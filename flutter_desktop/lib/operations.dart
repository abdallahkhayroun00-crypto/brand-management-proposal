import 'pos_logic.dart';

String utcNow() => DateTime.now().toUtc().toIso8601String();
bool isPlatform(Json o) => ['Yemeksepeti', 'Trendyol Go'].contains(o['source']);
void requireLocal(Json o) {
  if (isPlatform(o)) {
    throw const FormatException('Platform tahsilatı kasaya alınmaz');
  }
}

void requireOpen(Json o) {
  if (o['closed'] == true || o['cancelled'] == true) {
    throw const FormatException('Hesap kapalı');
  }
}

/// Stable batch:index keys match the phone split-check protocol.
class CheckLine {
  const CheckLine(this.key, this.line);
  final String key;
  final Json line;
  int get total => cents(line['price']) * (line['qty'] as int);
}

List<CheckLine> checkLines(Json o) => [
  for (final b in asMaps(o['batches']))
    for (var i = 0; i < (b['lines'] as List).length; i++)
      if (b['lines'][i]['voided'] != true &&
          b['lines'][i]['correction'] != true)
        CheckLine(
          '${b['id']}:$i',
          Map<String, dynamic>.from(b['lines'][i] as Map),
        ),
];
int allocatedTo(Json o, String key) => asMaps(o['guestChecks']).fold(
  0,
  (sum, g) =>
      sum +
      asMaps(g['allocations'])
          .where((a) => a['key'] == key)
          .fold<int>(0, (n, a) => n + (a['cents'] as int)),
);
int guestBalance(Json o, int id) {
  final g = asMaps(o['guestChecks']).firstWhere(
    (g) => g['id'] == id,
    orElse: () => throw const FormatException('Kişi bulunamadı'),
  );
  final allocated = asMaps(
    g['allocations'],
  ).fold<int>(0, (n, a) => n + (a['cents'] as int));
  final paid = asMaps(
    o['payments'],
  ).fold<int>(0, (n, p) => n + paymentGuestCents(p, id));
  return allocated - paid;
}

int paymentNetCents(Json p) => p['reversed'] == true
    ? 0
    : cents(p['amount']) -
          asMaps(p['refunds']).fold<int>(0, (n, r) => n + cents(r['amount']));

void addGuest(Json o, String name) {
  requireLocal(o);
  requireOpen(o);
  if (name.trim().isEmpty) throw const FormatException('Kişi adı gerekli');
  final guests = o.putIfAbsent('guestChecks', () => <dynamic>[]) as List;
  final id =
      asMaps(
        guests,
      ).fold<int>(0, (n, g) => (g['id'] as int) > n ? g['id'] as int : n) +
      1;
  guests.add({'id': id, 'name': name.trim(), 'allocations': <dynamic>[]});
}

void allocateProduct(Json o, int guestId, String key, int amount) {
  requireLocal(o);
  requireOpen(o);
  final line = checkLines(o).firstWhere(
    (l) => l.key == key,
    orElse: () => throw const FormatException('Ürün bulunamadı'),
  );
  final g = (o['guestChecks'] as List).cast<Map>().firstWhere(
    (g) => g['id'] == guestId,
  );
  final allocations = g['allocations'] as List;
  final previous = asMaps(allocations)
      .where((a) => a['key'] == key)
      .fold<int>(0, (n, a) => n + (a['cents'] as int));
  if (amount < 0 ||
      allocatedTo(o, key) - previous + amount > line.total ||
      guestBalance(o, guestId) - previous + amount < 0) {
    throw const FormatException('Ürün payı veya ödenen kişi bakiyesi aşıldı');
  }
  allocations.removeWhere((a) => a['key'] == key);
  if (amount > 0) allocations.add({'key': key, 'cents': amount});
}

void resetGuests(Json o) {
  requireOpen(o);
  if (orderPaidCents(o) > 0) {
    throw const FormatException('Önce ödemeleri iade edin');
  }
  o['guestChecks'] = <dynamic>[];
}

