import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'operations.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'platform_workflows.dart';
import 'workspace_ui.dart';

class ReportsWorkspace extends StatefulWidget {
  const ReportsWorkspace({
    super.key,
    required this.state,
    required this.edit,
    required this.onOrder,
  });
  final Json state;
  final EditState edit;
  final ValueChanged<int> onOrder;
  @override
  State<ReportsWorkspace> createState() => _ReportsWorkspaceState();
}

class _ReportsWorkspaceState extends State<ReportsWorkspace> {
  String tab = 'Özet',
      source = 'Tümü',
      method = 'Tümü',
      kind = 'Tümü',
      staff = 'Tümü',
      search = '',
      financeType = 'Tümü',
      period = 'Tüm Tarihler';
  DateTimeRange? dates;
  bool inDate(String stamp) {
    if (dates == null) return true;
    final d = DateTime.tryParse(stamp)?.toUtc().add(const Duration(hours: 3));
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(dates!.start) && !day.isAfter(dates!.end);
  }

  void selectPeriod(String value) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3)),
        today = DateTime(now.year, now.month, now.day);
    setState(() {
      period = value;
      dates = value == 'Tüm Tarihler'
          ? null
          : DateTimeRange(
              start: today.subtract(
                Duration(
                  days: value == 'Bugün'
                      ? 0
                      : value == '7 Gün'
                      ? 6
                      : 29,
                ),
              ),
              end: today,
            );
    });
  }

  Future<void> export(String content, String name) async {
    final fields = await askFields(context, 'CSV Kaydet', [
      ('Dosya yolu', path.join(Directory.current.path, '$name.csv')),
    ]);
    if (fields == null) return;
    try {
      final file = File(fields[0]);
      if (file.existsSync()) {
        throw const FormatException('Dosya zaten var. Yeni bir ad seçin.');
      }
      file.writeAsStringSync(content);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV kaydedildi: ${file.path}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> change, {
    double width = 155,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('report-$label-$value'),
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: label == 'Personel' && tab == 'Platform Mutabakatı'
          ? null
          : (v) => setState(() => change(v!)),
    ),
  );
  Widget ranking(
    String title,
    Map<String, int> values, {
    bool money = false,
    ValueChanged<String>? onSelect,
  }) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty || entries.first.value <= 0
        ? 1
        : entries.first.value;
    return WorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: entries.isEmpty
                ? const WorkEmpty(
                    title: 'Henüz veri yok',
                    message: 'Siparişler ve tahsilatlar burada özetlenir.',
                  )
                : ListView(
                    children: [
                      for (final e in entries.take(12))
                        InkWell(
                          onTap: onSelect == null
                              ? null
                              : () => onSelect(e.key),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.key,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      money
                                          ? formatTry(e.value)
                                          : '${e.value} adet',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (onSelect != null)
                                      const Icon(Icons.chevron_right, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (e.value / max).clamp(0.0, 1.0),
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(8),
                                  color: const Color(0xff527752),
                                  backgroundColor: const Color(0xffedf3e8),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = copyJson(widget.state), hub = platformHub(state);
    bool shared(String src, String by, String stamp) =>
        (source == 'Tümü' || source == src) &&
        (staff == 'Tümü' || staff == by) &&
        inDate(stamp);
    final baseReceipts = ledger(
      state,
    ).where((r) => shared(r.source, r.staff, r.stamp)).toList();
    final receipts = baseReceipts
        .where(
          (r) =>
              (method == 'Tümü' || method == r.method) &&
              (kind == 'Tümü' || kind == r.kind) &&
              '${r.orderId} ${r.staff} ${r.source}'.toLowerCase().contains(
                search.toLowerCase(),
              ),
        )
        .toList();
    final baseSales = sales(
      state,
    ).where((r) => shared(r.source, r.staff, r.stamp)).toList();
    final products = baseSales
        .where(
          (r) => '${r.orderId} ${r.product} ${r.staff}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    final people = {
      'Tümü',
      ...ledger(state).map((r) => r.staff).where((s) => s.isNotEmpty),
      ...sales(state).map((r) => r.staff).where((s) => s.isNotEmpty),
    }.toList();
    final productTotals = <String, int>{}, staffTotals = <String, int>{};
    for (final r in baseSales) {
      productTotals[r.product] = (productTotals[r.product] ?? 0) + r.quantity;
      staffTotals[r.staff] = (staffTotals[r.staff] ?? 0) + r.amount;
    }
    final staffRows = <List<String>>[
      for (final name in staffTotals.keys.where(
        (n) => n.toLowerCase().contains(search.toLowerCase()),
      ))
        [
          name,
          '${baseSales.where((r) => r.staff == name).map((r) => r.orderId).toSet().length}',
          '${baseSales.where((r) => r.staff == name).fold<int>(0, (n, r) => n + r.quantity)}',
          formatTry(staffTotals[name]!),
        ],
    ];
    final settlements = asMaps(hub['settlements'])
        .where(
          (r) =>
              (source == 'Tümü' || source == r['source']) &&
              inDate('${r['stamp']}'),
        )
        .toList();
    final finance = <List<Object?>>[
      for (final r in settlements)
        for (final type in [
          'Sale',
          'Return',
          'Commission',
          'SellerDiscount',
          'PaymentOrder',
        ])
          if (financeType == 'Tümü' || financeType == type)
            [
              r['orderId'],
              r['source'],
              type,
              type == 'Sale'
                  ? cents(r['gross'])
                  : type == 'Return'
                  ? -cents(r['refund'])
                  : type == 'Commission'
                  ? -cents(r['commission'])
                  : type == 'SellerDiscount'
                  ? cents(r['discount'])
                  : cents(r['net']),
              r['paymentOrderId'],
              r['paymentStatus'],
              r['stamp'],
            ],
    ];
    int net(String type) => baseReceipts
        .where((r) => type == 'Tümü' || r.method == type)
        .fold<int>(0, (n, r) => n + r.amount);
    String csv(List<List<Object?>> rows) =>
        '\uFEFF${rows.map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';
    void exportCurrent() {
      if (tab == 'Tahsilatlar') {
        export(ledgerCsv(receipts), 'nohut-tahsilat');
      } else if (tab == 'Ürünler') {
        export(salesCsv(products), 'nohut-urunler');
      } else if (tab == 'Personel') {
        export(
          csv([
            ['Personel', 'Sipariş', 'Adet', 'Ürün toplamı TRY'],
            ...staffRows,
          ]),
          'nohut-personel',
        );
      } else if (tab == 'Platform Mutabakatı') {
        export(
          csv([
            [
              'Sipariş',
              'Kaynak',
              'Tür',
              'Kuruş',
              'Ödeme emri',
              'Durum',
              'Tarih UTC',
            ],
            ...finance,
          ]),
          'nohut-mutabakat',
        );
      } else {
        export(ledgerCsv(baseReceipts), 'nohut-ozet-tahsilat');
      }
    }

    Widget content;
    if (tab == 'Özet') {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ranking(
              'Ürünler · Satış Adedi',
              productTotals,
              onSelect: (name) => setState(() {
                tab = 'Ürünler';
                search = name;
              }),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ranking(
              'Personel · Ürün Tutarı',
              staffTotals,
              money: true,
              onSelect: (name) => setState(() {
                tab = 'Ürünler';
                staff = name;
                search = '';
              }),
            ),
          ),
        ],
      );
    } else if (tab == 'Tahsilatlar') {
      content = WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                dropdown('Yöntem', method, [
                  'Tümü',
                  'Nakit',
                  'Kart',
                  'Platform',
                ], (v) => method = v),
                dropdown('İşlem', kind, [
                  'Tümü',
                  'Tahsilat',
                  'İade',
                  'Platform düzeltmesi',
                ], (v) => kind = v),
                Text(
                  '${receipts.length} hareket · Net ${formatTry(receipts.fold<int>(0, (n, r) => n + r.amount))}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WorkTable(
                headings: const [
                  'Sipariş / Kaynak',
                  'Yöntem / İşlem',
                  'İşlemi Yapan',
                  'Tarih · İstanbul',
                  'Tutar',
                ],
                rows: [
                  for (final r in receipts)
                    [
                      '#${r.orderId} · ${r.source}',
                      '${r.method} · ${r.kind}',
                      r.staff,
                      istanbulTime(r.stamp),
                      formatTry(r.amount),
                    ],
                ],
                onRow: (i) => widget.onOrder(receipts[i].orderId),
              ),
            ),
          ],
        ),
      );
    } else if (tab == 'Ürünler') {
      content = WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ürün fiyatları · Platform indirimi / komisyonu içermez. Tahsilat toplamı değildir.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WorkTable(
                headings: const [
                  'Sipariş / Kaynak',
                  'Ürün',
                  'Adet',
                  'Personel',
                  'Ürün Tutarı',
                ],
                rows: [
                  for (final r in products)
                    [
                      '#${r.orderId} · ${r.source}',
                      r.product,
                      '${r.quantity}',
                      r.staff,
                      formatTry(r.amount),
                    ],
                ],
                onRow: (i) => widget.onOrder(products[i].orderId),
              ),
            ),
          ],
        ),
      );
    } else if (tab == 'Personel') {
      content = WorkCard(
        child: WorkTable(
          headings: const ['Personel', 'Sipariş', 'Ürün Adedi', 'Ürün Tutarı'],
          rows: staffRows,
          onRow: (i) => setState(() {
            staff = staffRows[i][0];
            tab = 'Ürünler';
            search = '';
          }),
        ),
      );
    } else {
      content = WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'DEMO · Örnek %15 komisyon. Banka veya platform finans hesabına bağlı değildir.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                dropdown(
                  'Finans Hareketi',
                  financeType,
                  [
                    'Tümü',
                    'Sale',
                    'Return',
                    'Commission',
                    'SellerDiscount',
                    'PaymentOrder',
                  ],
                  (v) => financeType = v,
                  width: 190,
                ),
                for (final o in asMaps(state['orders']).where(
                  (o) =>
                      o['source'] == 'Trendyol Go' &&
                      o['demoRemoteStatus'] == 'Delivered' &&
                      o['cancelled'] != true &&
                      !asMaps(
                        hub['settlements'],
                      ).any((r) => r['orderId'] == o['id']),
                ))
                  OutlinedButton(
                    onPressed: () =>
                        widget.edit((s) => sampleSettlement(s, o['id'] as int)),
                    child: Text('#${o['id']} Örnek Finans Kaydı Al'),
                  ),
                if (settlements.isNotEmpty)
                  PopupMenuButton<Object>(
                    tooltip: 'Örnek Ödeme Emri Eşleştir',
                    onSelected: (id) => widget.edit(
                      (s) => findRecord(s, 'settlements', id)['paymentStatus'] =
                          'Eşleşti (demo)',
                    ),
                    itemBuilder: (_) => [
                      for (final r in settlements)
                        PopupMenuItem(
                          value: r['id'] as Object,
                          child: Text('${r['paymentOrderId']} · Demo Eşleştir'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WorkTable(
                headings: const [
                  'Sipariş',
                  'Kaynak',
                  'Tür',
                  'Tutar',
                  'Ödeme Emri / Durum',
                ],
                rows: [
                  for (final r in finance)
                    [
                      '#${r[0]}',
                      '${r[1]}',
                      '${r[2]}',
                      formatTry(r[3] as int),
                      '${r[4]} · ${r[5]}',
                    ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading(
          'Raporlar',
          'Tahsilat, ürün ve personel verileri · Tarihler İstanbul saatinde.',
          action: FilledButton.icon(
            key: const ValueKey('report-export'),
            onPressed: exportCurrent,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(tab == 'Özet' ? 'Tahsilat Özeti CSV' : 'CSV İndir'),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            dropdown('Kaynak', source, [
              'Tümü',
              'Masa',
              'Gel-Al',
              ...platformSources,
            ], (v) => source = v),
            dropdown(
              'Personel',
              staff,
              people.contains(staff) ? people : [...people, staff],
              (v) => staff = v,
            ),
            for (final v in ['Tüm Tarihler', 'Bugün', '7 Gün', '30 Gün'])
              ChoiceChip(
                label: Text(v),
                selected: period == v,
                onSelected: (_) => selectPeriod(v),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2099, 12, 31),
                  initialDateRange: dates,
                  helpText: 'Rapor Tarih Aralığı · İstanbul',
                );
                if (value != null && mounted) {
                  setState(() {
                    dates = value;
                    period = 'Özel';
                  });
                }
              },
              icon: const Icon(Icons.date_range, size: 17),
              label: Text(
                dates == null
                    ? 'Tarih Seç'
                    : '${istanbulTime(dates!.start.toUtc(), dateOnly: true)} – ${istanbulTime(dates!.end.toUtc(), dateOnly: true)}',
              ),
            ),
            IconButton(
              tooltip: 'Filtreleri Sıfırla',
              onPressed: () => setState(() {
                source = method = kind = staff = financeType = 'Tümü';
                dates = null;
                period = 'Tüm Tarihler';
                search = '';
              }),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: Row(
            children: [
              for (final type in ['Tümü', 'Nakit', 'Kart', 'Platform']) ...[
                Expanded(
                  child: WorkMetric(
                    label: type == 'Tümü' ? 'Net Tahsilat' : '$type · Net',
                    value: formatTry(net(type)),
                    icon: type == 'Tümü'
                        ? Icons.insights
                        : type == 'Nakit'
                        ? Icons.payments_outlined
                        : type == 'Kart'
                        ? Icons.credit_card
                        : Icons.delivery_dining,
                    selected: tab == 'Tahsilatlar' && method == type,
                    onTap: () => setState(() {
                      tab = 'Tahsilatlar';
                      method = type;
                      kind = 'Tümü';
                      search = '';
                    }),
                  ),
                ),
                if (type != 'Platform') const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: WorkTabs(
                values: const [
                  'Özet',
                  'Tahsilatlar',
                  'Ürünler',
                  'Personel',
                  'Platform Mutabakatı',
                ],
                selected: tab,
                onChanged: (v) => setState(() {
                  tab = v;
                  if (v == 'Platform Mutabakatı') staff = 'Tümü';
                  search = '';
                }),
              ),
            ),
            if (tab != 'Özet' && tab != 'Platform Mutabakatı')
              SizedBox(
                width: 220,
                child: TextField(
                  key: ValueKey('report-search-$tab'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Kayıtlarda ara',
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: content),
      ],
    );
  }
}
