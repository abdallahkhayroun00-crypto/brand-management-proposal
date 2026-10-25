import 'package:flutter/material.dart';
import 'platform_api.dart';
import 'platform_runtime.dart';
import 'platform_workflows.dart';

class PlatformConnectionsPanel extends StatefulWidget {
  const PlatformConnectionsPanel({super.key, required this.runtime});
  final PlatformRuntime runtime;
  @override
  State<PlatformConnectionsPanel> createState() =>
      _PlatformConnectionsPanelState();
}

class _PlatformConnectionsPanelState extends State<PlatformConnectionsPanel> {
  int revision = 0;
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
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'Platform API Bağlantıları',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        for (final source in platformSources)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source == 'Trendyol Go'
                        ? 'Uber Eats Trendyol Go · Yemek'
                        : source,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.runtime.statuses[source] ??
                        'API bilgileri girilmedi · Bağlı değil',
                  ),
                  Wrap(
                    spacing: 7,
                    children: [
                      OutlinedButton(
                        onPressed: () => configure(source),
                        child: const Text('API Kodunu / Bilgilerini Gir'),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.runtime.testConnection(source),
                        child: const Text('Bağlantıyı Test Et'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
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
          ),
        const Text(
          'Bağlantı testi ile başarılı sipariş / hazır bildirimi testi farklıdır. DEMO siparişler canlı API’ye gönderilmez.',
        ),
      ],
    ),
  );
}
