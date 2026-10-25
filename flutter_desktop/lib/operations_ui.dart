import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations.dart';
import 'platform_workflows.dart';
import 'order_actions.dart';

typedef EditState = bool Function(void Function(Json) change);

Future<List<String>?> askFields(
  BuildContext context,
  String title,
  List<(String, String)> fields,
) async {
  final controllers = fields
      .map((f) => TextEditingController(text: f.$2))
      .toList();
  final result = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < fields.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: TextField(
                    controller: controllers[i],
                    decoration: InputDecoration(labelText: fields[i].$1),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            controllers.map((c) => c.text.trim()).toList(),
          ),
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
  // Let the dialog finish its closing animation before disposing its inputs.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  for (final c in controllers) {
    c.dispose();
  }
  return result;
}

int parseMoney(String text) {
  if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(text)) {
    throw const FormatException('Tutar en fazla iki ondalık basamak olmalı');
  }
  return cents(double.parse(text.replaceAll(',', '.')));
}

int parseInteger(String text) =>
    int.tryParse(text) ?? (throw const FormatException('Tam sayı gerekli'));
Widget panelTitle(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 14),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
  ),
);
Widget info(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: Text(text),
);

class CashPanel extends StatelessWidget {
  const CashPanel({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  Widget build(BuildContext context) {
    final s = copyJson(state), active = activeCash(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Günlük Kasa · Açılış / Kapanış'),
        info(
          'Nakit sayımı. Kart ve platform tahsilatı kasadaki nakit değildir.',
        ),
        if (active == null)
          FilledButton(
            onPressed: () async {
              final v = await askFields(context, 'Kasayı Aç', [
                ('Açılış bakiyesi ₺', '0'),
              ]);
              if (v != null) edit((s) => openCash(s, parseMoney(v[0])));
            },
            child: const Text('Kasayı Aç'),
          ),
        if (active != null) ...[
          Text(
            'Kasa #${active['id']} · Açılış ${formatTry(active['openingCents'] as int)} · Beklenen ${formatTry(expectedCash(s, active))}',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final direction in [1, -1])
                OutlinedButton(
                  onPressed: () async {
                    final v = await askFields(
                      context,
                      direction == 1 ? 'Kasa Giriş' : 'Kasa Çıkış',
                      [('Tutar ₺', ''), ('Açıklama', '')],
                    );
                    if (v != null) {
                      edit(
                        (s) => moveCash(s, direction * parseMoney(v[0]), v[1]),
                      );
                    }
                  },
                  child: Text(direction == 1 ? 'Kasa Giriş' : 'Kasa Çıkış'),
                ),
              FilledButton(
                onPressed: () async {
                  final v = await askFields(context, 'Kapanış Sayımı', [
                    ('Sayılan nakit ₺', ''),
                  ]);
                  if (v != null) edit((s) => closeCash(s, parseMoney(v[0])));
                },
                child: const Text('Kasayı Kapat'),
              ),
            ],
          ),
        ],
        for (final c in asMaps(cashBook(s)['sessions']).reversed)
          ListTile(
            title: Text(
              'Kasa #${c['id']} · ${c['closedAt'] == null ? 'Açık' : 'Kapalı'}',
            ),
            subtitle: Text(
              '${c['openedAt']} → ${c['closedAt'] ?? 'Devam ediyor'}',
            ),
            trailing: Text(
              c['closedAt'] == null
                  ? formatTry(expectedCash(s, c))
                  : 'Beklenen ${formatTry(c['expectedCents'] as int)} · Sayılan ${formatTry(c['countedCents'] as int)} · Fark ${formatTry(c['differenceCents'] as int)}',
            ),
          ),
        for (final m in asMaps(cashBook(s)['movements']).reversed)
          ListTile(
            title: Text('${m['note']} · Kasa #${m['sessionId']}'),
            subtitle: Text('${m['at']}'),
            trailing: Text(formatTry(m['cents'] as int)),
          ),
      ],
    );
  }
}