void splitEqually(Json o, int count) {
  requireLocal(o);
  requireOpen(o);
  if (count < 2 ||
      count > 10 ||
      orderPaidCents(o) != 0 ||
      asMaps(o['guestChecks']).isNotEmpty) {
    throw const FormatException(
      '2–10 kişi; önce mevcut ödemeleri / payları kontrol edin',
    );
  }
  for (var i = 0; i < count; i++) {
    addGuest(o, 'Kişi ${i + 1}');
  }
  final total = orderTotalCents(o), lines = checkLines(o);
  var lineIndex = 0, used = 0;
  for (var i = 0; i < count; i++) {
    var need = total ~/ count + (i < total % count ? 1 : 0);
    while (need > 0 && lineIndex < lines.length) {
      final l = lines[lineIndex],
          left = l.total - used,
          portion = left < need ? left : need;
      allocateProduct(o, i + 1, l.key, portion);
      need -= portion;
      used += portion;
      if (used == l.total) {
        lineIndex++;
        used = 0;
      }
    }
  }
}

void changeGuest(Json o, int id, String name, {bool remove = false}) {
  requireLocal(o);
  requireOpen(o);
  final guests = o['guestChecks'] as List;
  final guest = guests.cast<Map>().firstWhere((g) => g['id'] == id);
  if (remove) {
    if (asMaps(guest['allocations']).isNotEmpty ||
        asMaps(o['payments']).any(
          (p) =>
              p['guestCheckId'] == id ||
              asMaps(p['guestAllocations']).any((a) => a['guestCheckId'] == id),
        )) {
      throw const FormatException(
        'Önce kişi paylarını / ödemeleri kontrol edin',
      );
    }
    guests.remove(guest);
  } else {
    if (name.trim().isEmpty) throw const FormatException('Ad gerekli');
    guest['name'] = name.trim();
  }
}

String billText(Json o) => [
  'NOHUT FALAFEL · HESAP ÖZETİ',
  'MALİ FİŞ DEĞİLDİR',
  '#${o['id']} · ${o['source']} · ${o['table'] ?? ''}',
  for (final l in checkLines(o))
    '${l.line['qty']} × ${l.line['name']} · ${formatTry(l.total)}',
  'Toplam ${formatTry(orderTotalCents(o))}',
  'Net tahsilat ${formatTry(orderPaidCents(o))}',
  'Kalan ${formatTry(orderDueCents(o))}',
  for (final p in asMaps(o['payments']))
    '${p['method']} · ${formatTry(paymentNetCents(p))} · ${p['guestName'] ?? ''}',
].join('\n');

void assignExistingPayment(Json o, int index, int guestId, int amount) {
  requireLocal(o);
  final p = ((o['payments'] as List)[index] as Map).cast<String, dynamic>();
  if (p['guestCheckId'] != null || p['reversed'] == true) {
    throw const FormatException(
      'Bu ödeme doğrudan bir kişiye ait / iade edilmiş',
    );
  }
  final mappings = p.putIfAbsent('guestAllocations', () => <dynamic>[]) as List;
  final previous = asMaps(mappings)
      .where((a) => a['guestCheckId'] == guestId)
      .fold<int>(0, (n, a) => n + cents(a['amount']));
  final total = asMaps(mappings).fold<int>(0, (n, a) => n + cents(a['amount']));
  if ((o['closed'] == true || o['cancelled'] == true) && amount > previous) {
    throw const FormatException(
      'Kapalı hesapta yalnız eşlemeyi azaltabilirsiniz',
    );
  }
  if (amount < 0 ||
      total - previous + amount > paymentNetCents(p) ||
      guestBalance(o, guestId) + previous < amount) {
    throw const FormatException('Tahsilat veya kişi payı aşıldı');
  }
  mappings.removeWhere((a) => a['guestCheckId'] == guestId);
  if (amount > 0) {
    mappings.add({'guestCheckId': guestId, 'amount': fromCents(amount)});
  }
}

void refundPayment(Json o, int index, int amount, String reason) {
  requireLocal(o);
  final payments = o['payments'] as List;
  if (index < 0 ||
      index >= payments.length ||
      reason.trim().isEmpty ||
      amount <= 0) {
    throw const FormatException('İade tutarı / nedeni gerekli');
  }
  final p = (payments[index] as Map).cast<String, dynamic>();
  if (amount > paymentNetCents(p)) {
    throw const FormatException('Tahsilattan fazla iade edilemez');
  }
  if (asMaps(
        p['guestAllocations'],
      ).fold<int>(0, (n, a) => n + cents(a['amount'])) >
      paymentNetCents(p) - amount) {
    throw const FormatException('Önce geçmiş ödeme kişi eşlemesini azaltın');
  }
  (p.putIfAbsent('refunds', () => <dynamic>[]) as List).add({
    'amount': fromCents(amount),
    'createdAt': utcNow(),
    'reason': reason.trim(),
    'by': 'Kasa (PC)',
  });
  // Refunds and service/table release are independent. A closed historical check
  // is not reopened over a new occupant of the same physical table.
  (o['events'] as List).add(
    '${utcNow()} · İade ${formatTry(amount)} · $reason',
  );
}

