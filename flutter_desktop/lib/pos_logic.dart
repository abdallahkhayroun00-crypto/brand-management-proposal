import 'dart:convert';

typedef Json = Map<String, dynamic>;

Json copyJson(Json value) => Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

List<Json> asMaps(Object? source) {
  if (source is! List) return <Json>[];
  return source.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
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
        if (line['voided'] != true && line['correction'] != true) line
  ];
}

int orderTotalCents(Json order) {
  if (order['cancelled'] == true) return 0;
  // Platform orders have an authoritative net amount after discounts.
  if ((order['source'] == 'Yemeksepeti' ||
      order['source'] == 'Trendyol Go') &&
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
  if ((order['source'] == 'Yemeksepeti' ||
      order['source'] == 'Trendyol Go') &&
      order['platformCollection'] == 'Pending') {
    return 0;
  }
  return asMaps(order['payments']).fold<int>(0,
      (sum, payment) => sum +
          (payment['reversed'] == true ? 0 : cents(payment['amount'])));
}

int orderDueCents(Json order) {
  if (order['cancelled'] == true) return 0;
  // Platform payment does not become a restaurant till receivable.
  if (order['source'] == 'Yemeksepeti' ||
      order['source'] == 'Trendyol Go') {
    return 0;
  }
  final due = orderTotalCents(order) - orderPaidCents(order);
  return due > 0 ? due : 0;
}

Json? activeTable(Json db, int table) {
  for (final order in asMaps(db['orders'])) {
    if (order['source'] == 'Masa' && order['table'] == table &&
        order['closed'] != true && order['cancelled'] != true &&
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
        'id': 1, 'staff': cashier, 'time': nowTime(),
        'createdAt': created, 'lines': productLines
      }
    ],
    'payments': <dynamic>[],
    'events': ['${nowTime()} · $cashier — Sipariş oluşturuldu'],
  };
  (state['orders'] as List).add(order);
  (state['printJobs'] as List).add({
    'orderId': id, 'batchId': 1, 'state': 'Bekliyor',
    'created': nowTime()
  });
  return order;
}

void addOrderBatch(Json state, int orderId, List<Json> productLines) {
  if (productLines.isEmpty) throw const FormatException('No products');
  final order = mutableOrder(state, orderId) ?? (throw const FormatException('Sipariş bulunamadı'));
  if (order['closed'] == true || order['cancelled'] == true) {
    throw const FormatException('Hesap kapalı');
  }
  final batches = order['batches'] as List;
  final nextBatchId = batches.fold<int>(0, (n, item) {
        final batch = item as Map;
        return (batch['id'] as int) > n ? batch['id'] as int : n;
      }) + 1;
  batches.add({
    'id': nextBatchId, 'staff': 'Kasa (PC)', 'time': nowTime(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'lines': productLines,
  });
  (order['events'] as List).add('${nowTime()} · Kasa (PC) · Ek sipariş');
  (state['printJobs'] as List).add({
    'orderId': orderId, 'batchId': nextBatchId,
    'state': 'Bekliyor', 'created': nowTime(),
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

void recordPayment(Json order, int amountCents, String method,
    {int? receivedCents}) {
  if (!['Nakit', 'Kart'].contains(method)) {
    throw const FormatException('Use bank POS integration for other methods');
  }
  if (order['closed'] == true || order['cancelled'] == true) {
    throw const FormatException('Hesap kapalı');
  }
  final due = orderDueCents(order);
  if (amountCents <= 0 || amountCents > due) {
    throw const FormatException('Geçersiz ödeme tutarı');
  }
  if (method == 'Nakit' && (receivedCents == null || receivedCents < amountCents)) {
    throw const FormatException('Alınan nakit tutarı yetersiz');
  }
  (order['payments'] as List).add({
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'method': method,
    'amount': fromCents(amountCents),
    'received': receivedCents == null ? null : fromCents(receivedCents),
    'change': receivedCents == null ? null : fromCents(receivedCents - amountCents),
    'time': nowTime(), 'by': 'Kasa (PC)',
  });
  (order['events'] as List).add(
      '${nowTime()} · Kasa (PC) · $method ${fromCents(amountCents)} TL');
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
