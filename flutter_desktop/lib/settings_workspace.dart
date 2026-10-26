import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations_ui.dart';
import 'platform_runtime.dart';
import 'platform_settings_ui.dart';
import 'workspace_ui.dart';
import 'package:printing/printing.dart';

class SettingsWorkspace extends StatefulWidget {
  const SettingsWorkspace({
    super.key,
    required this.state,
    required this.edit,
    required this.store,
    required this.runtime,
    required this.onStaff,
    required this.onPrinter,
  });
  final Json state;
  final EditState edit;
  final PosStore store;
  final PlatformRuntime runtime;
  final VoidCallback onStaff, onPrinter;
  @override
  State<SettingsWorkspace> createState() => _SettingsWorkspaceState();
}

class _SettingsWorkspaceState extends State<SettingsWorkspace> {
  String section = 'Genel', search = '', category = 'Tümü';
  int? selected;
  final price = TextEditingController(), printer = TextEditingController();
  bool printerLoaded = false;
  bool scanningPrinters = false;
  Future<void> choosePrinter() async {
    setState(() => scanningPrinters = true);
    try {
      final info = await Printing.info();
      if (!info.canListPrinters || !info.directPrint) {
        throw const FormatException(
          'Windows yazıcı listesi / doğrudan yazdırma desteklenmiyor.',
        );
      }
      final printers = await Printing.listPrinters();
      if (!mounted) return;
      final chosen = await showDialog<Printer>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tek Windows / USB Yazıcısı Seç'),
          content: SizedBox(
            width: 500,
            height: 330,
            child: printers.isEmpty
                ? const WorkEmpty(
                    title: 'Windows yazıcısı bulunamadı',
                    message:
                        'USB yazıcısını bağlayıp Windows sürücüsünü kurun.',
                  )
                : ListView(
                    children: [
                      for (final p in printers)
                        ListTile(
                          leading: const Icon(Icons.print_outlined),
                          title: Text(p.name),
                          subtitle: Text(
                            p.isAvailable
                                ? 'Windows sürücüsü · Cihaz türünü kontrol edin'
                                : 'Windows: kullanılamıyor',
                          ),
                          onTap: p.isAvailable
                              ? () => Navigator.pop(ctx, p)
                              : null,
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      );
      if (chosen != null &&
          mounted &&
          widget.edit((s) {
            final settings =
                s.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
            settings['printerName'] = chosen.name;
            settings['printerUrl'] = chosen.url;
            settings['printerCount'] = 1;
            settings['printerMode'] = 'windows';
            settings['paperWidthMm'] = 80;
          })) {
        printer.text = chosen.name;
        message(
          'Windows yazıcısı seçildi. Fiziksel 80 mm çıktı testi henüz yapılmadı.',
        );
      }
    } catch (e) {
      if (mounted) message('Yazıcı listelenemedi: $e');
    } finally {
      if (mounted) setState(() => scanningPrinters = false);
    }
  }

  String? result;
  static const sections = <String, IconData>{
    'Genel': Icons.tune,
    'Menü & Fiyatlar': Icons.restaurant_menu,
    'Platform API': Icons.hub_outlined,
    'Yazıcı': Icons.print_outlined,
    'Veri & Yedek': Icons.backup_outlined,
  };
  @override
  void dispose() {
    price.dispose();
    printer.dispose();
    super.dispose();
  }

  void message(String value) => setState(() => result = value);
  Widget statusRow(
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xffedf3e8),
      child: Icon(icon, color: pine, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(value, style: const TextStyle(fontSize: 12)),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
  Widget general() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      workHeading(
        'İşletme ve Bağlantılar',
        'Nohut Falafel · Yönetici / Kasa (PC)',
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final item in [
            ('5 Masa', Icons.table_restaurant_outlined),
            ('Tek Yazıcı', Icons.print_outlined),
            ('Gel-Al', Icons.takeout_dining_outlined),
          ])
            SizedBox(
              width: 165,
              height: 92,
              child: WorkMetric(
                label: 'İşletme Düzeni',
                value: item.$1,
                icon: item.$2,
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusRow(
              'Personel telefonları',
              'Aynı bilgisayarın Wi-Fi sunucusu · Kişisel QR ve cihaz oturumu',
              Icons.qr_code_2,
              onTap: widget.onStaff,
            ),
            statusRow(
              'Platform API',
              'Trendyol Go / Yemeksepeti · Resmi hesap ve API bilgileri gerekli',
              Icons.hub_outlined,
              onTap: () => setState(() => section = 'Platform API'),
            ),
            statusRow(
              'Banka POS / ÖKC',
              'Bağlı değil · Kart kayıtları banka cihazını çalıştırmaz',
              Icons.credit_card,
            ),
            statusRow(
              'Tek mutfak yazıcısı',
              widget.state['settings']?['printerMode'] == 'windows'
                  ? 'Windows sürücüsü seçili · Fiziksel test bekliyor'
                  : 'Simülasyon · Ayarlar’dan Windows / USB yazıcısı seçilebilir',
              Icons.print_outlined,
              onTap: () => setState(() => section = 'Yazıcı'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const WorkCard(
        child: Text(
          'Telefon siparişleri yalnızca Gel-Al. Platformların kurye ve tahsilatı kendilerine aittir. Personel kabul / ret, ödeme veya fiyat değişikliği yapamaz. Prototipte şifre yoktur.',
          style: TextStyle(fontSize: 12, color: muted, height: 1.6),
        ),
      ),
    ],
  );
  Widget menu() {
    final all = asMaps(widget.state['localMenu']);
    final categories = {
      'Tümü',
      ...all.map((p) => '${p['category'] ?? 'Diğer'}'),
    }.toList();
    String label(String c) => switch (c) {
      'wrap' => 'Dürümler',
      'plate' => 'Porsiyonlar',
      'drink' => 'İçecekler',
      _ => c,
    };
    final rows = all
        .where(
          (p) =>
              (category == 'Tümü' || p['category'] == category) &&
              '${p['name']}'.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    final product = all.where((p) => p['id'] == selected).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading(
          'Menü & Fiyatlar',
          '${all.length} ürün · Fiyat değişikliği yalnızca yeni siparişlere uygulanır.',
        ),
        TextField(
          key: const ValueKey('settings-menu-search'),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Ürün ara',
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in categories)
              ChoiceChip(
                label: Text(label(c)),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: WorkCard(
                  padding: 0,
                  child: rows.isEmpty
                      ? const WorkEmpty(title: 'Ürün bulunamadı')
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final p = rows[i];
                            return ListTile(
                              key: ValueKey('settings-product-${p['id']}'),
                              selected: selected == p['id'],
                              selectedTileColor: const Color(0xffedf3e8),
                              title: Text(
                                '${p['name']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                p['price'] == null
                                    ? 'Satış dışı · Fiyat eksik'
                                    : formatTry(cents(p['price'])),
                              ),
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 17,
                              ),
                              onTap: () => setState(() {
                                selected = p['id'] as int;
                                price.text = p['price'] == null
                                    ? ''
                                    : '${p['price']}';
                                result = null;
                              }),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 245,
                child: WorkCard(
                  child: product == null
                      ? const WorkEmpty(
                          title: 'Ürün seçin',
                          message:
                              'Fiyatını düzenlemek için listeden bir ürüne dokunun.',
                          icon: Icons.touch_app_outlined,
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${product['name']}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                label('${product['category']}'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                key: const ValueKey('settings-product-price'),
                                controller: price,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Yeni fiyat',
                                  suffixText: '₺',
                                  helperText: 'Boş bırak = satış dışı',
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                key: const ValueKey('settings-save-price'),
                                onPressed: () {
                                  try {
                                    final amount = price.text.trim().isEmpty
                                        ? null
                                        : fromCents(
                                            parseMoney(price.text.trim()),
                                          );
                                    final ok = widget.edit((s) {
                                      (s['localMenu'] as List)
                                              .cast<Map>()
                                              .firstWhere(
                                                (p) => p['id'] == selected,
                                              )['price'] =
                                          amount;
                                    });
                                    if (ok) message('Fiyat kaydedildi.');
                                  } catch (e) {
                                    message('$e');
                                  }
                                },
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Fiyatı Kaydet'),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Mevcut siparişlerin tutarı değiştirilmez. Platform menüsüne fiyat gönderilmez.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget printerSettings() {
    if (!printerLoaded) {
      printer.text = '${widget.state['settings']?['printerName'] ?? ''}';
      printerLoaded = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading('Tek Sipariş Yazıcısı', 'Cihaz bilgisi ve mutfak kuyruğu'),
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusRow(
                'Yazıcı 1',
                widget.state['settings']?['printerMode'] == 'windows'
                    ? 'Windows sürücüsü seçili · Fiziksel test bekliyor'
                    : 'Seçili değil · Simülasyon',
                Icons.print_outlined,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('settings-printer-name'),
                controller: printer,
                decoration: const InputDecoration(
                  labelText: 'Yazıcı adı',
                  helperText: 'Bu kayıt fiziksel cihaz bağlantısını açmaz.',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: scanningPrinters ? null : choosePrinter,
                    icon: const Icon(Icons.usb, size: 18),
                    label: Text(
                      scanningPrinters
                          ? 'Listeleniyor…'
                          : 'Windows USB Yazıcısı Seç',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      if (widget.edit((s) {
                        final settings =
                            s.putIfAbsent('settings', () => <String, dynamic>{})
                                as Map;
                        settings['printerName'] = printer.text.trim();
                        settings['printerCount'] = 1;
                        settings['printerMode'] ??= 'simulation';
                      })) {
                        message(
                          'Yazıcı adı kaydedildi. Cihaz seçimi değiştirilmedi.',
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Yazıcı Bilgisini Kaydet'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onPrinter,
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Kuyruk ve Fiş Önizleme'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (widget.edit((s) {
                        (s.putIfAbsent('settings', () => <String, dynamic>{})
                                as Map)['printerMode'] =
                            'simulation';
                      })) {
                        message(
                          'Simülasyon modu seçildi. Fiziksel yazdırma kapalı.',
                        );
                      }
                    },
                    child: const Text('Simülasyon Modu'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const WorkCard(
          child: Text(
            'İlk sipariş ve ek ürünler ayrı mutfak işleri oluşturur. Ek fişte yalnızca ek ürünler bulunur. Tek Windows yazıcısı kullanılır; tamamlanmış mutfak işi tekrar gönderilmez. Sürücüde 80 mm kâğıdı seçin. Kuyruk kabulü fiziksel çıktı doğrulaması değildir. Mali ÖKC / e-Fatura bağlantısı yoktur.',
            style: TextStyle(fontSize: 12, height: 1.6, color: muted),
          ),
        ),
      ],
    );
  }

  Widget backup() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      workHeading('Veri & Yedek', 'Bilgisayardaki ortak SQLite veritabanı'),
      WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusRow(
              'Veri saklama',
              'SQLite · WAL · Tutarlı yedekleme',
              Icons.storage_outlined,
            ),
            const SizedBox(height: 12),
            SelectableText(
              widget.store.filePath,
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
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
                if (v == null) return;
                try {
                  widget.store.backup(v[0]);
                  if (mounted) message('Yedek kaydedildi: ${v[0]}');
                } catch (e) {
                  if (mounted) message('$e');
                }
              },
              icon: const Icon(Icons.backup_outlined, size: 18),
              label: const Text('Tutarlı SQLite Yedeği Oluştur'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const WorkCard(
        child: Text(
          'Telefonlar tüm veritabanını değiştiremez; doğrulanan işlemleri aynı bilgisayara gönderir. API anahtarları Windows güvenli deposunda tutulur ve bu SQLite yedeğine dahil değildir. Yedeği ayrı bir yerde saklayın.',
          style: TextStyle(fontSize: 12, height: 1.6, color: muted),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      workHeading(
        'Ayarlar',
        'İşletme, menü, bağlantılar ve veriler tek merkezde.',
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 185,
              child: WorkCard(
                padding: 8,
                child: ListView(
                  children: [
                    for (final e in sections.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          key: ValueKey('settings-section-${e.key}'),
                          selected: section == e.key,
                          selectedTileColor: const Color(0xffedf3e8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          leading: Icon(e.value, size: 20, color: pine),
                          title: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () => setState(() {
                            section = e.key;
                            result = null;
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: section == 'Menü & Fiyatlar'
                        ? menu()
                        : SingleChildScrollView(
                            child: switch (section) {
                              'Platform API' => PlatformConnectionsPanel(
                                runtime: widget.runtime,
                              ),
                              'Yazıcı' => printerSettings(),
                              'Veri & Yedek' => backup(),
                              _ => general(),
                            },
                          ),
                  ),
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: WorkCard(
                        padding: 12,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: pine,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result!,
                                style: const TextStyle(fontSize: 12),
                              ),
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
      ),
    ],
  );
}
