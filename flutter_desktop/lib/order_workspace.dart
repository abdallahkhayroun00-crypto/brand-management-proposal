import 'package:flutter/material.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'order_actions.dart';

class OrderWorkspace extends StatefulWidget {
  const OrderWorkspace({
    super.key,
    required this.order,
    required this.edit,
    required this.onAdd,
    required this.onPay,
    required this.onGuestPay,
    required this.onClose,
  });
  final Json order;
  final EditState edit;
  final VoidCallback onAdd, onPay, onClose;
  final ValueChanged<Json> onGuestPay;
  @override
  State<OrderWorkspace> createState() => _OrderWorkspaceState();
}

class _OrderWorkspaceState extends State<OrderWorkspace> {
  String tab = 'Ürünler';
  String? selectedLine;
  int? selectedGuest;
  Json get o => widget.order;
  int get id => o['id'] as int;
  bool get open =>
      o['closed'] != true && o['cancelled'] != true && !isPlatform(o);
  void edit(void Function(Json) change) => widget.edit(change);
  int share(Json guest, String key) => asMaps(guest['allocations'])
      .where((a) => a['key'] == key)
      .fold<int>(0, (n, a) => n + (a['cents'] as int));

  Future<void> amountFor(CheckLine line, Json guest, {int? amount}) async {
    if (amount == null) {
      final v =
          await askFields(context, '${guest['name']} · ${line.line['name']}', [
            (
              'Kişinin ürün payı ₺ (0 = geri al)',
              (share(guest, line.key) / 100).toStringAsFixed(2),
            ),
          ]);
      if (v == null) return;
      amount = parseMoney(v[0]);
    }
    final value = amount;
    edit(
      (s) => allocateProduct(
        mutableOrder(s, id)!,
        guest['id'] as int,
        line.key,
        value,
      ),
    );
  }

  Future<void> cancel(CheckLine line) async {
    final v = await askFields(context, '${line.line['name']} · İptal', [
      ('Adet', '1'),
      ('Neden', ''),
    ]);
    if (v != null) {
      edit((s) => cancelProduct(s, id, line.key, parseInteger(v[0]), v[1]));
    }
  }