void cancelProduct(
  Json state,
  int orderId,
  String key,
  int qty,
  String reason,
) {
  final o =
      mutableOrder(state, orderId) ??
      (throw const FormatException('Sipariş yok'));
  requireLocal(o);
  requireOpen(o);
  final parts = key.split(':');
  final b = (o['batches'] as List).cast<Map>().firstWhere(
    (b) => '${b['id']}' == parts[0],
  );
  final l = (b['lines'][int.parse(parts[1])] as Map).cast<String, dynamic>();
  final before = l['qty'] as int;
  if (reason.trim().isEmpty ||
      qty < 1 ||
      qty > before ||
      l['voided'] == true ||
      l['correction'] == true) {
    throw const FormatException('İptal adedi / nedeni geçersiz');
  }
  final remaining = cents(l['price']) * (before - qty);
  if (allocatedTo(o, key) > remaining ||
      orderTotalCents(o) - cents(l['price']) * qty < orderPaidCents(o)) {
    throw const FormatException(
      'Önce kişi payını azaltın ve fazla tahsilatı iade edin',
    );
  }
  l['originalQty'] ??= before;
  l['qty'] = before - qty;
  l['voided'] = l['qty'] == 0;
  final batches = o['batches'] as List;
  final id =
      asMaps(
        batches,
      ).fold<int>(0, (n, b) => (b['id'] as int) > n ? b['id'] as int : n) +
      1;
  batches.add({
    'id': id,
    'staff': 'Kasa (PC)',
    'time': nowTime(),
    'createdAt': utcNow(),
    'lines': [
      {
        'name': 'İPTAL: ${l['name']}',
        'qty': qty,
        'price': 0,
        'correction': true,
        'removed': [],
        'note': reason.trim(),
      },
    ],
  });
  (state['printJobs'] as List).add({
    'orderId': orderId,
    'batchId': id,
    'state': 'Bekliyor',
    'created': nowTime(),
  });
  (o.putIfAbsent('voids', () => <dynamic>[]) as List).add({
    'name': l['name'],
    'qty': qty,
    'price': l['price'],
    'reason': reason,
    'createdAt': utcNow(),
  });
  (o['events'] as List).add(
    '${utcNow()} · $qty × ${l['name']} iptal · $reason',
  );
}

void cancelLocalOrder(Json state, int id, String reason) {
  final o = mutableOrder(state, id)!;
  requireLocal(o);
  requireOpen(o);
  if (orderPaidCents(o) > 0) {
    throw const FormatException('Önce tüm ödemeleri iade edin');
  }
  if (reason.trim().isEmpty) {
    throw const FormatException('İptal nedeni gerekli');
  }
  resetGuests(o);
  for (final l in checkLines(o)) {
    cancelProduct(state, id, l.key, l.line['qty'] as int, reason);
  }
  o['closed'] = true;
  o['cancelled'] = true;
  o['tableReleased'] = true;
}

void setLocalService(Json o, String status) {
  requireLocal(o);
  requireOpen(o);
  const sequence = ['Hazırlanıyor', 'Hazır', 'Teslim Edildi'];
  final old = sequence.indexOf('${o['serviceStatus']}');
  if (sequence.indexOf(status) != old + 1) {
    throw const FormatException('Geçersiz hizmet geçişi');
  }
  o['serviceStatus'] = status;
  (o['events'] as List).add('${utcNow()} · Hizmet: $status');
}

void closePickup(Json o) {
  requireLocal(o);
  requireOpen(o);
  if (o['source'] != 'Gel-Al' ||
      orderDueCents(o) != 0 ||
      o['serviceStatus'] != 'Teslim Edildi') {
    throw const FormatException('Önce ödeme ve teslim tamamlanmalı');
  }
  o['closed'] = true;
}

Json cashBook(Json s) =>
    (s.putIfAbsent(
              'cashBook',
              () => {
                'sessions': <dynamic>[],
                'movements': <dynamic>[],
                'next': 1,
              },
            )
            as Map)
        .cast<String, dynamic>();
