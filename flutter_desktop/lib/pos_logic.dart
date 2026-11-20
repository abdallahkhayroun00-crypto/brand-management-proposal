import 'campaign_menu.dart';
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
  // Restaurant timestamps always use Türkiye local time (UTC+03:00),
  // independent of the Windows user's regional timezone.
  final now = DateTime.now().toUtc().add(const Duration(hours: 3));
  return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}

/// Refuse inactive products even if a cashier kept an old composer open
/// while the QR catalog was updated in another window.
void validateVisibleProductLines(Json state, List<Json> lines) {
  final hiddenIds = asMaps(state['localMenu'])
      .where((p) => p['active'] == false && p['id'] is int)
      .map((p) => p['id'] as int)
      .toSet();
  for (final line in lines) {
    if (line['campaignId'] != null ||
        (line['productId'] is int && (line['productId'] as int) < 0))
      prepareCampaignLine(state, line);
    if (hiddenIds.contains(line['productId'])) {
      throw const FormatException(
        'Ürün artık satışta değil; menüyü yenileyin.',
      );
    }
  }
}

/// The cashier reviews a draft, never a historical price snapshot. Refuse
/// stale drafts after sync or a local price/availability change.
void validateCashierDraft(Json state, List<Json> lines) {
  for (final line in lines) {
    if (line['customItem'] != true) continue;
    final item = prepareInternalItem(state, line);
    line['productId'] = item['id'];
    line['name'] = line['productKey'] = item['name'];
    line['price'] = item['price'];
    line.remove('saveToMenu');
  }
  validateProductLines(lines);
  final menu = orderingProducts(state);
  for (final line in lines) {
    if (line['customItem'] == true) continue;
    final p = menu.where((p) => p['id'] == line['productId']).firstOrNull;
    if (p?['campaignId'] != null) {
      if (cents(p!['price']) != cents(line['basePrice'] ?? line['price']))
        throw const FormatException(
          'Kampanya fiyatı değişti; menüyü yenileyin',
        );
      final next = prepareCampaignLine(state, line);
      if (cents(line['price']) != cents(next['price']))
        throw const FormatException(
          'Kampanya fiyatı değişti; menüyü yenileyin',
        );
      line.addAll(next);
    }
    if (p == null ||
        p['active'] == false ||
        p['price'] is! num ||
        cents(p['price']) != cents(line['basePrice'] ?? line['price']) ||
        (line['adjustmentCents'] != null &&
            (line['adjustmentCents'] is! int ||
                cents(line['price']) !=
                    cents(line['basePrice']) +
                        (line['adjustmentCents'] as int) +
                        componentExtraCents(line)))) {
      throw const FormatException(
        'Menü fiyatı veya ürün durumu değişti. Güncel menüyü alın; sepetiniz korunuyor.',
      );
    }
  }
}

Json prepareInternalItem(Json state, Json line) {
  final name = line['name'];
  final price = line['price'];
  if (name is! String ||
      name.trim().isEmpty ||
      name.trim().length > 100 ||
      price is! num ||
      !price.isFinite ||
      price <= 0 ||
      price > 99999.99) {
    throw const FormatException(
      'Özel ürün adı ve birim fiyatını kontrol edin.',
    );
  }
  final label = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  final amount = fromCents(cents(price));
  if (amount <= 0) throw const FormatException('Birim fiyat sıfır olamaz.');
  const customId = 2000000001;
  if (line['saveToMenu'] != true) {
    return {'id': customId, 'name': label, 'price': amount};
  }
  final products = state.putIfAbsent('internalMenu', () => <dynamic>[]) as List;
  final existing = asMaps(products)
      .where((p) => p['name'] == label && cents(p['price']) == cents(amount))
      .firstOrNull;
  if (existing != null) return existing;
  final id =
      asMaps(products).fold<int>(
        customId,
        (n, p) => (p['id'] as int) > n ? p['id'] as int : n,
      ) +
      1;
  final item = {
    'id': id,
    'name': label,
    'price': amount,
    'category': 'side',
    'active': true,
  };
  products.add(item);
  return item;
}

