import 'order_reporting.dart';
import 'product_customization.dart';
import 'pos_logic.dart';
import 'campaign_menu.dart';
import 'operations.dart';
import 'order_actions.dart';
import 'pos_store.dart';

class StaffConflict implements Exception {
  const StaffConflict();
}

/// Server owns prices, active-worker checks, table merging and kitchen jobs.
/// Phones submit validated actions, never arbitrary state replacements.
Json submitStaffOrder(PosStore store, Json payload) {
  final id = payload['requestId'];
  if (id is! String) throw const FormatException('İstek kimliği gerekli');
  return store.command(id, payload, (s) {
    if (payload['expectedRevision'] != store.read().revision) {
      throw const StaffConflict();
    }
    final staff = asMaps(s['employees'])
        .where((e) => e['id'] == payload['staffId'] && e['active'] == true)
        .firstOrNull;
    if (staff == null) throw const FormatException('Aktif personel seçin');
    final source = payload['source'];
    if (!['Masa', 'Gel-Al'].contains(source)) {
      throw const FormatException('Telefon siparişleri Gel-Al; kurye yok');
    }
    final table = payload['table'];
    if (source == 'Masa' && (table is! int || table < 1 || table > 5)) {
      throw const FormatException('Masa 1–5');
    }
    if (payload['lines'] is! List ||
        (payload['lines'] as List).isEmpty ||
        (payload['lines'] as List).length > 200) {
      throw const FormatException('Ürün seçin');
    }
    if (asMaps(payload['lines']).length != (payload['lines'] as List).length) {
      throw const FormatException('Geçersiz ürün satırı');
    }
    final lines = <Json>[];
    for (final row in asMaps(payload['lines'])) {
      final p = row['customItem'] == true
          ? prepareInternalItem(s, row)
          : orderingProducts(s)
                .where(
                  (p) =>
                      p['id'] == row['productId'] &&
                      p['price'] is num &&
                      p['active'] != false,
                )
                .firstOrNull;
      if (row['expectedPriceCents'] != null &&
          (p == null || row['expectedPriceCents'] != cents(p['price']))) {
        throw const FormatException('Ürün fiyatı değişti. Sepeti güncelleyin.');
      }
      if (p == null ||
          row['qty'] is! int ||
          (row['qty'] as int) < 1 ||
          (row['qty'] as int) > 1000 ||
          (row['removed'] != null &&
              (row['removed'] is! List ||
                  (row['removed'] as List).any((v) => v is! String)))) {
        throw const FormatException('Ürün / adet / malzeme geçersiz');
      }
      if ((row['note'] != null && row['note'] is! String) ||
          '${row['note'] ?? ''}'.length > 500) {
        throw const FormatException('Not çok uzun');
      }
      lines.add({
        if (row['customItem'] == true) 'customItem': true,
        if (p['campaignId'] != null) ...{
          'campaignId': p['campaignId'],
          'components': mergeCampaignComponents(
            asMaps(p['components']),
            row['components'],
          ),
        },
        'productId': p['id'],
        'productKey': p['name'],
        'name': p['name'],
        'price': p['price'],
        'qty': row['qty'],
        'removed': row['removed'] ?? [],
        'note': row['note'] ?? '',
      });
    }
    for (var i = 0; i < lines.length; i++) {
      final raw = asMaps(payload['lines'])[i];
      if (raw['adjustmentCents'] != null && raw['adjustmentCents'] is! int)
        throw const FormatException('Fiyat farkı geçersiz');
      applyLineCustomization(
        lines[i],
        raw['adjustmentCents'] as int? ?? 0,
        '${lines[i]['note']}',
        (lines[i]['removed'] as List).cast<String>(),
      );
    }
    final requested = payload['orderId'];
    if (requested != null && requested is! int)
      throw const FormatException('Sipariş kimliği geçersiz');
    if (payload.containsKey('expectedTableOrderId') &&
        source == 'Masa' &&
        activeTable(s, table as int)?['id'] !=
            payload['expectedTableOrderId']) {
      throw const FormatException(
        'Masa hesabı değişti. Sipariş hedefini kontrol edin.',
      );
    }
    final existing = requested != null
        ? mutableOrder(s, requested as int)
        : source == 'Masa'
        ? activeTable(s, table as int)
        : null;
    if (requested != null && existing == null)
      throw const FormatException('Sipariş artık yok');
    if (existing != null) {
      requireLocal(existing);
      requireOpen(existing);
      if (existing['source'] != source ||
          source == 'Masa' && existing['table'] != table)
        throw const FormatException('Siparişin masası değişti; yenileyin');
    }

    Json order;
    if (existing != null) {
      addOrderBatch(
        s,
        existing['id'] as int,
        lines,
        cashier: '${staff['name']}',
        staffId: staff['id'] as int,
      );
      order = mutableOrder(s, existing['id'] as int)!;
      final batch = (order['batches'] as List).last as Map;
      batch['staff'] = staff['name'];
      batch['staffId'] = staff['id'];
    } else {
      order = newLocalOrder(
        state: s,
        source: '$source',
        table: source == 'Masa' ? table as int : null,
        productLines: lines,
        cashier: '${staff['name']}',
        pickupChannel: '${payload['pickupChannel'] ?? 'Tezgahtan'}',
      );
      ((order['batches'] as List).first as Map)['staffId'] = staff['id'];
      final customer = payload['customer'];
      if (source == 'Gel-Al' && customer is Map) {
        for (final field in ['name', 'phone', 'time']) {
          if (customer[field] != null &&
              (customer[field] is! String ||
                  (customer[field] as String).length > 200)) {
            throw const FormatException('Müşteri bilgisi geçersiz');
          }
        }
        order['customer'] = {
          for (final field in ['name', 'phone', 'time'])
            field: customer[field] ?? '',
        };
      }
    }
    finishPickupIfSettled(order);
    recordStaffNotice(
      s,
      order,
      id,
      '${staff['name']}',
      existing == null ? 'Yeni sipariş' : 'Ek sipariş',
    );
    return {
      'ok': true,
      'orderId': order['id'],
      'orderNumber': displayOrderNumber(order),
      'requestId': id,
    };
  });
}

