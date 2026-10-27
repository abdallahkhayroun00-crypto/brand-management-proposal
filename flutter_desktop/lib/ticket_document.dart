import 'order_reporting.dart';
import 'operations.dart';
import 'pos_logic.dart';

enum TicketKind { newOrder, addition, correction, bill }

class TicketLine {
  const TicketLine({
    required this.name,
    required this.quantity,
    required this.amountCents,
    this.note = '',
    this.removed = const [],
  });
  final String name, note;
  final int quantity, amountCents;
  final List<String> removed;
  Json toJson() => {
    'name': name,
    'quantity': quantity,
    'amountCents': amountCents,
    'note': note,
    'removed': removed,
  };
  factory TicketLine.fromJson(Json j) => TicketLine(
    name: '${j['name']}',
    quantity: j['quantity'] as int,
    amountCents: j['amountCents'] as int,
    note: '${j['note'] ?? ''}',
    removed: (j['removed'] as List? ?? []).map((r) => '$r').toList(),
  );
}

class TicketDocument {
  const TicketDocument({
    required this.kind,
    required this.orderId,
    required this.batchId,
    required this.source,
    required this.destination,
    required this.reference,
    required this.stamp,
    required this.lines,
    required this.totalCents,
    this.platformTotalCents,
    this.paidCents = 0,
    this.dueCents = 0,
    this.externalCode = '',
    this.payments = const [],
  });
  final TicketKind kind;
  final int orderId, batchId, totalCents, paidCents, dueCents;
  final int? platformTotalCents;
  final String source, destination, reference, stamp, externalCode;
  final List<TicketLine> lines;
  final List<String> payments;
  int get quantity => lines.fold<int>(0, (n, l) => n + l.quantity);
  String get heading => switch (kind) {
    TicketKind.newOrder => 'YENİ SİPARİŞ',
    TicketKind.addition => 'EK SİPARİŞ',
    TicketKind.correction => 'ÜRÜN İPTALİ',
    TicketKind.bill => 'HESAP ÖZETİ',
  };
  int get lineSubtotalCents => lines.fold<int>(0, (n, l) => n + l.amountCents);
  String get totalLabel => platformTotalCents != null
      ? (kind == TicketKind.addition ? 'EK ÜRÜN TOPLAMI' : 'ÜRÜN TOPLAMI')
      : switch (kind) {
          TicketKind.addition => 'EK SİPARİŞ TOPLAMI',
          TicketKind.bill => 'HESAP TOPLAMI',
          _ => 'TOPLAM',
        };
  String get legal => kind == TicketKind.bill
      ? 'Hesap Özeti - Mali fiş / fatura değildir'
      : 'Hazırlık Fişi - Mali fiş değildir';
  Json toJson() => {
    'schema': 1,
    'kind': kind.name,
    'orderId': orderId,
    'batchId': batchId,
    'source': source,
    'destination': destination,
    'reference': reference,
    'stamp': stamp,
    'lines': lines.map((l) => l.toJson()).toList(),
    'totalCents': totalCents,
    'platformTotalCents': platformTotalCents,
    'paidCents': paidCents,
    'dueCents': dueCents,
    'externalCode': externalCode,
    'payments': payments,
  };
  factory TicketDocument.fromJson(Json j) => TicketDocument(
    kind: TicketKind.values.byName('${j['kind']}'),
    orderId: j['orderId'] as int,
    batchId: j['batchId'] as int,
    source: '${j['source']}',
    destination: '${j['destination']}',
    reference: '${j['reference']}',
    stamp: '${j['stamp']}',
    lines: asMaps(j['lines']).map(TicketLine.fromJson).toList(),
    totalCents: j['totalCents'] as int,
    platformTotalCents: j['platformTotalCents'] as int?,
    paidCents: j['paidCents'] as int? ?? 0,
    dueCents: j['dueCents'] as int? ?? 0,
    externalCode: '${j['externalCode'] ?? ''}',
    payments: (j['payments'] as List? ?? []).map((p) => '$p').toList(),
  );
}

String _destination(Json order) => order['source'] == 'Masa'
    ? 'Masa: ${order['table']}'
    : order['source'] == 'Gel-Al'
    ? order['pickupChannel'] == 'Telefon'
          ? 'Telefon Gel-Al'
          : 'Gel-Al'
    : '${order['source']}';
TicketLine _line(Json line) => TicketLine(
  name: '${line['name'] ?? line['productKey']}',
  quantity: line['qty'] as int,
  amountCents: cents(line['price']) * (line['qty'] as int),
  note: '${line['note'] ?? ''}',
  removed: (line['removed'] as List? ?? []).map((r) => '$r').toList(),
);

TicketDocument kitchenTicket(Json state, Json job, {bool useSnapshot = true}) {
  if (useSnapshot && job['ticketSnapshot'] is Map) {
    return TicketDocument.fromJson(
      copyJson((job['ticketSnapshot'] as Map).cast<String, dynamic>()),
    );
  }
  final order =
      mutableOrder(state, job['orderId'] as int) ??
      (throw const FormatException('Sipariş bulunamadı'));
  final batch =
      asMaps(
        order['batches'],
      ).where((b) => b['id'] == job['batchId']).firstOrNull ??
      (throw const FormatException('Mutfak partisi bulunamadı'));
  final raw = asMaps(
    batch['lines'],
  ).where((l) => l['voided'] != true || l['correction'] == true).toList();
  final batchId = batch['id'] as int,
      kind = raw.any((l) => l['correction'] == true)
          ? TicketKind.correction
          : batchId == 1
          ? TicketKind.newOrder
          : TicketKind.addition;
  final lines = raw.map(_line).toList();
  return TicketDocument(
    kind: kind,
    orderId: order['id'] as int,
    batchId: batchId,
    source: '${order['source']}',
    destination: _destination(order),
    reference:
        '#${displayOrderNumber(order)}${batchId == 1 ? '' : '-${batchId - 1}'}',
    stamp: '${batch['createdAt'] ?? order['createdAt']}',
    lines: lines,
    totalCents: lines.fold<int>(0, (n, l) => n + l.amountCents),
    platformTotalCents: isPlatform(order) ? orderTotalCents(order) : null,
    externalCode: isPlatform(order)
        ? '${order['platformSnapshot']?['orderCode'] ?? order['platformSnapshot']?['orderId'] ?? order['platformPackageId'] ?? ''}'
        : '',
  );
}

TicketDocument billDocument(Json order) => TicketDocument(
  kind: TicketKind.bill,
  orderId: order['id'] as int,
  batchId: 0,
  source: '${order['source']}',
  destination: _destination(order),
  reference: '#${displayOrderNumber(order)}',
  stamp: utcNow(),
  lines: checkLines(order).map((l) => _line(l.line)).toList(),
  totalCents: orderTotalCents(order),
  paidCents: orderPaidCents(order),
  dueCents: orderDueCents(order),
  payments: [
    for (final p in asMaps(order['payments']))
      '${p['method']} · ${formatTry(paymentNetCents(p))}',
  ],
);

/// Captured in the same SQLite transaction as a newly queued batch. Later
/// cancellations, price edits and platform revisions cannot rewrite that ticket.
void freezeKitchenTickets(Json state) {
  for (final raw in (state['printJobs'] as List? ?? []).whereType<Map>()) {
    if (raw['ticketSnapshot'] != null) continue;
    try {
      raw['ticketSnapshot'] = kitchenTicket(
        state,
        raw.cast<String, dynamic>(),
        useSnapshot: false,
      ).toJson();
    } on FormatException {
      /* Keep old orphan jobs inspectable without blocking unrelated writes. */
    }
  }
}
