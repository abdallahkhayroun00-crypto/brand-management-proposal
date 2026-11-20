import 'order_reporting.dart';
import 'receipt_preview.dart';

import 'dart:io';

import 'receipt_printer.dart';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'brand.dart';
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations.dart';
import 'platform_workflows.dart';
import 'qr_menu_preview.dart';
import 'qr_menu_sync.dart';

typedef EditState = bool Function(void Function(Json) change);

String optionLabel(String value) =>
    const {
      'ACTIVE': 'Satışta',
      'PASSIVE': 'Satış dışı',
      'direct': 'Restoranda onay',
      'indirect': 'Platform uygulamasında onay',
      'Created': 'Kabul bekliyor',
      'Picking': 'Hazırlanıyor',
      'Invoiced': 'Hazır',
      'Shipped': 'Kuryede',
      'Delivered': 'Teslim edildi',
      'Cancelled': 'İptal edildi',
      'UnSupplied': 'Tedarik edilemedi',
      'Collected': 'Platform tahsil etti',
      'Pending': 'Tahsilat bekliyor',
      'wrap': 'Dürümler',
      'plate': 'Porsiyonlar',
      'meze': 'Mezeler',
      'fatte': 'Fatte',
      'side': 'Diğer',
      'salad': 'Salatalar',
      'dessert': 'Tatlılar',
      'drink': 'İçecekler',
      'NONE': 'Yanıt yok',
      'WAITING_FOR_APPROVE': 'Onay bekliyor',
      'APPROVED': 'Onaylandı',
      'REJECTED': 'Reddedildi',
    }[value] ??
    value;

Future<List<String>?> askFields(
  BuildContext context,
  String title,
  List<(String, String)> fields, {
  Map<int, List<String>> choices = const {},
  String? Function(List<String>)? validate,
}) async {
  final selectable = <int, List<String>>{
    for (var i = 0; i < fields.length; i++)
      if (fields[i].$1.contains('evet / hayır')) i: ['evet', 'hayır'],
    ...choices,
  };
  final controllers = fields
      .map((f) => TextEditingController(text: f.$2))
      .toList();
  for (final entry in selectable.entries) {
    if (!entry.value.contains(controllers[entry.key].text))
      controllers[entry.key].text = entry.value.first;
  }
  String? formError;
  final result = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
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
                    child: selectable.containsKey(i)
                        ? DropdownButtonFormField<String>(
                            initialValue: controllers[i].text,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: fields[i].$1,
                            ),
                            items: selectable[i]!
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(optionLabel(v)),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => controllers[i].text = v!,
                          )
                        : TextField(
                            controller: controllers[i],
                            decoration: InputDecoration(
                              labelText: fields[i].$1,
                            ),
                          ),
                  ),
                if (formError != null)
                  Text(
                    formError!,
                    style: const TextStyle(color: Color(0xff8c352e)),
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
            onPressed: () {
              final values = controllers.map((c) => c.text.trim()).toList();
              final error = validate?.call(values);
              if (error != null) {
                update(() => formError = error);
                return;
              }
              Navigator.pop(ctx, values);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );
  // Let the dialog finish its closing animation before disposing its inputs.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  for (final c in controllers) {
    c.dispose();
  }
  return result;
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String detail, {
  String confirm = 'Onayla',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(detail)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm),
          ),
        ],
      ),
    ) ??
    false;

int parseMoney(String text) {
  final input = text.trim();
  if (!RegExp(r'^\d+([.,]\d{1,2})?$').hasMatch(input)) {
    throw const FormatException('Tutar en fazla iki ondalık basamak olmalı');
  }
  final parts = input.replaceAll(',', '.').split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null || whole > 999999999)
    throw const FormatException('Tutar çok büyük');
  final fraction = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return whole * 100 + fraction;
}

int parseInteger(String text) =>
    int.tryParse(text) ?? (throw const FormatException('Tam sayı gerekli'));