class OrderOperations extends StatelessWidget {
  const OrderOperations({super.key, required this.order, required this.edit});
  final Json order;
  final EditState edit;
  @override
  Widget build(BuildContext context) {
    final o = order, id = o['id'] as int;
    if (isPlatform(o)) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        OutlinedButton(
          onPressed: () => showDialog<void>(
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
          ),
          child: const Text('Hesap Özeti Önizle'),
        ),
        if (o['closed'] != true)
          for (final g in asMaps(o['guestChecks']))
            Wrap(
              spacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final v = await askFields(context, 'Kişi Adı', [
                      ('Ad', '${g['name']}'),
                    ]);
                    if (v != null) {
                      edit(
                        (s) => changeGuest(
                          mutableOrder(s, id)!,
                          g['id'] as int,
                          v[0],
                        ),
                      );
                    }
                  },
                  child: Text('${g['name']} Düzenle'),
                ),
                OutlinedButton(
                  onPressed: () => edit(
                    (s) => changeGuest(
                      mutableOrder(s, id)!,
                      g['id'] as int,
                      '',
                      remove: true,
                    ),
                  ),
                  child: const Text('Boş Kişiyi Kaldır'),
                ),
              ],
            ),
        panelTitle('Ürünler / Kişi Payları / İadeler'),
        if (o['closed'] != true && o['cancelled'] != true) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final v = await askFields(context, 'Kişi Ekle', [('Ad', '')]);
                  if (v != null) {
                    edit((s) => addGuest(mutableOrder(s, id)!, v[0]));
                  }
                },
                child: const Text('Kişi Ekle'),
              ),
              OutlinedButton(
                onPressed: () => edit((s) => resetGuests(mutableOrder(s, id)!)),
                child: const Text('Kişi Paylarını Sıfırla'),
              ),
              if (['Hazırlanıyor', 'Hazır'].contains(o['serviceStatus']))
                OutlinedButton(
                  onPressed: () => edit((s) {
                    if (o['serviceStatus'] == 'Hazır') {
                      setLocalService(mutableOrder(s, id)!, 'Teslim Edildi');
                    } else {
                      requestOrderAction(s, id, 'ready', pcActor);
                    }
                  }),
                  child: Text(
                    o['serviceStatus'] == 'Hazır' ? 'Teslim Edildi' : 'Hazır',
                  ),
                ),
              if (o['source'] == 'Gel-Al')
                OutlinedButton(
                  onPressed: () =>
                      edit((s) => closePickup(mutableOrder(s, id)!)),
                  child: const Text('Gel-Al Hesabını Kapat'),
                ),
              OutlinedButton(
                onPressed: () async {
                  final v = await askFields(context, 'Siparişi İptal Et', [
                    ('Neden', ''),
                  ]);
                  if (v != null) edit((s) => cancelLocalOrder(s, id, v[0]));
                },
                child: const Text('Siparişi İptal Et'),
              ),
            ],
          ),
          for (final line in checkLines(o))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${line.line['qty']} × ${line.line['name']} · ${formatTry(line.total)} · Dağıtılmamış ${formatTry(line.total - allocatedTo(o, line.key))}',
                    ),
                    Text(
                      'Çıkar: ${(line.line['removed'] as List? ?? []).join(', ')} · ${line.line['note'] ?? ''}',
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final v = await askFields(context, 'Ürün İptali', [
                              ('Adet', '1'),
                              ('Neden', ''),
                            ]);
                            if (v != null) {
                              edit(
                                (s) => cancelProduct(
                                  s,
                                  id,
                                  line.key,
                                  parseInteger(v[0]),
                                  v[1],
                                ),
                              );
                            }
                          },
                          child: const Text('Adet İptal'),
                        ),
                        for (final g in asMaps(o['guestChecks']))
                          OutlinedButton(
                            onPressed: () async {
                              final existing = asMaps(g['allocations'])
                                  .where((a) => a['key'] == line.key)
                                  .fold<int>(
                                    0,
                                    (n, a) => n + (a['cents'] as int),
                                  );
                              final v = await askFields(
                                context,
                                '${g['name']} · ${line.line['name']}',
                                [
                                  (
                                    'Bu ürünün kişi payı ₺ (0 = geri al)',
                                    (existing / 100).toStringAsFixed(2),
                                  ),
                                ],
                              );
                              if (v != null) {
                                edit(
                                  (s) => allocateProduct(
                                    mutableOrder(s, id)!,
                                    g['id'] as int,
                                    line.key,
                                    parseMoney(v[0]),
                                  ),
                                );
                              }
                            },
                            child: Text('${g['name']} Payı'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        for (var i = 0; i < asMaps(o['payments']).length; i++)
          if (asMaps(o['payments'])[i]['guestCheckId'] == null &&
              paymentNetCents(asMaps(o['payments'])[i]) > 0)
            Wrap(
              spacing: 6,
              children: [
                for (final g in asMaps(o['guestChecks']))
                  Builder(
                    builder: (context) {
                      final index = i, p = asMaps(o['payments'])[i];
                      final mapped = asMaps(p['guestAllocations'])
                          .where((a) => a['guestCheckId'] == g['id'])
                          .fold<int>(0, (n, a) => n + cents(a['amount']));
                      return OutlinedButton(
                        onPressed: () async {
                          final v = await askFields(
                            context,
                            'Geçmiş Tahsilatı Eşleştir',
                            [
                              (
                                '${g['name']} · Ödeme ${index + 1} · Pay ₺ (0 = geri al)',
                                (mapped / 100).toStringAsFixed(2),
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
                        child: Text(
                          'Ödeme ${index + 1} → ${g['name']} · ${formatTry(mapped)}',
                        ),
                      );
                    },
                  ),
              ],
            ),
        for (var i = 0; i < asMaps(o['payments']).length; i++)
          Builder(
            builder: (context) {
              final p = asMaps(o['payments'])[i], index = i;
              return ListTile(
                title: Text(
                  '${p['method']} · Net ${formatTry(paymentNetCents(p))}',
                ),
                subtitle: Text(
                  '${p['createdAt']} · ${p['guestName'] ?? p['by'] ?? ''}',
                ),
                trailing: paymentNetCents(p) <= 0
                    ? const Text('İade edildi')
                    : OutlinedButton(
                        onPressed: () async {
                          final v =
                              await askFields(context, 'Tahsilat İadesi', [
                                (
                                  'Tutar ₺',
                                  (paymentNetCents(p) / 100).toStringAsFixed(2),
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
              );
            },
          ),
        ExpansionTile(
          title: const Text('İşlem Geçmişi'),
          children: [
            for (final e in o['events'] as List? ?? [])
              ListTile(dense: true, title: Text('$e')),
          ],
        ),
      ],
    );
  }
}

class StaffPanel extends StatelessWidget {
  const StaffPanel({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  Future<void> change(BuildContext context, [Json? person]) async {
    final v = await askFields(
      context,
      person == null ? 'Personel Ekle' : 'Personel Düzenle',
      [
        ('Ad', '${person?['name'] ?? ''}'),
        ('Görev: Personel / Yönetici', '${person?['role'] ?? 'Personel'}'),
      ],
    );
    if (v != null) {
      edit(
        (s) => saveEmployee(
          s,
          person?['id'] as int?,
          v[0],
          v[1],
          person?['active'] == true || person == null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Personel Yönetimi'),
      info(
        'Kişisel QR ile cihaz etkinleştirilir. Kimlik oturumdan gelir; şifre yok.',
      ),
      FilledButton(
        onPressed: () => change(context),
        child: const Text('Personel Ekle'),
      ),
      for (final p in asMaps(state['employees']))
        ListTile(
          title: Text('${p['name']}'),
          subtitle: Text('${p['role']}'),
          onTap: () => change(context, p),
          trailing: Switch(
            value: p['active'] == true,
            onChanged: (v) => edit(
              (s) => saveEmployee(
                s,
                p['id'] as int,
                '${p['name']}',
                '${p['role']}',
                v,
              ),
            ),
          ),
        ),
    ],
  );
}

class ReportsPanel extends StatefulWidget {
  const ReportsPanel({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  State<ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<ReportsPanel> {
  String source = 'Tümü',
      method = 'Tümü',
      kind = 'Tümü',
      staff = '',
      from = '',
      to = '',
      financeType = 'Tümü';
  Future<void> export(String content, String name) async {
    final v = await askFields(context, 'CSV Kaydet', [
      ('Dosya yolu', path.join(Directory.current.path, '$name.csv')),
    ]);
    if (v == null) return;
    try {
      if (File(v[0]).existsSync()) {
        throw const FormatException('Dosya zaten var. Yeni bir ad seçin.');
      }
      File(v[0]).writeAsStringSync(content);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV kaydedildi: ${v[0]}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget filter(
    String label,
    String value,
    List<String> items,
    ValueChanged<String> set,
  ) => SizedBox(
    width: 175,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => setState(() => set(v!)),
    ),
  );
  bool inDate(String stamp) {
    if (from.isEmpty && to.isEmpty) return true;
    final parsed = DateTime.tryParse(stamp);
    if (parsed == null) return false;
    final date = parsed
        .toUtc()
        .add(const Duration(hours: 3))
        .toIso8601String()
        .substring(0, 10);
    return (from.isEmpty || date.compareTo(from) >= 0) &&
        (to.isEmpty || date.compareTo(to) <= 0);
  }

  @override
  Widget build(BuildContext context) {
    final s = copyJson(widget.state), hub = platformHub(s);
    final rows = ledger(s)
        .where(
          (r) =>
              (source == 'Tümü' || r.source == source) &&
              (method == 'Tümü' || r.method == method) &&
              (kind == 'Tümü' || r.kind == kind) &&
              r.staff.toLowerCase().contains(staff.toLowerCase()) &&
              inDate(r.stamp),
        )
        .toList();
    final saleRows = sales(s)
        .where(
          (r) =>
              (source == 'Tümü' || r.source == source) &&
              r.staff.toLowerCase().contains(staff.toLowerCase()) &&
              inDate(r.stamp),
        )
        .toList();
    final settlements = asMaps(hub['settlements'])
        .where(
          (r) =>
              (source == 'Tümü' || r['source'] == source) &&
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Raporlar · Tahsilat ve İade'),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            filter('Kaynak', source, [
              'Tümü',
              'Masa',
              'Gel-Al',
              ...platformSources,
            ], (v) => source = v),
            filter('Yöntem', method, [
              'Tümü',
              'Nakit',
              'Kart',
              'Platform',
            ], (v) => method = v),
            filter('Tür', kind, [
              'Tümü',
              'Tahsilat',
              'İade',
              'Platform düzeltmesi',
            ], (v) => kind = v),
            OutlinedButton(
              onPressed: () async {
                final v = await askFields(context, 'Rapor Filtreleri', [
                  ('Başlangıç YYYY-MM-DD (İstanbul)', from),
                  ('Bitiş YYYY-MM-DD', to),
                  ('Personel', staff),
                ]);
                if (v != null && context.mounted) {
                  final valid = v
                      .take(2)
                      .every(
                        (d) =>
                            d.isEmpty ||
                            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) &&
                                DateTime.tryParse(d) != null,
                      );
                  if (!valid ||
                      v[0].isNotEmpty &&
                          v[1].isNotEmpty &&
                          v[0].compareTo(v[1]) > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarih aralığı geçersiz')),
                    );
                    return;
                  }
                  setState(() {
                    from = v[0];
                    to = v[1];
                    staff = v[2];
                  });
                }
              },
              child: Text('$from → $to · Personel: $staff'),
            ),
            FilledButton(
              onPressed: () => export(ledgerCsv(rows), 'nohut-tahsilat'),
              child: const Text('Tahsilat CSV'),
            ),
          ],
        ),
        info(
          'Net filtreli tahsilat: ${formatTry(rows.fold<int>(0, (n, r) => n + r.amount))} · ${rows.length} hareket. Tarihler Europe/Istanbul.',
        ),
        for (final r in rows)
          ListTile(
            title: Text(
              '#${r.orderId} · ${r.source} · ${r.method} · ${r.kind}',
            ),
            subtitle: Text('${r.stamp} · ${r.staff}'),
            trailing: Text(formatTry(r.amount)),
          ),
        panelTitle('Ürün / Personel Satışları'),
        info(
          'Platform ürün fiyatları indirim öncesi olabilir; sipariş net toplamıyla aynı değildir.',
        ),
        OutlinedButton(
          onPressed: () => export(salesCsv(saleRows), 'nohut-urunler'),
          child: const Text('Ürün Satışları CSV'),
        ),
        for (final r in saleRows)
          ListTile(
            title: Text('#${r.orderId} · ${r.quantity} × ${r.product}'),
            subtitle: Text('${r.source} · ${r.staff} · ${r.stamp}'),
            trailing: Text(formatTry(r.amount)),
          ),
        panelTitle('Platform Hakediş ve Mutabakat · DEMO'),
        info(
          'Komisyon %15 yalnızca örnek. Dahil indirim tekrar düşülmez. Bankaya bağlı değildir.',
        ),
        filter('Finans hareketi', financeType, [
          'Tümü',
          'Sale',
          'Return',
          'Commission',
          'SellerDiscount',
          'PaymentOrder',
        ], (v) => financeType = v),
        for (final o in asMaps(s['orders']).where(
          (o) =>
              o['source'] == 'Trendyol Go' &&
              o['demoRemoteStatus'] == 'Delivered' &&
              o['cancelled'] != true &&
              !asMaps(hub['settlements']).any((r) => r['orderId'] == o['id']),
        ))
          OutlinedButton(
            onPressed: () =>
                widget.edit((s) => sampleSettlement(s, o['id'] as int)),
            child: Text('#${o['id']} Örnek Finans Kaydı Al'),
          ),
        OutlinedButton(
          onPressed: () => export(
            '\uFEFF${[
              ['Sipariş', 'Kaynak', 'Tür', 'Kuruş', 'Ödeme emri', 'Durum', 'Tarih UTC'],
              ...finance,
            ].map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n',
            'nohut-mutabakat',
          ),
          child: const Text('Mutabakat CSV'),
        ),
        for (final r in finance)
          ListTile(
            title: Text('#${r[0]} · ${r[2]} · ${formatTry(r[3] as int)}'),
            subtitle: Text('${r[4]} · ${r[5]} · ${r[6]}'),
          ),
        for (final r in settlements)
          OutlinedButton(
            onPressed: () => widget.edit((s) {
              final record = findRecord(s, 'settlements', r['id']);
              record['paymentStatus'] = 'Eşleşti (demo)';
            }),
            child: Text('${r['paymentOrderId']} Örnek Ödeme Emri Eşleştir'),
          ),
      ],
    );
  }
}

class PrinterPanel extends StatelessWidget {
  const PrinterPanel({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Tek Yazıcı · Mutfak İşleri'),
      info(
        'Fiziksel yazıcı bağlı değil. Önizleme ve demo sonuçları. Mali fiş değildir.',
      ),
      for (final j in asMaps(state['printJobs']).reversed)
        Card(
          child: ListTile(
            title: Text(
              '#${j['orderId']} · Parti ${j['batchId']} · ${j['state']}',
            ),
            subtitle: Text('${j['error'] ?? ''}'),
            trailing: Wrap(
              spacing: 5,
              children: [
                OutlinedButton(
                  onPressed: () {
                    try {
                      final text = receiptText(state, j);
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Mutfak Önizleme'),
                          content: SingleChildScrollView(
                            child: SelectableText(text),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('Önizle'),
                ),
                if (!['İşaretlendi', 'Simüle edildi'].contains(j['state'])) ...[
                  for (final success in [true, false])
                    OutlinedButton(
                      onPressed: () => edit((s) {
                        final job = (s['printJobs'] as List)
                            .cast<Map>()
                            .firstWhere(
                              (r) =>
                                  r['orderId'] == j['orderId'] &&
                                  r['batchId'] == j['batchId'],
                            );
                        job['state'] = success ? 'Simüle edildi' : 'Hata';
                        job['error'] = success
                            ? ''
                            : 'DEMO · Yazıcı erişilemiyor';
                        job['attempts'] = (job['attempts'] as int? ?? 0) + 1;
                      }),
                      child: Text(success ? 'Test: Tamamlandı' : 'Test: Hata'),
                    ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    super.key,
    required this.state,
    required this.edit,
    required this.store,
  });
  final Json state;
  final EditState edit;
  final PosStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Ayarlar'),
      SelectableText('SQLite: ${store.filePath}'),
      ExpansionTile(
        title: const Text('Yerel Menü Fiyatları'),
        children: [
          for (final p in asMaps(state['localMenu']))
            ListTile(
              title: Text('${p['name']}'),
              subtitle: Text(
                p['price'] == null
                    ? 'Fiyat belirlenmedi'
                    : formatTry(cents(p['price'])),
              ),
              trailing: OutlinedButton(
                onPressed: () async {
                  final v = await askFields(context, 'Yerel Ürün Fiyatı', [
                    (
                      'Fiyat ₺ (boş = satış dışı)',
                      p['price'] == null ? '' : '${p['price']}',
                    ),
                  ]);
                  if (v != null) {
                    edit((s) {
                      final row = (s['localMenu'] as List)
                          .cast<Map>()
                          .firstWhere((row) => row['id'] == p['id']);
                      row['price'] = v[0].isEmpty
                          ? null
                          : fromCents(parseMoney(v[0]));
                    });
                  }
                },
                child: const Text('Fiyat Düzenle'),
              ),
            ),
        ],
      ),
      info(
        '5 masa · Tek yazıcı · Telefon siparişleri Gel-Al · Kasa (PC) · Prototipte şifre yok.',
      ),
      info(
        'Banka POS / ÖKC / fiziksel yazıcı bağlı değil. Platform anahtarlarını yalnızca üstteki güvenli API alanına girin. DEMO siparişler gerçek API’ye gönderilmez.',
      ),
      for (final src in platformSources)
        ListTile(
          title: Text(src),
          subtitle: const Text('Ortam: DEMO · Canlı bağlantı yok'),
          trailing: OutlinedButton(
            onPressed: () =>
                edit((s) => queuePlatform(s, 'sync', src, src, {})),
            child: const Text('Örnek Bağlantı İsteği'),
          ),
        ),
      OutlinedButton(
        onPressed: () async {
          final v = await askFields(context, 'Tek Yazıcı Ayarı', [
            (
              'Yazıcı adı (henüz bağlanmaz)',
              '${state['settings']?['printerName'] ?? ''}',
            ),
          ]);
          if (v != null) {
            edit((s) {
              final settings =
                  (s.putIfAbsent('settings', () => <String, dynamic>{}) as Map);
              settings['printerName'] = v[0];
              settings['printerCount'] = 1;
              settings['printerMode'] = 'simulation';
            });
          }
        },
        child: const Text('Yazıcı Ayarı'),
      ),
      OutlinedButton(
        onPressed: () async {
          final v = await askFields(context, 'SQLite Yedekle', [
            (
              'Yeni yedek dosya yolu',
              path.join(
                Directory.current.path,
                'nohut-backup-${DateTime.now().millisecondsSinceEpoch}.sqlite3',
              ),
            ),
          ]);
          if (v != null) {
            try {
              store.backup(v[0]);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Yedek kaydedildi: ${v[0]}')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$e')));
              }
            }
          }
        },
        child: const Text('Tutarlı SQLite Yedeği Oluştur'),
      ),
    ],
  );
}