Json? activeCash(Json s) => asMaps(
  cashBook(s)['sessions'],
).where((c) => c['closedAt'] == null).firstOrNull;
void openCash(Json s, int opening) {
  if (opening < 0 || activeCash(s) != null) {
    throw const FormatException('Açık kasa var veya tutar geçersiz');
  }
  final book = cashBook(s), id = cashBook(s)['next'] as int;
  book['next'] = id + 1;
  (book['sessions'] as List).add({
    'id': id,
    'openedAt': utcNow(),
    'openingCents': opening,
    'openedBy': 'Kasa (PC)',
    // Exclude pre-existing events even when the OS clock gives opening and
    // previous-shift refunds the exact same timestamp. Preserve multiplicity.
    'openingLedger': ledger(s).map((e) => e.identity).toList(),
    'closedAt': null,
  });
}

class LedgerEntry {
  const LedgerEntry(
    this.orderId,
    this.source,
    this.method,
    this.kind,
    this.amount,
    this.stamp,
    this.staff,
  );
  final int orderId, amount;
  final String source, method, kind, stamp, staff;
  String get identity => '$orderId|$source|$method|$kind|$amount|$stamp|$staff';
}

List<LedgerEntry> ledger(Json state) => [
  for (final o in asMaps(state['orders'])) ...[
    for (final p in asMaps(o['payments'])) ...[
      LedgerEntry(
        o['id'] as int,
        '${o['source']}',
        '${p['method']}',
        'Tahsilat',
        cents(p['amount']),
        '${p['createdAt'] ?? ''}',
        '${p['by'] ?? ''}',
      ),
      if (p['reversed'] == true)
        LedgerEntry(
          o['id'] as int,
          '${o['source']}',
          '${p['method']}',
          'İade',
          -cents(p['amount']),
          '${p['reversedAt'] ?? ''}',
          '${p['by'] ?? ''}',
        ),
      for (final r in asMaps(p['refunds']))
        LedgerEntry(
          o['id'] as int,
          '${o['source']}',
          '${p['method']}',
          'İade',
          -cents(r['amount']),
          '${r['createdAt']}',
          '${r['by'] ?? 'Kasa (PC)'}',
        ),
    ],
    if (isPlatform(o))
      for (final a in asMaps(o['platformAdjustments']))
        LedgerEntry(
          o['id'] as int,
          '${o['source']}',
          'Platform',
          'Platform düzeltmesi',
          cents(a['amount']),
          '${a['stamp']}',
          '${o['source']}',
        ),
  ],
];

class SaleEntry {
  const SaleEntry(
    this.orderId,
    this.source,
    this.staff,
    this.product,
    this.quantity,
    this.amount,
    this.stamp,
  );
  final int orderId, quantity, amount;
  final String source, staff, product, stamp;
}

List<SaleEntry> sales(Json state) => [
  for (final o in asMaps(state['orders']))
    if (o['cancelled'] != true)
      for (final b in asMaps(o['batches']))
        for (final l in asMaps(b['lines']))
          if (l['voided'] != true && l['correction'] != true)
            SaleEntry(
              o['id'] as int,
              '${o['source']}',
              '${b['staff']}',
              '${l['name'] ?? l['productKey']}',
              l['qty'] as int,
              cents(l['price']) * (l['qty'] as int),
              '${b['createdAt'] ?? o['createdAt'] ?? ''}',
            ),
];
String salesCsv(Iterable<SaleEntry> rows) =>
    '\uFEFF${[
      ['Sipariş', 'Kaynak', 'Personel', 'Ürün', 'Adet', 'Ürün toplamı kuruş', 'Tarih UTC'],
      ...rows.map((r) => [r.orderId, r.source, r.staff, r.product, r.quantity, r.amount, r.stamp]),
    ].map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';

int expectedCash(Json s, Json c, {String? end}) {
  final stop = end ?? c['closedAt'] as String? ?? utcNow();
  final start = c['openedAt'] as String;
  final baseline = <String, int>{};
  for (final key in c['openingLedger'] as List? ?? []) {
    baseline['$key'] = (baseline['$key'] ?? 0) + 1;
  }
  final receipts = ledger(s)
      .where((e) {
        final existing = baseline[e.identity] ?? 0;
        if (existing == 0) return true;
        baseline[e.identity] = existing - 1;
        return false;
      })
      .where(
        (e) =>
            e.method == 'Nakit' &&
            !['Yemeksepeti', 'Trendyol Go'].contains(e.source) &&
            DateTime.tryParse(e.stamp) != null &&
            !DateTime.parse(e.stamp).isBefore(DateTime.parse(start)) &&
            !DateTime.parse(e.stamp).isAfter(DateTime.parse(stop)),
      )
      .fold<int>(0, (n, e) => n + e.amount);
  return (c['openingCents'] as int) +
      receipts +
      asMaps(cashBook(s)['movements'])
          .where((m) => m['sessionId'] == c['id'])
          .fold<int>(0, (n, m) => n + (m['cents'] as int));
}

