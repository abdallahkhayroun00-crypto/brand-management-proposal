import 'package:flutter/material.dart';
import 'platform_api.dart';
import 'platform_runtime.dart';
import 'platform_workflows.dart';
import 'workspace_ui.dart';

class PlatformConnectionsPanel extends StatefulWidget {
  const PlatformConnectionsPanel({super.key, required this.runtime});
  final PlatformRuntime runtime;
  @override
  State<PlatformConnectionsPanel> createState() =>
      _PlatformConnectionsPanelState();
}

class _PlatformConnectionsPanelState extends State<PlatformConnectionsPanel> {
  int revision = 0;
  String selected = 'Trendyol Go';
  final testing = <String>{};
  Future<void> configure(String source) async {
    PlatformCredentials old;
    try {
      old = await widget.runtime.vault.load(source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Windows güvenli deposu açılamadı. Bilgiler düz metin olarak kaydedilmedi.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final isTgo = source == 'Trendyol Go';
    final fields = isTgo
        ? <String, String>{
            'supplierId': 'Supplier ID',
            'storeId': 'Restoran / Store ID',
            'apiKey': 'API Key / API Kodu',
            'apiSecret': 'API Secret',
            'executorEmail': 'İşlemi yapan hesap e-postası',
          }
        : <String, String>{
            'username': 'API Kullanıcı Adı',
            'password': 'API Şifresi',
            'chainCode': 'Chain Code',
            'remoteId': 'Restoran Remote ID',
            'platformKey': 'Platform Key (onboarding bilgisi)',
            'webhookSecret': 'Webhook Secret (gateway için)',
            'relayUrl': 'Onaylı HTTPS Webhook Gateway Adresi',
            'relayToken': 'Gateway Erişim Anahtarı',
          };
    const secrets = {
      'apiKey',
      'apiSecret',
      'password',
      'webhookSecret',
      'relayToken',
    };
    final controls = {
      for (final key in fields.keys)
        key: TextEditingController(
          text: secrets.contains(key) ? '' : old.field(key),
        ),
    };
    var mode = old.mode,
        confirmed = old.confirmed,
        direct = old.values['directApproved'] == true,
        prepared = old.values['preparedApproved'] == true;
    var saving = false, error = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(
            isTgo
                ? 'Uber Eats Trendyol Go · Yemek API'
                : 'Yemeksepeti · Restoran POS API',
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Anahtarlar Windows güvenli deposunda tutulur; telefonlara, CSV’ye veya GitHub’a gönderilmez. Boş bırakılan gizli alan mevcut anahtarı korur.',
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: mode,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'off',
                        child: Text('Kapalı · Bilgileri kaydet'),
                      ),
                      DropdownMenuItem(
                        value: 'stage',
                        child: Text('STAGE · Resmi test hesabı'),
                      ),
                      DropdownMenuItem(
                        value: 'live',
                        child: Text('CANLI · Onaylı restoran hesabı'),
                      ),
                    ],
                    onChanged: saving ? null : (v) => set(() => mode = v!),
                  ),
                  for (final entry in fields.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: TextField(
                        controller: controls[entry.key],
                        obscureText: secrets.contains(entry.key),
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: entry.value,
                          hintText:
                              secrets.contains(entry.key) &&
                                  old.field(entry.key).isNotEmpty
                              ? 'Kayıtlı anahtar korunacak'
                              : null,
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: saving ? null : (v) => set(() => confirmed = v!),
                    title: const Text(
                      'Platform bu restoran entegrasyon programını ve ortamını onayladı',
                    ),
                  ),
                  if (!isTgo) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: direct,
                      onChanged: saving ? null : (v) => set(() => direct = v!),
                      title: const Text(
                        'Direct Flow / PC kabulü için hesap onayı var',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: prepared,
                      onChanged: saving
                          ? null
                          : (v) => set(() => prepared = v!),
                      title: const Text(
                        'Hazır bildirimi için hesap onayı var (sipariş callback’i de gerekir)',
                      ),
                    ),
                    const Text(
                      'Restoran webhook’u onaylı HTTPS gateway’e gelir. Telefonlar yine yalnızca laptop LAN sunucusunu kullanır. Gateway kurulumu ve hesap onayı olmadan sipariş alma bağlı değildir.',
                    ),
                  ] else
                    const Text(
                      'Yemek sipariş sorgusu belgelendi. Kabul / hazır için güncel restoran servis sözleşmesi henüz doğrulanamadı; Market endpointleri kullanılmaz.',
                    ),
                  if (error.isNotEmpty)
                    Text(error, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      set(() => saving = true);
                      final values = <String, dynamic>{
                        ...old.values,
                        'mode': mode,
                        'programConfirmed': confirmed,
                        'directApproved': direct,
                        'preparedApproved': prepared,
                      };
                      for (final key in controls.keys) {
                        final value = controls[key]!.text.trim();
                        if (!secrets.contains(key) || value.isNotEmpty) {
                          values[key] = value;
                        }
                      }
                      try {
                        await widget.runtime.vault.save(
                          PlatformCredentials(source, values),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } on FormatException catch (e) {
                        if (ctx.mounted) {
                          set(() {
                            error = e.message;
                            saving = false;
                          });
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          set(() {
                            error =
                                'Güvenli kayıt başarısız. Anahtarlar düz metin olarak kaydedilmedi.';
                            saving = false;
                          });
                        }
                      }
                    },
              child: Text(saving ? 'Kaydediliyor…' : 'Güvenli Kaydet'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controls.values) {
      c.dispose();
    }
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.runtime,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading(
          'Platform API Bağlantıları',
          'Resmi hesap bilgileri Windows güvenli deposunda saklanır.',
        ),
        WorkTabs(
          values: platformSources,
          selected: selected,
          onChanged: (v) => setState(() => selected = v),
        ),
        const SizedBox(height: 16),
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xffedf3e8),
                    child: Icon(
                      Icons.delivery_dining,
                      color: selected == 'Trendyol Go'
                          ? Colors.deepOrange
                          : Colors.pink,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected == 'Trendyol Go'
                              ? 'Uber Eats Trendyol Go · Yemek'
                              : selected,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          testing.contains(selected)
                              ? 'Bağlantı test ediliyor…'
                              : widget.runtime.statuses[selected] ??
                                    'API bilgileri girilmedi · Bağlı değil',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              const Text(
                '1. Resmi hesap bilgilerini kaydet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Anahtarlar telefona, CSV dosyasına veya GitHub’a gönderilmez. Kapalı, resmi test ve canlı ortamlar ayrı tutulur.',
                style: TextStyle(fontSize: 12, height: 1.6, color: muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => configure(selected),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('API Kodunu / Bilgilerini Gir'),
                ),
              ),
              const Divider(height: 32),
              const Text(
                '2. Kimlik doğrulamasını test et',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bu test, sipariş kabulü veya hazır bildiriminin uçtan uca çalıştığını kanıtlamaz. DEMO siparişler canlı API’ye gönderilmez.',
                style: TextStyle(fontSize: 12, height: 1.6, color: muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: testing.contains(selected)
                        ? null
                        : () async {
                            final source = selected;
                            setState(() => testing.add(source));
                            await widget.runtime.testConnection(source);
                            if (mounted) setState(() => testing.remove(source));
                          },
                    icon: const Icon(Icons.network_check, size: 18),
                    label: Text(
                      testing.contains(selected)
                          ? 'Test Ediliyor…'
                          : 'Bağlantıyı Test Et',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final source = selected;
                      final remove = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Kayıtlı Anahtarları Kaldır'),
                          content: Text(
                            '$source için kayıtlı API bilgileri kaldırılacak.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Kaldır'),
                            ),
                          ],
                        ),
                      );
                      if (remove != true) return;
                      try {
                        await widget.runtime.vault.remove(source);
                        widget.runtime.statuses[source] =
                            'Anahtarlar kaldırıldı · Bağlı değil';
                      } catch (_) {
                        widget.runtime.statuses[source] =
                            'Güvenli depo açılamadı; silme onaylanmadı';
                      }
                      if (mounted) setState(() => revision++);
                    },
                    child: const Text('Kayıtlı Anahtarları Kaldır'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Entegrasyon Yetenekleri',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                selected == 'Trendyol Go'
                    ? '• Sipariş sorgusu: uygulandı; resmi hesap gerekli.\n• Kabul / ret / hazır: güncel Meal sözleşmesi doğrulanana kadar kapalı.\n• Mağaza, menü ve finans iş akışları: DEMO.'
                    : '• Sipariş alma: onaylı hesap ve ayrı HTTPS gateway gerekli.\n• PC kabulü / hazır: resmi hesap izinleri ve sipariş callback’i gerekli.\n• Mağaza, menü ve finans iş akışları: DEMO.',
                style: const TextStyle(fontSize: 12, height: 1.9, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