  Widget products({bool splitting = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (checkLines(o).isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Aktif ürün yok.'),
        ),
      for (final line in checkLines(o))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selectedLine == line.key
                ? const Color(0xffedf5e9)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              key: ValueKey('check-line-${line.key}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => selectedLine = line.key),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selectedLine == line.key
                        ? const Color(0xff89ad91)
                        : const Color(0xffe4e9e3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedLine == line.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 18,
                      color: const Color(0xff527752),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${line.line['qty']}×',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${line.line['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if ('${line.line['note'] ?? ''}'.isNotEmpty)
                            Text(
                              '${line.line['note']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if ((line.line['removed'] as List? ?? []).isNotEmpty)
                            Text(
                              'Çıkar: ${(line.line['removed'] as List).join(', ')}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (splitting)
                            Text(
                              'Kalan pay: ${formatTry(line.total - allocatedTo(o, line.key))}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (splitting)
                            for (final g in asMaps(o['guestChecks']))
                              if (share(g, line.key) > 0)
                                Text(
                                  '${g['name']}: ${formatTry(share(g, line.key))}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff285940),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatTry(line.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (!splitting && selectedLine != null && open)
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => cancel(
                checkLines(o).firstWhere((l) => l.key == selectedLine),
              ),
              icon: const Icon(Icons.remove_circle_outline, size: 17),
              label: const Text('Seçili Ürünü İptal Et'),
            ),
            TextButton(
              onPressed: () => setState(() => tab = 'Hesap Böl'),
              child: const Text('Kişiye Paylaştır'),
            ),
          ],
        ),
    ],
  );

  Widget split() {
    final guests = asMaps(o['guestChecks']);
    final guest = guests.where((g) => g['id'] == selectedGuest).firstOrNull;
    final line = checkLines(o).where((l) => l.key == selectedLine).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: open
                  ? () async {
                      final v = await askFields(context, 'Kişi Ekle', [
                        ('Ad', ''),
                      ]);
                      if (v != null) {
                        edit((s) => addGuest(mutableOrder(s, id)!, v[0]));
                      }
                    }
                  : null,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Kişi Ekle'),
            ),
            PopupMenuButton<int>(
              tooltip: 'Eşit Böl',
              onSelected: (n) =>
                  edit((s) => splitEqually(mutableOrder(s, id)!, n)),
              itemBuilder: (_) => [
                for (var n = 2; n <= 10; n++)
                  PopupMenuItem(
                    value: n,
                    enabled: open,
                    child: Text('$n kişiye eşit böl'),
                  ),
              ],
              child: const Chip(
                avatar: Icon(Icons.balance, size: 17),
                label: Text('Eşit Böl ▾'),
              ),
            ),
            IconButton(
              tooltip: 'Payları Sıfırla',
              onPressed: open
                  ? () => edit((s) => resetGuests(mutableOrder(s, id)!))
                  : null,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (guests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Kişi ekleyin veya hesabı eşit bölün. Ürün ve kişi seçerek pay atayın.',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in guests)
              ChoiceChip(
                key: ValueKey('guest-${g['id']}'),
                label: Text(
                  '${g['name']} · ${formatTry(guestBalance(o, g['id'] as int))}',
                ),
                selected: selectedGuest == g['id'],
                onSelected: (_) =>
                    setState(() => selectedGuest = g['id'] as int),
              ),
          ],
        ),
        if (guest != null) ...[
          const SizedBox(height: 12),
          Text(
            '${guest['name']} · Kalan ${formatTry(guestBalance(o, guest['id'] as int))}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 6,
            children: [
              if (open && guestBalance(o, guest['id'] as int) > 0)
                FilledButton(
                  onPressed: () => widget.onGuestPay(guest),
                  child: const Text('Kişi Ödemesi'),
                ),
              TextButton(
                onPressed: open
                    ? () async {
                        final v = await askFields(context, 'Kişi Adı', [
                          ('Ad', '${guest['name']}'),
                        ]);
                        if (v != null) {
                          edit(
                            (s) => changeGuest(
                              mutableOrder(s, id)!,
                              guest['id'] as int,
                              v[0],
                            ),
                          );
                        }
                      }
                    : null,
                child: const Text('Adını Değiştir'),
              ),
              TextButton(
                onPressed: open
                    ? () => edit(
                        (s) => changeGuest(
                          mutableOrder(s, id)!,
                          guest['id'] as int,
                          '',
                          remove: true,
                        ),
                      )
                    : null,
                child: const Text('Boş Kişiyi Kaldır'),
              ),
            ],
          ),
        ],
        const Divider(height: 24),
        const Text(
          '1. Ürünü seç → 2. Kişiyi seç → 3. Payı ata',
          style: TextStyle(fontSize: 12, color: Color(0xff7c8b80)),
        ),
        const SizedBox(height: 12),
        products(splitting: true),
        if (line != null && guest != null && open)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('assign-product'),
                onPressed: () => amountFor(
                  line,
                  guest,
                  amount:
                      line.total -
                      allocatedTo(o, line.key) +
                      share(guest, line.key),
                ),
                child: Text('Kalan Payı ${guest['name']} İçin Ata'),
              ),
              OutlinedButton(
                onPressed: () => amountFor(line, guest),
                child: const Text('Tutar Gir / Düzenle'),
              ),
            ],
          ),
      ],
    );
  }

  Widget payments() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (asMaps(o['payments']).isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Henüz tahsilat yok.'),
        ),
      for (var index = 0; index < asMaps(o['payments']).length; index++)
        Builder(
          builder: (context) {
            final p = asMaps(o['payments'])[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          p['method'] == 'Nakit'
                              ? Icons.payments_outlined
                              : Icons.credit_card_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p['method']} · ${p['guestName'] ?? 'Genel Ödeme'}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(formatTry(paymentNetCents(p))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${p['createdAt']}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xff7c8b80),
                      ),
                    ),
                    for (final r in asMaps(p['refunds']))
                      Text(
                        'İade ${formatTry(cents(r['amount']))} · ${r['reason']} · ${r['createdAt']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (!isPlatform(o) && paymentNetCents(p) > 0)
                          TextButton(
                            onPressed: () async {
                              final v =
                                  await askFields(context, 'Tahsilat İadesi', [
                                    (
                                      'Tutar ₺',
                                      (paymentNetCents(p) / 100)
                                          .toStringAsFixed(2),
                                    ),
                                    ('Neden', ''),
                                  ]);
                              if (v != null) {
                                edit(
                                  (s) => refundPayment(
                                    mutableOrder(s, id)!,
                                    index,
                                    parseMoney(v[0]),
                                    v[1],
                                  ),
                                );
                              }
                            },
                            child: const Text('Kısmi / Tam İade'),
                          ),
                        if (!isPlatform(o) && p['guestCheckId'] == null)
                          for (final g in asMaps(o['guestChecks']))
                            TextButton(
                              onPressed: () async {
                                final previous = asMaps(p['guestAllocations'])
                                    .where((a) => a['guestCheckId'] == g['id'])
                                    .fold<int>(
                                      0,
                                      (n, a) => n + cents(a['amount']),
                                    );
                                final v = await askFields(
                                  context,
                                  'Tahsilatı Kişiye Eşleştir',
                                  [
                                    (
                                      '${g['name']} payı ₺ (0 = geri al)',
                                      (previous / 100).toStringAsFixed(2),
                                    ),
                                  ],
                                );
                                if (v != null) {
                                  edit(
                                    (s) => assignExistingPayment(
                                      mutableOrder(s, id)!,
                                      index,
                                      g['id'] as int,
                                      parseMoney(v[0]),
                                    ),
                                  );
                                }
                              },
                              child: Text('${g['name']} Eşleştir'),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ],
  );

  Widget summary(String label, int value, {bool emphasis = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xff7c8b80)),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          formatTry(value),
          style: TextStyle(
            fontSize: emphasis ? 19 : 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xff183b2c),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!checkLines(o).any((l) => l.key == selectedLine)) selectedLine = null;
    final guests = asMaps(o['guestChecks']);
    if (!guests.any((g) => g['id'] == selectedGuest)) selectedGuest = null;
    final paymentGuest = guests
        .where((g) => g['id'] == selectedGuest)
        .firstOrNull;
    final status = o['cancelled'] == true
        ? 'İptal'
        : o['closed'] == true
        ? 'Kapalı'
        : '${o['serviceStatus'] ?? o['demoRemoteStatus'] ?? 'Açık'}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o['source'] == 'Masa'
                            ? 'Masa ${o['table']}'
                            : '${o['source']}',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Sipariş #$id',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xff7c8b80),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: open
                        ? const Color(0xfffff3df)
                        : const Color(0xffedf5e9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'bill') {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hesap Özeti'),
                          content: SingleChildScrollView(
                            child: SelectableText(billText(o)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      final v = await askFields(context, 'Siparişi İptal Et', [
                        ('Neden', ''),
                      ]);
                      if (v != null) {
                        edit((s) => cancelLocalOrder(s, id, v[0]));
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'bill',
                      child: Text('Hesap Özeti Önizle'),
                    ),
                    if (open)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Siparişi İptal Et'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff3f6ef),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: summary('Toplam', orderTotalCents(o))),
                  const SizedBox(width: 8),
                  Expanded(child: summary('Alınan', orderPaidCents(o))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: summary('Kalan', orderDueCents(o), emphasis: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final t in [
                  'Ürünler',
                  'Hesap Böl',
                  'Tahsilatlar',
                  'Geçmiş',
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        key: ValueKey('detail-tab-$t'),
                        onTap: () => setState(() => tab = t),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tab == t
                                ? const Color(0xff183b2c)
                                : const Color(0xfff3f6ef),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tab == t
                                    ? Colors.white
                                    : const Color(0xff183b2c),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: switch (tab) {
                  'Hesap Böl' =>
                    isPlatform(o)
                        ? const Text('Platform hesabı yerel kasada bölünmez.')
                        : split(),
                  'Tahsilatlar' => payments(),
                  'Geçmiş' => Column(
                    children: [
                      for (final event in o['events'] as List? ?? [])
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history, size: 18),
                          title: Text(
                            '$event',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  _ => products(),
                },
              ),
            ),
            const Divider(height: 20),
            if (open)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('order-payment'),
                    onPressed: orderDueCents(o) > 0 && guests.isEmpty
                        ? widget.onPay
                        : guests.isNotEmpty
                        ? paymentGuest == null
                              ? () => setState(() => tab = 'Hesap Böl')
                              : guestBalance(o, paymentGuest['id'] as int) > 0
                              ? () => widget.onGuestPay(paymentGuest)
                              : null
                        : null,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(
                      guests.isEmpty
                          ? 'Ödeme Al'
                          : paymentGuest == null
                          ? 'Kişi Seç'
                          : '${paymentGuest['name']} · Öde',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ek Sipariş'),
                  ),
                  if (['Hazırlanıyor', 'Hazır'].contains(o['serviceStatus']))
                    OutlinedButton(
                      onPressed: () => edit((s) {
                        final order = mutableOrder(s, id)!;
                        if (order['serviceStatus'] == 'Hazır') {
                          setLocalService(order, 'Teslim Edildi');
                        } else {
                          requestOrderAction(s, id, 'ready', pcActor);
                        }
                      }),
                      child: Text(
                        o['serviceStatus'] == 'Hazır' ? 'Teslim Et' : 'Hazır',
                      ),
                    ),
                  if (orderDueCents(o) == 0)
                    OutlinedButton(
                      onPressed: o['source'] == 'Masa'
                          ? widget.onClose
                          : () =>
                                edit((s) => closePickup(mutableOrder(s, id)!)),
                      child: const Text('Hesabı Kapat'),
                    ),
                ],
              ),
            if (open && guests.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  paymentGuest == null
                      ? 'Kişi ödemeleri: Hesap Böl → kişi seçin.'
                      : '${paymentGuest['name']} · Kalan kişi payı ${formatTry(guestBalance(o, paymentGuest['id'] as int))}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff7c8b80),
                  ),
                ),
              ),
            if (!open)
              Text(
                isPlatform(o)
                    ? 'Platform siparişi · Durum işlemleri Online Siparişler ekranında.'
                    : 'Kapalı hesap · İşlemler ve tahsilat geçmişi sekmelerde.',
                style: const TextStyle(fontSize: 12, color: Color(0xff7c8b80)),
              ),
          ],
        ),
      ),
    );
  }
}
