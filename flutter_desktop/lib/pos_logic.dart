import 'order_reporting.dart';

import 'dart:convert';

typedef Json = Map<String, dynamic>;

Json copyJson(Json value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

List<Json> asMaps(Object? source) {
  if (source is! List) return <Json>[];
  return source
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

int cents(Object? value) {
  if (value is num) return (value * 100).round();
  return 0;
}

double fromCents(int value) => value / 100.0;

List<Json> activeLines(Json order) {
  return [
    for (final batch in asMaps(order['batches']))
      for (final line in asMaps(batch['lines']))
        if (line['voided'] != true && line['correction'] != true) line,
  ];
}

int orderTotalCents(Json order) {
  if (order['cancelled'] == true) return 0;
  // Platform orders have an authoritative net amount after discounts.
  if ((order['source'] == 'Yemeksepeti' || order['source'] == 'Trendyol Go') &&
      order['platformSnapshot'] is Map) {
    final snapshot = order['platformSnapshot'] as Map;
    final total = cents(snapshot['orderTotal']);
    final cancelled = cents(order['platformCancelledAmount']);
    return (total - cancelled).clamp(0, 1 << 55).toInt();
  }
  return activeLines(order).fold<int>(0, (sum, row) {
    final quantity = row['qty'] is num ? (row['qty'] as num).toInt() : 0;
    return sum + cents(row['price']) * quantity;
  });
}

int orderPaidCents(Json order) {
  if ((order['source'] == 'Yemeksepeti' || order['source'] == 'Trendyol Go') &&
      order['platformCollection'] == 'Pending') {
    return 0;
  }
  final paid = asMaps(order['payments']).fold<int>(
    0,
    (sum, payment) =>
        sum +
        (payment['reversed'] == true
            ? 0
            : cents(payment['amount']) -
                  asMaps(
                    payment['refunds'],
                  ).fold<int>(0, (n, r) => n + cents(r['amount']))),
  );
  return paid +
      (['Yemeksepeti', 'Trendyol Go'].contains(order['source'])
          ? asMaps(
              order['platformAdjustments'],
            ).fold<int>(0, (n, a) => n + cents(a['amount']))
          : 0);
}

int orderDueCents(Json order) {
  if (order['cancelled'] == true) return 0;
  // Platform payment does not become a restaurant till receivable.
  if (order['source'] == 'Yemeksepeti' || order['source'] == 'Trendyol Go') {
    return 0;
  }
  final due = orderTotalCents(order) - orderPaidCents(order);
  return due > 0 ? due : 0;
}

int paymentGuestCents(Json p, int id) {
  if (p['reversed'] == true) return 0;
  if (p['guestCheckId'] == id) {
    return cents(p['amount']) -
        asMaps(p['refunds']).fold<int>(0, (n, r) => n + cents(r['amount']));
  }
  return asMaps(p['guestAllocations'])
      .where((a) => a['guestCheckId'] == id)
      .fold<int>(0, (n, a) => n + cents(a['amount']));
}

Json? activeTable(Json db, int table) {
  for (final order in asMaps(db['orders'])) {
    if (order['source'] == 'Masa' &&
        order['table'] == table &&
        order['closed'] != true &&
        order['cancelled'] != true &&
        order['tableReleased'] != true &&
        asMaps(order['batches']).isNotEmpty) {
      return order;
    }
  }
  return null;
}

String nowTime() {
  final now = DateTime.now();
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

Json newLocalOrder({
  required Json state,
  required String source,
  required List<Json> productLines,
  int? table,
  String pickupChannel = 'Tezgahtan',
  String cashier = 'Kasa (PC)',
}) {
  if (!['Masa', 'Gel-Al'].contains(source)) {
    throw const FormatException('Use platform integration for delivery');
  }
  if (source == 'Masa' && (table == null || table < 1 || table > 5)) {
    throw const FormatException('Masa 1–5');
  }
  if (productLines.isEmpty) throw const FormatException('No products');
  validateProductLines(productLines);
  if (source == 'Masa' && activeTable(state, table!) != null) {
    throw const FormatException('Masa dolu; mevcut hesaba ek sipariş ekleyin');
  }
  if (!['Tezgahtan', 'Telefon'].contains(pickupChannel)) {
    throw const FormatException('Telefon siparişleri yalnızca Gel-Al');
  }
  final id = state['nextId'] as int;
  state['nextId'] = id + 1;
  final created = DateTime.now().toUtc().toIso8601String();
  final order = <String, dynamic>{
    'id': id,
    'source': source,
    'table': source == 'Masa' ? table : null,
    'created': nowTime(),
    'createdAt': created,
    'closed': false,
    'serviceStatus': 'Hazırlanıyor',
    'pickupChannel': source == 'Gel-Al' ? pickupChannel : null,
    'customer': <String, dynamic>{'name': '', 'phone': '', 'time': ''},
    'batches': [
      <String, dynamic>{
        'id': 1,
        'staff': cashier,
        'time': nowTime(),
        'createdAt': created,
        'lines': productLines,
      },
    ],
    'payments': <dynamic>[],
    'events': ['${nowTime()} · $cashier — Sipariş oluşturuldu'],
  };
  (state['orders'] as List).add(order);
  assignDailyNumbers(state);
  (state['printJobs'] as List).add({
    'orderId': id,
    'batchId': 1,
    'state': 'Bekliyor',
    'created': nowTime(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });
  return order;
}

void addOrderBatch(Json state, int orderId, List<Json> productLines) {
  if (productLines.isEmpty) throw const FormatException('No products');
  validateProductLines(productLines);
  final order =
      mutableOrder(state, orderId) ??
      (throw const FormatException('Sipariş bulunamadı'));
  if (order['closed'] == true || order['cancelled'] == true) {
    throw const FormatException('Hesap kapalı');
  }
  if (['Yemeksepeti', 'Trendyol Go'].contains(order['source'])) {
    throw const FormatException('Platform siparişine yerel ürün eklenemez');
  }
  final batches = order['batches'] as List;
  final nextBatchId =
      batches.fold<int>(0, (n, item) {
        final batch = item as Map;
        return (batch['id'] as int) > n ? batch['id'] as int : n;
      }) +
      1;
  batches.add({
    'id': nextBatchId,
    'staff': 'Kasa (PC)',
    'time': nowTime(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'lines': productLines,
  });
  (order['events'] as List).add('${nowTime()} · Kasa (PC) · Ek sipariş');
  (state['printJobs'] as List).add({
    'orderId': orderId,
    'batchId': nextBatchId,
    'state': 'Bekliyor',
    'created': nowTime(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });
}

/// Use only when working with the actual JSON map inside a transaction.
/// Unlike asMaps (copying), this helper returns the mutable stored order.
Json? mutableOrder(Json data, int orderId) {
  for (final row in data['orders'] as List) {
    if (row is Map && row['id'] == orderId) {
      return row.cast<String, dynamic>();
    }
  }
  return null;
}

void recordPayment(
  Json order,
  int amountCents,
  String method, {
  int? receivedCents,
  int? guestId,
}) {
  if (!['Nakit', 'Kart'].contains(method)) {
    throw const FormatException('Use bank POS integration for other methods');
  }
  if (order['closed'] == true || order['cancelled'] == true) {
    throw const FormatException('Hesap kapalı');
  }
  final due = orderDueCents(order);
  final guests = asMaps(order['guestChecks']);
  if (guests.isNotEmpty) {
    final unmatched = asMaps(order['payments'])
        .where((p) => p['guestCheckId'] == null && p['reversed'] != true)
        .fold<int>(
          0,
          (n, p) =>
              n +
              cents(p['amount']) -
              asMaps(
                p['refunds'],
              ).fold<int>(0, (v, r) => v + cents(r['amount'])) -
              asMaps(
                p['guestAllocations'],
              ).fold<int>(0, (v, a) => v + cents(a['amount'])),
        );
    if (unmatched > 0) {
      throw const FormatException('Önce geçmiş tahsilatı kişilere eşleştirin');
    }
    final guest = guests.where((g) => g['id'] == guestId).firstOrNull;
    if (guest == null) throw const FormatException('Kişi hesabını seçin');
    final allocation = asMaps(
      guest['allocations'],
    ).fold<int>(0, (n, a) => n + (a['cents'] as int));
    final paid = asMaps(
      order['payments'],
    ).fold<int>(0, (n, p) => n + paymentGuestCents(p, guestId!));
    if (amountCents > allocation - paid) {
      throw const FormatException('Kişi bakiyesi aşıldı');
    }
  }
  if (amountCents <= 0 || amountCents > due) {
    throw const FormatException('Geçersiz ödeme tutarı');
  }
  if (method == 'Nakit' &&
      (receivedCents == null || receivedCents < amountCents)) {
    throw const FormatException('Alınan nakit tutarı yetersiz');
  }
  (order['payments'] as List).add({
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'method': method,
    'amount': fromCents(amountCents),
    'received': receivedCents == null ? null : fromCents(receivedCents),
    'change': receivedCents == null
        ? null
        : fromCents(receivedCents - amountCents),
    'time': nowTime(),
    'by': 'Kasa (PC)',
    'guestCheckId': ?guestId,
  });
  (order['events'] as List).add(
    '${nowTime()} · Kasa (PC) · $method ${fromCents(amountCents)} TL',
  );
}

void validateProductLines(List<Json> lines) {
  for (final l in lines) {
    if (l['qty'] is! int ||
        (l['qty'] as int) < 1 ||
        l['price'] is! num ||
        !(l['price'] as num).isFinite ||
        (l['price'] as num) < 0) {
      throw const FormatException('Ürün adedi / fiyatı geçersiz');
    }
  }
}

void closeLocalTable(Json order) {
  if (order['source'] != 'Masa') throw const FormatException('Only tables');
  if (orderDueCents(order) != 0) {
    throw const FormatException('Önce kalan hesabı kapatın');
  }
  order['closed'] = true;
  order['tableReleased'] = true;
  (order['events'] as List).add('${nowTime()} · Kasa (PC) · Masa kapatıldı');
}

String formatTry(int amount) {
  final value = amount / 100;
  final fixed = value.toStringAsFixed(2);
  return '$fixed ₺';
}
