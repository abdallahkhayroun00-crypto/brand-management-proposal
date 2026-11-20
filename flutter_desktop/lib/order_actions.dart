import 'pos_logic.dart';
import 'campaign_menu.dart';
import 'operations.dart';
import 'product_customization.dart';

export 'operations.dart' show recordMixedPayment, recordProductPayment;

/// Applied only inside revision-checked SQLite commands.
void editLocalLine(
  Json order,
  String key,
  int quantity,
  String note,
  List<String> removed,
  String by, {
  int? adjustmentCents,
  Object? components,
}) {
  requireLocal(order);
  requireOpen(order);
  if (quantity < 0 ||
      quantity > 1000 ||
      note.length > 500 ||
      removed.length > 50 ||
      removed.any((s) => s.length > 100)) {
    throw const FormatException('Adet / not / malzeme geçersiz');
  }
  final parts = key.split(':');
  if (parts.length != 2) throw const FormatException('Ürün satırı geçersiz');
  final batch = (order['batches'] as List)
      .whereType<Map>()
      .where((b) => '${b['id']}' == parts[0])
      .firstOrNull;
  final index = int.tryParse(parts[1]);
  if (batch == null ||
      index == null ||
      index < 0 ||
      index >= (batch['lines'] as List).length)
    throw const FormatException('Ürün bulunamadı');
  final line = (batch['lines'] as List)[index] as Map;
  if (line['voided'] == true || line['correction'] == true)
    throw const FormatException('Ürün iptal edilmiş');
  final customized = Map<String, dynamic>.from(line);
  if (line['campaignId'] != null) {
    customized['components'] = mergeCampaignComponents(
      asMaps(line['components']),
      components,
    );
  } else if (components != null &&
      (components is! List || components.isNotEmpty)) {
    throw const FormatException('Ürün kampanya değil');
  }
  applyLineCustomization(
    customized,
    adjustmentCents ?? (line['adjustmentCents'] as int? ?? 0),
    note,
    removed,
  );
  final previous = line['qty'] as int,
      nextTotal =
          orderTotalCents(order) -
          cents(line['price']) * previous +
          cents(customized['price']) * quantity;
  if (nextTotal < orderPaidCents(order) ||
      allocatedTo(order, key) > cents(customized['price']) * quantity) {
    throw const FormatException(
      'Önce fazla tahsilatı iade edin veya kişi payını azaltın',
    );
  }
  (order.putIfAbsent('lineEdits', () => <dynamic>[]) as List).add({
    'key': key,
    'before': copyJson(Map<String, dynamic>.from(line)),
    'by': by,
    'at': utcNow(),
  });
  line.addAll(customized);
  line['qty'] = quantity;
  line['voided'] = quantity == 0;
  line['note'] = note;
  line['removed'] = removed;
  if (quantity > previous) {
    order['serviceStatus'] = 'Hazırlanıyor';
    order['serviceStartedAt'] = utcNow();
    order.remove('readyAt');
    order.remove('deliveredAt');
  }
  (order['events'] as List).add(
    '${utcNow()} · $by · ${line['name']} $previous → $quantity · $note',
  );
}

void moveLocalTable(Json state, Json order, int table, String by) {
  requireLocal(order);
  requireOpen(order);
  if (order['source'] != 'Masa' || table < 1 || table > 5)
    throw const FormatException('Masa 1–5 seçin');
  final occupied = activeTable(state, table);
  if (occupied != null && occupied['id'] != order['id'])
    throw const FormatException('Hedef masa dolu; hesaplar birleştirilmedi');
  final previous = order['table'];
  order['table'] = table;
  (order['events'] as List).add('${utcNow()} · $by · Masa $previous → $table');
}

void closeLocalOrder(Json order) {
  requireLocal(order);
  requireOpen(order);
  if (orderDueCents(order) > 0)
    throw const FormatException('Önce kalan hesabı ödeyin');
  order['closed'] = true;
  order['tableReleased'] = true;
  order['closedAt'] = utcNow();
  (order['events'] as List).add('${utcNow()} · Hesap kapatıldı');
}

void queuePaymentReceipt(
  Json state,
  Json order, {
  required String requestId,
  String? receipt,
}) {
  requireLocal(order);
  if (orderPaidCents(order) <= 0)
    throw const FormatException('Önce ödeme kaydedin');
  final jobs = state['printJobs'] as List;
  if (jobs.whereType<Map>().any((j) => j['receiptRequestId'] == requestId))
    return;
  jobs.add({
    'orderId': order['id'],
    'batchId':
        jobs.whereType<Map>().fold<int>(
          0,
          (n, j) => j['batchId'] is int && (j['batchId'] as int) < n
              ? j['batchId'] as int
              : n,
        ) -
        1,
    'kind': 'paymentReceipt',
    'receiptRequestId': requestId,
    'state': 'Bekliyor',
    'createdAt': utcNow(),
    'created': nowTime(),
    'text': receipt ?? billText(order),
  });
}

void recordStaffNotice(
  Json state,
  Json order,
  String id,
  String staff,
  String action,
) {
  final notices = state.putIfAbsent('staffNotices', () => <dynamic>[]) as List;
  notices.add({
    'id': id,
    'orderId': order['id'],
    'staff': staff,
    'action': action,
    'table': order['table'],
    'at': utcNow(),
  });
  if (notices.length > 100) notices.removeRange(0, notices.length - 100);
}