Widget panelTitle(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 14),
  child: Text(
    text,
    style: const TextStyle(
      fontFamily: NohutBrand.headingFont,
      fontWeight: FontWeight.w400,
      fontSize: 22,
    ),
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
                  if (v == null || !context.mounted) return;
                  int counted;
                  try {
                    counted = parseMoney(v[0]);
                  } on FormatException catch (e) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                    return;
                  }
                  final expected = expectedCash(s, active);
                  final confirmed = await confirmAction(
                    context,
                    'Kasayı Kapatmadan Önce',
                    'Beklenen: ${formatTry(expected)}\nSayılan: ${formatTry(counted)}\nFark: ${formatTry(counted - expected)}',
                    confirm: 'Sayımı Onayla ve Kapat',
                  );
                  if (confirmed)
                    edit((next) {
                      final current = activeCash(next);
                      if (current == null ||
                          current['id'] != active['id'] ||
                          expectedCash(next, current) != expected) {
                        throw const FormatException(
                          'Kasa değişti. Güncel sayımı kontrol edin.',
                        );
                      }
                      closeCash(next, counted);
                    });
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
  const OrderOperations({
    super.key,
    required this.order,
    required this.edit,
    this.printerName = '',
    this.printSettings,
  });
  final Json order;
  final String printerName;
  final Map? printSettings;
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
                child: ReceiptPreview(order: o, settings: printSettings),
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
        if (orderPaidCents(o) > 0)
          OutlinedButton(
            onPressed: () async {
              try {
                final printer = printerName;
                await windowsPrint(
                  billText(o),
                  printer,
                  settings: printSettings,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Hesap Özeti Yazdır'),
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
                onPressed: () async {
                  if (await confirmAction(
                    context,
                    'Kişi Paylarını Sıfırla',
                    'Sipariş #${displayOrderNumber(o)} için ürün dağılımı silinecek. Devam edilsin mi?',
                  )) {
                    edit((s) => resetGuests(mutableOrder(s, id)!));
                  }
                },
                child: const Text('Kişi Paylarını Sıfırla'),
              ),
              if (o['source'] == 'Gel-Al' &&
                  o['deliveredAt'] == null &&
                  o['serviceStatus'] != 'Teslim Edildi')
                OutlinedButton(
                  onPressed: () =>
                      edit((s) => markPickupDelivered(mutableOrder(s, id)!)),
                  child: const Text('Teslim Edildi'),
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
                        if (asMaps(o['guestChecks']).isNotEmpty &&
                            line.total > allocatedTo(o, line.key))
                          PopupMenuButton<int>(
                            tooltip: 'Kalan ürün payını kişiye ata',
                            onSelected: (guestId) async {
                              final values = await askFields(
                                context,
                                'Ürün Payı',
                                [('Bu kişiye verilecek adet', '1')],
                              );
                              if (values == null) return;
                              final units = double.tryParse(
                                values[0].replaceAll(',', '.'),
                              );
                              if (units == null ||
                                  !units.isFinite ||
                                  units <= 0)
                                return;
                              edit((s) {
                                final current = mutableOrder(s, id)!;
                                final currentLine = checkLines(
                                  current,
                                ).firstWhere((l) => l.key == line.key);
                                final remaining =
                                    currentLine.total -
                                    allocatedTo(current, line.key);
                                if (remaining <= 0)
                                  throw const FormatException(
                                    'Ürün zaten dağıtılmış.',
                                  );
                                final guest = asMaps(
                                  current['guestChecks'],
                                ).firstWhere((g) => g['id'] == guestId);
                                final previous = asMaps(guest['allocations'])
                                    .where((a) => a['key'] == line.key)
                                    .fold<int>(
                                      0,
                                      (n, a) => n + (a['cents'] as int),
                                    );
                                allocateProduct(
                                  current,
                                  guestId,
                                  line.key,
                                  previous +
                                      (cents(currentLine.line['price']) * units)
                                          .round(),
                                );
                              });
                            },
                            itemBuilder: (context) => [
                              for (final g in asMaps(o['guestChecks']))
                                PopupMenuItem(
                                  value: g['id'] as int,
                                  child: Text(
                                    '${g['name']} · ${formatTry(line.total - allocatedTo(o, line.key))}',
                                  ),
                                ),
                            ],
                            child: const Chip(
                              label: Text('Ürünü Kişiye Ata ▾'),
                            ),
                          ),
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
                          if (v != null && context.mounted) {
                            int amount;
                            try {
                              amount = parseMoney(v[0]);
                            } on FormatException catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                              return;
                            }
                            if (amount <= 0 ||
                                amount > paymentNetCents(p) ||
                                v[1].trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Geçerli iade tutarı ve neden girin.',
                                  ),
                                ),
                              );
                              return;
                            }
                            final confirmed = await confirmAction(
                              context,
                              'İadeyi Gözden Geçir',
                              'Sipariş #${displayOrderNumber(o)}\nTutar: ${formatTry(amount)}\nYöntem: ${p['method']}\nNeden: ${v[1]}\n${p['method'] == 'Kart' ? 'İadeyi önce banka terminalinde tamamlayın. Bu kayıt bankaya işlem göndermez.' : 'Nakit iadesini doğrulayın.'}',
                              confirm: 'İade Yapıldı · Kaydet',
                            );
                            if (!confirmed) return;
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
        ('Görev', '${person?['role'] ?? 'Personel'}'),
      ],
      choices: {
        1: ['Personel', 'Yönetici'],
      },
      validate: (v) => v[0].isEmpty ? 'Personel adı gerekli' : null,
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
      info('Telefonda çalışan adı seçilir. Prototipte şifre yok.'),
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
      // Each new business day starts with empty daily reports. To inspect
      // past dates, change the filters or clear both dates for all history.
      from = istanbulDay(
        DateTime.now(),
      ),
      to = istanbulDay(DateTime.now()),
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
      // Excel on Windows needs a UTF-8 BOM for Turkish column names.
      File(v[0]).writeAsStringSync('\uFEFF$content');
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
      key: ValueKey('$label:$value'),
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

  Widget _hourlyChart(Json state) {
    final counts = hourlyOrderCounts(
      asMaps(state['orders']),
      from: from,
      to: to,
      source: source,
      staff: staff,
    );
    final maximum = counts.reduce((a, b) => a > b ? a : b);
    final total = counts.fold<int>(0, (a, b) => a + b);
    final peaks = [
      for (var h = 0; h < 24; h++)
        if (maximum > 0 && counts[h] == maximum)
          '${h.toString().padLeft(2, '0')}:00',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            panelTitle('Saatlik Sipariş Yoğunluğu'),
            Text(
              total == 0
                  ? 'Bu filtrelerde henüz sipariş yok.'
                  : 'En yoğun: ${peaks.join(', ')} · $maximum sipariş · Toplam $total',
            ),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var h = 0; h < 24; h++)
                    SizedBox(
                      width: 38,
                      child: Tooltip(
                        message: '$h:00 · ${counts[h]} sipariş',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${counts[h]}'),
                            const SizedBox(height: 5),
                            Container(
                              width: 25,
                              height: maximum == 0
                                  ? 2
                                  : 2 + 150 * counts[h] / maximum,
                              decoration: BoxDecoration(
                                color: counts[h] == maximum && maximum > 0
                                    ? Colors.orange
                                    : const Color(0xff25523e),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Text(h.toString().padLeft(2, '0')),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            info(
              'Europe/Istanbul · İlk sipariş saati · Ek ürün ve ödemeler yeniden sayılmaz. İptal ve kabul bekleyen kayıtlar hariç. Tarih, kaynak ve personel filtreleri uygulanır; ödeme yöntemi grafiği değiştirmez.',
            ),
            OutlinedButton(
              onPressed: () => export(
                '\uFEFFSaat (Europe/Istanbul),Sipariş sayısı\r\n${[for (var h = 0; h < 24; h++) '$h:00,${counts[h]}'].join('\r\n')}',
                'nohut-yogunluk',
              ),
              child: const Text('Yoğunluk CSV'),
            ),
          ],
        ),
      ),
    );
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final days in [1, 7, 30])
              OutlinedButton(
                onPressed: () => setState(() {
                  final now = DateTime.now().toUtc().add(
                    const Duration(hours: 3),
                  );
                  to = now.toIso8601String().substring(0, 10);
                  from = now
                      .subtract(Duration(days: days - 1))
                      .toIso8601String()
                      .substring(0, 10);
                }),
                child: Text(days == 1 ? 'Bugün' : 'Son $days Gün'),
              ),
            OutlinedButton(
              onPressed: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  helpText: 'Rapor tarih aralığı',
                );
                if (range != null && mounted)
                  setState(() {
                    from = range.start.toIso8601String().substring(0, 10);
                    to = range.end.toIso8601String().substring(0, 10);
                  });
              },
              child: const Text('Takvimden Seç'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _hourlyChart(s),
        panelTitle('Raporlar · Tahsilat ve İade'),
        info(
          'Varsayılan: bugün (00:00–23:59, Europe/Istanbul). Geçmiş kayıtları görmek için tarih filtrelerini değiştirin veya boş bırakın.',
        ),
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
                      .every((d) => d.isEmpty || validBusinessDate(d));
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
              '#${displayOrderNumber(mutableOrder(s, r.orderId) ?? {'id': r.orderId})} · ${r.source} · ${r.method} · ${r.kind}',
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
            title: Text(
              '#${displayOrderNumber(mutableOrder(s, r.orderId) ?? {'id': r.orderId})} · ${r.quantity} × ${r.product}',
            ),
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
      panelTitle('Xprinter XP-237B · 58 mm Fiş'),
      info(
        '48 mm baskı alanı · Büyük boyutlu sayfaları daralt: Varsayılan · Büyütme yapılmaz.',
      ),
      info(
        'Masa / Gel-Al ve ek siparişler PC kuyruğundan otomatik basılır. Ayarlar → Yazıcı Ayarı: Windows yazıcı adını kaydedin. Kuyruğa gönderildi, kağıt çıktısını doğrulamaz.',
      ),
      for (final j in asMaps(state['printJobs']).reversed)
        Card(
          child: ListTile(
            title: Text(
              '#${displayOrderNumber(mutableOrder(state, j['orderId'] as int) ?? {'id': j['orderId']})} · Parti ${j['batchId']} · ${j['state']}',
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/printing/nohut-receipt-logo.png',
                                  width: 70,
                                ),
                                SelectableText(text),
                              ],
                            ),
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
                if (canRequeueLocalKitchen(state, j))
                  OutlinedButton(
                    onPressed: () async {
                      if (!await confirmAction(
                        context,
                        'Yeniden Yazdırmayı Onayla',
                        'Sipariş #${displayOrderNumber(mutableOrder(state, j['orderId'] as int) ?? {'id': j['orderId']})} · Parti ${j['batchId']}\nDurum: ${j['state']}\nÖnce yazıcı çıktısını kontrol edin. Bu işlem aynı mutfak fişini tekrar basabilir.',
                        confirm: 'Kontrol Ettim · Yeniden Yazdır',
                      ))
                        return;
                      edit((s) {
                        final job = (s['printJobs'] as List)
                            .cast<Map>()
                            .firstWhere(
                              (r) =>
                                  r['orderId'] == j['orderId'] &&
                                  r['batchId'] == j['batchId'],
                            );
                        if (job['state'] != j['state'] ||
                            !canRequeueLocalKitchen(s, job)) {
                          throw const FormatException(
                            'Yazdırma durumu değişti. Kuyruğu ve çıktıyı tekrar kontrol edin.',
                          );
                        }
                        job['state'] = 'Bekliyor';
                        job['createdAt'] = DateTime.now()
                            .toUtc()
                            .toIso8601String();
                        job['error'] = '';
                      });
                    },
                    child: const Text('Kontrol Ettim · Yeniden Kuyruğa Al'),
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.state,
    required this.edit,
    required this.store,
    required this.qrSync,
  });
  final Json state;
  final EditState edit;
  final PosStore store;
  final QrMenuAutoSync qrSync;
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  String menuSearch = '';
  Json get state => widget.state;
  EditState get edit => widget.edit;
  PosStore get store => widget.store;
  QrMenuAutoSync get qrSync => widget.qrSync;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Ayarlar'),
      SelectableText('SQLite: ${store.filePath}'),
      QrMenuSyncPanel(
        sync: qrSync,
        enabled: state['settings']?['qrAutoSync'] != false,
        onToggle: (enabled) {
          final saved = edit((s) {
            final settings =
                s.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
            settings['qrAutoSync'] = enabled;
          });
          if (saved && enabled) qrSync.syncNow();
        },
      ),
      ExpansionTile(
        title: const Text('Yerel Menü Fiyatları'),
        children: [
          if (state['settings']?['qrAutoSync'] != false)
            info(
              'Fiyat kaynağı resmî QR menüdür. Yerel fiyat düzenlemek için otomatik eşitlemeyi kapatın.',
            ),
          TextField(
            decoration: const InputDecoration(labelText: 'Ürün adına göre ara'),
            onChanged: (v) => setState(() => menuSearch = v),
          ),
          for (final p in asMaps(state['localMenu']).where(
            (p) =>
                '${p['name']}'.toLowerCase().contains(menuSearch.toLowerCase()),
          ))
            ListTile(
              title: Text('${p['name']}'),
              subtitle: Text(
                p['price'] == null
                    ? 'Fiyat belirlenmedi'
                    : formatTry(cents(p['price'])),
              ),
              trailing: OutlinedButton(
                onPressed: state['settings']?['qrAutoSync'] != false
                    ? null
                    : () async {
                        final v =
                            await askFields(context, 'Yerel Ürün Fiyatı', [
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
        'Yemeksepeti / Trendyol Go: DEMO. Banka POS / ÖKC bağlı değil. Termal yazıcı Windows sürücüsüyle çalışır. Gerçek API anahtarı girmeyin.',
      ),
      info(
        'Platform denemeleri Online Siparişler bölümündeki ayrı test alanında yapılır.',
      ),
      SwitchListTile(
        title: const Text('Otomatik Masa / Gel-Al Fişi'),
        subtitle: const Text(
          'Yazıcı adını bir kez kaydedin; eski işler kendiliğinden basılmaz.',
        ),
        value: state['settings']?['autoPrint'] == true,
        onChanged: (enabled) => edit((s) {
          final cfg =
              s.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
          final wasEnabled = cfg['autoPrint'] == true;
          cfg['autoPrint'] = enabled;
          if (enabled && !wasEnabled)
            cfg['autoPrintEnabledAt'] = DateTime.now()
                .toUtc()
                .toIso8601String();
          cfg.putIfAbsent(
            'autoPrintEnabledAt',
            () => DateTime.now().toUtc().toIso8601String(),
          );
        }),
      ),
      OutlinedButton(
        onPressed: () async {
          final v = await askFields(context, 'Tek Yazıcı Ayarı', [
            (
              'Windows termal yazıcısının tam adı',
              '${state['settings']?['printerName'] ?? ''}',
            ),
          ], validate: (v) => v[0].isEmpty ? 'Yazıcı adı gerekli' : null);
          if (v != null) {
            edit((s) {
              final settings =
                  (s.putIfAbsent('settings', () => <String, dynamic>{}) as Map);
              settings['printerName'] = v[0];
              settings['printerCount'] = 1;
              settings['printerMode'] = 'windows';
              if (settings['autoPrint'] != true)
                settings['autoPrintEnabledAt'] = DateTime.now()
                    .toUtc()
                    .toIso8601String();
              settings['autoPrint'] = true;
              settings.putIfAbsent(
                'autoPrintEnabledAt',
                () => DateTime.now().toUtc().toIso8601String(),
              );
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