Json submitStaffAction(PosStore store, Json payload) {
  final requestId = payload['requestId'];
  if (requestId is! String)
    throw const FormatException('İstek kimliği gerekli');
  if (payload['action'] == 'delete') {
    if (payload['orderId'] is! int ||
        payload['expectedRevision'] is! int ||
        payload['staffId'] is! int)
      throw const FormatException('Silme bilgisi geçersiz');
    if (payload['confirmed'] != true)
      throw const FormatException('Silmeyi onaylayın');
    return store.deleteOrder(
      payload['orderId'] as int,
      payload['expectedRevision'] as int,
      requestId,
      staffId: payload['staffId'] as int,
    );
  }
  return store.command(requestId, payload, (s) {
    if (payload['expectedRevision'] != store.read().revision)
      throw const StaffConflict();
    final staff = asMaps(s['employees'])
        .where((e) => e['id'] == payload['staffId'] && e['active'] == true)
        .firstOrNull;
    if (staff == null) throw const FormatException('Aktif personel seçin');
    final orderId = payload['orderId'];
    if (orderId is! int) throw const FormatException('Sipariş seçin');
    final order = mutableOrder(s, orderId);
    if (order == null) throw const FormatException('Sipariş yok');
    requireLocal(order);
    if (payload['action'] == 'printProductPayment') {
      final paymentId = payload['paymentId'];
      final payment = asMaps(order['payments'])
          .where(
            (p) =>
                paymentId is String &&
                p['productPaymentId'] == paymentId &&
                p['staffId'] == staff['id'],
          )
          .firstOrNull;
      final receipt = payment?['productReceipt'];
      if (payment == null ||
          receipt is! String ||
          paymentNetCents(payment) <= 0) {
        throw const FormatException('Ödeme fişi bulunamadı.');
      }
      queuePaymentReceipt(
        s,
        order,
        requestId: 'receipt_$paymentId',
        receipt: receipt,
      );
      return {'ok': true, 'orderId': orderId, 'action': 'printProductPayment'};
    }
    requireOpen(order);
    if (payload['guestId'] != null && payload['guestId'] is! int)
      throw const FormatException('Kişi geçersiz');
    final by = '${staff['name']}', action = payload['action'];
    switch (action) {
      case 'editLine':
        if (payload['adjustmentCents'] != null &&
            payload['adjustmentCents'] is! int)
          throw const FormatException('Fiyat farkı geçersiz');
        if (payload['key'] is! String ||
            payload['qty'] is! int ||
            payload['note'] is! String ||
            payload['removed'] is! List ||
            (payload['removed'] as List).any((v) => v is! String))
          throw const FormatException('Ürün bilgisi geçersiz');
        editLocalLine(
          order,
          payload['key'] as String,
          payload['qty'] as int,
          payload['note'] as String,
          (payload['removed'] as List).cast<String>(),
          by,
          adjustmentCents: payload['adjustmentCents'] as int?,
          components: payload['components'],
        );
      case 'splitEqual':
        if (payload['count'] is! int)
          throw const FormatException('Kişi sayısı geçersiz');
        splitEqually(order, payload['count'] as int);
      case 'addGuest':
        if (payload['name'] is! String || '${payload['name']}'.length > 100)
          throw const FormatException('Kişi adı geçersiz');
        addGuest(order, '${payload['name']}');
      case 'allocate':
        if (payload['guestId'] is! int ||
            payload['key'] is! String ||
            payload['cents'] is! int)
          throw const FormatException('Ürün payı geçersiz');
        allocateProduct(
          order,
          payload['guestId'] as int,
          '${payload['key']}',
          payload['cents'] as int,
        );
      case 'resetGuests':
        resetGuests(order);
      case 'move':
        if (payload['table'] is! int) throw const FormatException('Masa seçin');
        moveLocalTable(s, order, payload['table'] as int, by);
      case 'status':
        markPickupDelivered(order);
      case 'payProducts':
        final shares = payload['shares'];
        final amount = payload['amountCents'];
        final method = payload['method'];
        final received = payload['receivedCents'];
        final cash = payload['cashCents'];
        if (payload['confirmed'] != true ||
            amount is! int ||
            method is! String ||
            !['Nakit', 'Kart', 'Karışık'].contains(method) ||
            shares is! Map ||
            shares.length > 200 ||
            shares.entries.any((e) => e.key is! String || e.value is! int) ||
            received != null && received is! int ||
            cash != null && cash is! int) {
          throw const FormatException('Ürün ödemesini doğrulayın.');
        }
        final receipt = recordProductPayment(
          order,
          shares.cast<String, int>(),
          amount,
          method,
          receivedCents: received as int?,
          cashCents: cash as int?,
        );
        final payments = (order['payments'] as List).cast<Map>();
        for (final p in payments.reversed.take(method == 'Karışık' ? 2 : 1)) {
          p['by'] = by;
          p['staffId'] = staff['id'];
        }
        payments.last['productPaymentId'] = requestId;
        payments.last['productReceipt'] = receipt;
      case 'payMixed':
        if (payload['confirmed'] != true ||
            payload['amountCents'] is! int ||
            payload['cashCents'] is! int ||
            payload['receivedCents'] != null &&
                payload['receivedCents'] is! int ||
            payload['printReceipt'] is! bool)
          throw const FormatException('Ödemeyi doğrulayın');
        recordMixedPayment(
          order,
          payload['amountCents'] as int,
          payload['cashCents'] as int,
          guestId: payload['guestId'] as int?,
          receivedCents: payload['receivedCents'] as int?,
        );
        for (final p in (order['payments'] as List).cast<Map>().reversed.take(
          2,
        ))
          p['by'] = by;
        if (payload['printReceipt'] == true)
          queuePaymentReceipt(s, order, requestId: requestId);
      case 'pay':
        if (payload['amountCents'] is! int ||
            !['Nakit', 'Kart'].contains(payload['method']) ||
            payload['confirmed'] != true ||
            payload['receivedCents'] != null &&
                payload['receivedCents'] is! int ||
            payload['printReceipt'] is! bool)
          throw const FormatException('Ödemeyi doğrulayın');
        // Card here records an explicitly confirmed physical terminal payment.
        // No phone endpoint can claim to be a bank callback.
        recordPayment(
          order,
          payload['amountCents'] as int,
          payload['method'] as String,
          receivedCents: payload['receivedCents'] as int?,
          guestId: payload['guestId'] as int?,
        );
        ((order['payments'] as List).last as Map)['by'] = by;
        if (payload['printReceipt'] == true)
          queuePaymentReceipt(s, order, requestId: requestId);
      case 'close':
        if (order['source'] != 'Masa')
          throw const FormatException('Yalnız masa hesabı kapatılabilir');
        closeLocalOrder(order);
      default:
        throw const FormatException('İşlem desteklenmiyor');
    }
    finishPickupIfSettled(order);
    recordStaffNotice(
      s,
      order,
      requestId,
      by,
      const {
            'editLine': 'Ürün düzenlendi',
            'move': 'Masa taşındı',
            'status': 'Servis durumu güncellendi',
            'pay': 'Ödeme alındı',
            'close': 'Hesap kapatıldı',
          }[action] ??
          '$action',
    );
    return {
      'ok': true,
      'orderId': orderId,
      'orderNumber': displayOrderNumber(order),
      'requestId': requestId,
      'action': action,
    };
  });
}