void moveCash(Json s, int signed, String reason) {
  final c = activeCash(s);
  if (c == null || signed == 0 || reason.trim().isEmpty) {
    throw const FormatException('Açık kasa, tutar ve açıklama gerekli');
  }
  if (expectedCash(s, c) + signed < 0) {
    throw const FormatException('Kasada yeterli nakit yok');
  }
  (cashBook(s)['movements'] as List).add({
    'sessionId': c['id'],
    'cents': signed,
    'note': reason.trim(),
    'at': utcNow(),
    'by': 'Kasa (PC)',
  });
}

void closeCash(Json s, int counted) {
  if (counted < 0) throw const FormatException('Sayım geçersiz');
  final active = activeCash(s);
  if (active == null) throw const FormatException('Açık kasa yok');
  final c = (cashBook(s)['sessions'] as List).cast<Map>().firstWhere(
    (c) => c['id'] == active['id'],
  );
  final end = utcNow(), expected = expectedCash(s, active, end: utcNow());
  c.addAll(<String, dynamic>{
    'closedAt': end,
    'countedCents': counted,
    'expectedCents': expected,
    'differenceCents': counted - expected,
    'closedBy': 'Kasa (PC)',
  });
}

String csvCell(Object? value) {
  var text = '${value ?? ''}';
  // Prevent spreadsheet formula execution in names/notes received over LAN.
  if (RegExp(r'^\s*[=+@-]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String ledgerCsv(Iterable<LedgerEntry> rows) =>
    '\uFEFF${[
      ['Sipariş', 'Kaynak', 'Yöntem', 'Tür', 'Tutar (kuruş)', 'Tarih UTC', 'Personel'],
      ...rows.map((r) => [r.orderId, r.source, r.method, r.kind, r.amount, r.stamp, r.staff]),
    ].map((row) => row.map(csvCell).join(',')).join('\r\n')}\r\n';

void saveEmployee(Json state, int? id, String name, String role, bool active) {
  if (name.trim().isEmpty || !['Personel', 'Yönetici'].contains(role)) {
    throw const FormatException('Ad / görev geçersiz');
  }
  final employees = state['employees'] as List;
  if (asMaps(employees).any(
    (e) =>
        e['id'] != id &&
        '${e['name']}'.toLowerCase() == name.trim().toLowerCase(),
  )) {
    throw const FormatException('Bu ad zaten var');
  }
  if (id == null) {
    id =
        asMaps(
          employees,
        ).fold<int>(0, (n, e) => (e['id'] as int) > n ? e['id'] as int : n) +
        1;
    employees.add({
      'id': id,
      'name': name.trim(),
      'role': role,
      'active': active,
    });
  } else {
    final person = employees.cast<Map>().firstWhere((e) => e['id'] == id);
    person['name'] = name.trim();
    person['role'] = role;
    person['active'] = active;
  }
}

String receiptText(Json state, Json job) {
  final o = mutableOrder(state, job['orderId'] as int);
  if (o == null) throw const FormatException('Sipariş bulunamadı');
  final batch = asMaps(
    o['batches'],
  ).where((b) => b['id'] == job['batchId']).firstOrNull;
  if (batch == null) throw const FormatException('Mutfak partisi bulunamadı');
  return [
    'NOHUT FALAFEL · MUTFAK',
    'MALİ FİŞ DEĞİLDİR',
    '#${o['id']} · ${o['source']} · ${o['table'] == null ? 'Gel-Al / Platform' : 'Masa ${o['table']}'}',
    'Parti ${batch['id']} · ${batch['staff']} · ${batch['createdAt'] ?? batch['time']}',
    for (final l in asMaps(batch['lines']))
      if (l['voided'] != true || l['correction'] == true)
        '${l['qty']} × ${l['name'] ?? l['productKey']}\n'
            '${(l['removed'] as List? ?? []).isEmpty ? '' : 'Çıkar: ${(l['removed'] as List).join(', ')}\n'}'
            '${l['note'] ?? ''}',
  ].join('\n');
}