void queueLocalKitchen(Json state, Json order, Map batch) {
  if (state['settings']?['receiptPolicy'] == 'onPayment') return;
  (state['printJobs'] as List).add({
    'orderId': order['id'], 'batchId': batch['id'], 'state': 'Bekliyor',
    'created': nowTime(), 'createdAt': DateTime.now().toUtc().toIso8601String(),
    // Immutable content: cancellation must not rewrite an accepted ticket.
    'snapshot': copyJson({
      'order': {
        for (final key in [
          'id',
          'dailyNumber',
          'numberDay',
          'source',
          'table',
          'createdAt',
        ])
          key: order[key],
      },
      'batch': batch,
    }),
  });
}

bool correctionKitchenJob(Json state, Map job) {
  final snapshot = job['snapshot'];
  final batch = snapshot is Map ? snapshot['batch'] : null;
  final source = batch is Map
      ? batch
      : asMaps(
          mutableOrder(state, job['orderId'] as int)?['batches'],
        ).where((b) => b['id'] == job['batchId']).firstOrNull;
  return source is Map &&
      asMaps(source['lines']).any((l) => l['correction'] == true);
}

/// Cancelled originals and platform jobs must never be requeued as local food.
bool canRequeueLocalKitchen(Json state, Map job) {
  final order = mutableOrder(state, job['orderId'] as int);
  return order != null &&
      ['Masa', 'Gel-Al'].contains(order['source']) &&
      job['state'] != 'Gönderiliyor' &&
      job['state'] != 'İptal' &&
      (order['cancelled'] != true || correctionKitchenJob(state, job));
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
  validateVisibleProductLines(state, productLines);
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
  queueLocalKitchen(state, order, (order['batches'] as List).first as Map);
  return order;
}

void addOrderBatch(
  Json state,
  int orderId,
  List<Json> productLines, {
  String cashier = 'Kasa (PC)',
  int? staffId,
}) {
  if (productLines.isEmpty) throw const FormatException('No products');
  validateProductLines(productLines);
  validateVisibleProductLines(state, productLines);
  final order =
      mutableOrder(state, orderId) ??
      (throw const FormatException('Sipariş bulunamadı'));
  if (order['terminalPending'] != null)
    throw const FormatException('Terminal sonucu bekleniyor');
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
    'staff': cashier,
    if (staffId != null) 'staffId': staffId,
    'time': nowTime(),
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'lines': productLines,
  });
  (order['events'] as List).add('${nowTime()} · $cashier · Ek sipariş');
  order['serviceStatus'] = 'Hazırlanıyor';
  order['serviceStartedAt'] = DateTime.now().toUtc().toIso8601String();
  order.remove('readyAt');
  order.remove('deliveredAt');
  queueLocalKitchen(state, order, batches.last as Map);
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
  if (order['terminalPending'] != null)
    throw const FormatException('Terminal işlemi bekleniyor');
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
  if (lines.isEmpty || lines.length > 200)
    throw const FormatException('1–200 ürün satırı seçin');
  for (final l in lines) {
    if (l['qty'] is! int ||
        (l['qty'] as int) < 1 ||
        (l['qty'] as int) > 1000 ||
        l['price'] is! num ||
        !(l['price'] as num).isFinite ||
        (l['price'] as num) < 0) {
      throw const FormatException('Ürün adedi / fiyatı geçersiz');
    }
    if ((l['note'] != null &&
            (l['note'] is! String || (l['note'] as String).length > 500)) ||
        (l['removed'] != null &&
            (l['removed'] is! List ||
                (l['removed'] as List).length > 50 ||
                (l['removed'] as List).any(
                  (x) => x is! String || x.length > 100,
                )))) {
      throw const FormatException(
        'Not en fazla 500 karakter; malzeme listesi geçersiz.',
      );
    }
  }
}

void closeLocalTable(Json order) {
  if (order['terminalPending'] != null)
    throw const FormatException('Terminal sonucu bekleniyor');
  if (order['closed'] == true || order['cancelled'] == true)
    throw const FormatException('Hesap zaten kapalı');
  if (order['source'] != 'Masa') throw const FormatException('Only tables');
  if (orderDueCents(order) != 0) {
    throw const FormatException('Önce kalan hesabı kapatın');
  }
  order['closed'] = true;
  order['tableReleased'] = true;
  (order['events'] as List).add('${nowTime()} · Kasa (PC) · Masa kapatıldı');
}

String formatTry(int amount) {
  final absolute = amount.abs();
  final whole = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '${amount < 0 ? '-' : ''}$whole,${(absolute % 100).toString().padLeft(2, '0')} ₺';
}
