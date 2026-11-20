import 'dart:io';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations_ui.dart';
import 'qr_menu_sync.dart';
import 'qr_menu_preview.dart';
import 'trendyol_go_readonly.dart';
import 'trendyol_go_ui.dart';
import 'receipt_printer.dart';
import 'receipt_layout.dart';
import 'receipt_preview.dart';

class SimpleSettings extends StatefulWidget {
  const SimpleSettings({
    super.key,
    required this.state,
    required this.edit,
    required this.store,
    required this.qrSync,
    required this.tgoIntegration,
    this.staffPanel,
    this.wifiPanel,
  });
  final Json state;
  final EditState edit;
  final PosStore store;
  final QrMenuAutoSync qrSync;
  final TrendyolGoReadonly tgoIntegration;
  final Widget? staffPanel, wifiPanel;
  @override
  State<SimpleSettings> createState() => _SimpleSettingsState();
}

class _SimpleSettingsState extends State<SimpleSettings> {
  String tab = 'Genel', search = '';
  Widget printerLayout(Map settings, Widget controls) {
    final preview = section(
      'Fiş Önizleme',
      'Örnek hesap · ${settings['paperWidthMm'] ?? 56} mm',
      [
        ReceiptPreview(
          settings: settings,
          order: {
            'id': 1,
            'dailyNumber': 1,
            'source': 'Masa',
            'table': 3,
            'createdAt': '2026-11-18T09:00:00Z',
            'batches': [
              {
                'id': 1,
                'lines': [
                  {'name': 'Falafel Dürüm', 'qty': 1, 'price': 140},
                  {'name': 'Ek Lavaş', 'qty': 1, 'price': 10},
                ],
              },
            ],
            'payments': [
              {'method': 'Nakit', 'amount': 150},
            ],
          },
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 790) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [controls, const SizedBox(height: 12), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: controls),
            const SizedBox(width: 16),
            SizedBox(width: 270, child: preview),
          ],
        );
      },
    );
  }

  Widget section(String title, String description, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: NohutBrand.headingFont,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 20),
              ...children,
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final settings = widget.state['settings'] as Map? ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Ayarlar'),
        const Text('İşletmen için gereken ayarlar, tek yerde.'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final name in [
              'Genel',
              'Menü',
              'Yazıcı',
              'Trendyol Go',
              if (widget.staffPanel != null) 'Personel',
              if (widget.wifiPanel != null) 'Bağlantı',
              'inPOS',
              'Yedek',
            ])
              ChoiceChip(
                label: Text(name),
                selected: tab == name,
                onSelected: (_) => setState(() => tab = name),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (tab == 'Personel' && widget.staffPanel != null) widget.staffPanel!,
        if (tab == 'Bağlantı' && widget.wifiPanel != null) widget.wifiPanel!,
        if (tab == 'Genel')
          section(
            'Bildirimler',
            'Personelden gelen siparişler yönetici ekranında görünür.',
            [
              SwitchListTile(
                title: const Text('Yeni sipariş sesi'),
                value: settings['soundAlerts'] != false,
                onChanged: (v) => widget.edit((s) {
                  (s.putIfAbsent('settings', () => <String, dynamic>{})
                          as Map)['soundAlerts'] =
                      v;
                }),
              ),
              const ListTile(
                leading: Icon(Icons.table_restaurant),
                title: Text('5 masa · Ortak hesaplar'),
                subtitle: Text('Telefon ve laptop aynı siparişleri kullanır.'),
              ),
            ],
          ),
        if (tab == 'Trendyol Go')
          TgoSettingsPanel(integration: widget.tgoIntegration),
        if (tab == 'Menü')
          section(
            'Menü ve fiyatlar',
            'Eşitleme eski siparişlerin fiyatlarını değiştirmez.',
            [
              QrMenuSyncPanel(
                sync: widget.qrSync,
                enabled: settings['qrAutoSync'] != false,
                onToggle: (v) {
                  if (widget.edit((s) {
                        (s.putIfAbsent('settings', () => <String, dynamic>{})
                                as Map)['qrAutoSync'] =
                            v;
                      }) &&
                      v)
                    widget.qrSync.syncNow();
                },
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ürün ara',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              for (final p in asMaps(widget.state['localMenu']).where(
                (p) =>
                    '${p['name']}'.toLowerCase().contains(search.toLowerCase()),
              ))
                ListTile(
                  title: Text('${p['name']}'),
                  subtitle: Text(
                    p['price'] == null
                        ? 'Satış dışı'
                        : formatTry(cents(p['price'])),
                  ),
                  trailing: IconButton(
                    tooltip: 'Fiyat Düzenle',
                    onPressed: settings['qrAutoSync'] != false
                        ? null
                        : () async {
                            final v = await askFields(
                              context,
                              'Yerel Ürün Fiyatı',
                              [
                                (
                                  'Fiyat ₺ (boş = satış dışı)',
                                  '${p['price'] ?? ''}',
                                ),
                              ],
                            );
                            if (v != null)
                              widget.edit((s) {
                                final row = (s['localMenu'] as List)
                                    .cast<Map>()
                                    .firstWhere((x) => x['id'] == p['id']);
                                row['price'] = v[0].isEmpty
                                    ? null
                                    : fromCents(parseMoney(v[0]));
                              });
                          },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
            ],
          ),
        if (tab == 'Yazıcı')
          printerLayout(
            settings,
            section(
              'Ödemede sor, istenirse yazdır',
              'Sipariş ve ek ürünlerde otomatik çıktı alınmaz. Ödeme kaydında fiş isteği sorulur.',
              [
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text('${settings['printerName'] ?? 'XP-237B'}'),
                  subtitle: Text(
                    '${settings['paperWidthMm'] ?? 56} mm kağıt · ${settings['printableWidthMm'] ?? 48} mm baskı · Aynı fiş tasarımı',
                  ),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'receipt-transport-${settings['receiptTransport'] ?? 'windows'}',
                  ),
                  initialValue: '${settings['receiptTransport'] ?? 'windows'}',
                  decoration: const InputDecoration(
                    labelText: 'Yazdırma yöntemi',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'windows',
                      child: Text('Windows · Fiş görseli'),
                    ),
                    DropdownMenuItem(
                      value: 'escpos',
                      child: Text('ESC/POS · Fiş modu'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null)
                      widget.edit((s) {
                        final cfg = s['settings'] as Map;
                        cfg['receiptTransport'] = v;
                        if (v == 'escpos') cfg['receiptOffsetMm'] = 0;
                      });
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'XP-237B: Önce yazıcının fiş modunda olduğunu doğrulayın. ESC/POS, sayfa uzunluğu sınırını kullanmaz. Etiket modunda seçmeyin.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Yazıcı Ayarı'),
                  onPressed: () async {
                    final v = await askFields(
                      context,
                      'Yazıcı Ayarı',
                      [
                        (
                          'Windows yazıcı adı',
                          '${settings['printerName'] ?? 'XP-237B'}',
                        ),
                        (
                          'Kağıt genişliği (mm)',
                          '${settings['paperWidthMm'] ?? 56}',
                        ),
                        (
                          'Baskı genişliği (mm)',
                          '${settings['printableWidthMm'] ?? 48}',
                        ),
                        (
                          'Üst / alt güvenli boşluk (mm)',
                          '${settings['receiptMarginMm'] ?? 4}',
                        ),
                        (
                          'Yatay kaydırma (mm, + sağa)',
                          '${settings['receiptOffsetMm'] ?? 0}',
                        ),
                        (
                          'Logo boyutu (mm)',
                          '${settings['receiptLogoMm'] ?? 18}',
                        ),
                      ],
                      validate: (v) {
                        final values = v
                            .skip(1)
                            .map((x) => double.tryParse(x.replaceAll(',', '.')))
                            .toList();
                        if (v[0].isEmpty ||
                            values.any((x) => x == null || !x.isFinite))
                          return 'Yazıcı adı ve sayısal ölçüler gerekli';
                        final p = values.cast<double>();
                        try {
                          ReceiptDimensions({
                            'paperWidthMm': p[0],
                            'printableWidthMm': p[1],
                            'receiptMarginMm': p[2],
                            'receiptOffsetMm': p[3],
                            'receiptLogoMm': p[4],
                          });
                        } on FormatException catch (e) {
                          return e.message;
                        }
                        if (settings['receiptTransport'] == 'escpos' &&
                            p[3] != 0)
                          return 'ESC/POS için yatay kaydırma 0 olmalı';

                        if (p[0] < 40 ||
                            p[0] > 80 ||
                            p[1] < 30 ||
                            p[1] > 48 ||
                            p[1] > p[0] ||
                            p[2] < 2 ||
                            p[2] > 10 ||
                            p[3].abs() > 10 ||
                            p[4] < 10 ||
                            p[4] > 25)
                          return 'Ölçüler: kağıt 40–80, baskı 30–48, boşluk 2–10, kaydırma ±10, logo 10–25 mm';
                        return null;
                      },
                    );
                    if (v != null)
                      widget.edit((s) {
                        final cfg = s['settings'] as Map;
                        cfg['printerName'] = v[0];
                        for (var i = 0; i < 5; i++)
                          cfg[[
                            'paperWidthMm',
                            'printableWidthMm',
                            'receiptMarginMm',
                            'receiptOffsetMm',
                            'receiptLogoMm',
                          ][i]] = double.parse(
                            v[i + 1].replaceAll(',', '.'),
                          );
                        cfg['receiptScale'] = 'actual';
                      });
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Hizalama Testi Yazdır'),
                  onPressed: () async {
                    try {
                      await windowsPrint(
                        'HİZALAMA TESTİ\nSol |--------------------| Sağ\nOrtalanmış baskı alanı\nKağıt: ${settings['paperWidthMm'] ?? 56} mm\nBu bir sipariş değildir.',
                        '${settings['printerName'] ?? 'XP-237B'}',
                        settings: settings,
                      );
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Test yazıcı kuyruğuna gönderildi'),
                          ),
                        );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                ),
                for (final j in asMaps(widget.state['printJobs']).where(
                  (j) =>
                      j['kind'] == 'paymentReceipt' &&
                      j['state'] == 'Kontrol gerekli',
                ))
                  ListTile(
                    title: const Text('Fiş çıktısını kontrol edin'),
                    subtitle: Text('${j['error']}'),
                    trailing: TextButton(
                      child: const Text('Kontrol Ettim · Yeniden Dene'),
                      onPressed: () async {
                        if (await confirmAction(
                          context,
                          'Tekrar yazdır?',
                          'Aynı çıktı iki kez basılabilir. Önce yazıcıyı kontrol edin.',
                        ))
                          widget.edit((s) {
                            final job = (s['printJobs'] as List)
                                .cast<Map>()
                                .firstWhere(
                                  (x) =>
                                      x['receiptRequestId'] ==
                                      j['receiptRequestId'],
                                );
                            if (job['state'] != 'Kontrol gerekli')
                              throw const FormatException('Durum değişti');
                            job['state'] = 'Bekliyor';
                          });
                      },
                    ),
                  ),
              ],
            ),
          ),
        if (tab == 'inPOS')
          section('inPOS m530', 'Otomatik bağlantı henüz etkin değil.', [
            const ListTile(
              leading: Icon(Icons.credit_card_off_outlined),
              title: Text('GMP-3 · Resmî SDK ve aktivasyon bekleniyor'),
              subtitle: Text(
                'Uygulama numarası, yetkili servis eşleştirmesi ve üretici SDK’sı gerekir. Kart düğmesi şu anda yalnızca terminalde onayladığınız ödemeyi kaydeder.',
              ),
            ),
            const Text(
              'Bağlantı hazır olduğunda: Tutarı gönder → Kartı okut → Sonucu bekle → Onaylı ödemeyi kaydet. Belirsiz sonuç yeniden tahsil edilmez; referans ile sorgulanır.',
            ),
            for (final a in asMaps(widget.state['terminalAttempts']))
              ListTile(
                title: Text('${a['reference']} · ${a['status']}'),
                subtitle: Text(formatTry(a['amountCents'] as int)),
              ),
          ]),
        if (tab == 'Yedek')
          section(
            'Verilerini koru',
            'Sipariş geçmişi bu bilgisayarda saklanır.',
            [
              FilledButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('SQLite Yedeği Oluştur'),
                onPressed: () async {
                  final v = await askFields(context, 'SQLite Yedekle', [
                    (
                      'Yeni yedek dosya yolu',
                      '${Directory.current.path}/nohut-${DateTime.now().millisecondsSinceEpoch}.sqlite3',
                    ),
                  ]);
                  if (v != null) {
                    try {
                      widget.store.backup(v[0]);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yedek kaydedildi')),
                        );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
              ExpansionTile(
                title: const Text('Veritabanı konumu'),
                children: [SelectableText(widget.store.filePath)],
              ),
            ],
          ),
      ],
    );
  }
}
