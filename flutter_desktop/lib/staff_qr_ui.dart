import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'lan_server.dart';
import 'pos_store.dart';
import 'pos_logic.dart';

class StaffQrPanel extends StatefulWidget {
  const StaffQrPanel({super.key, required this.server});
  final PosLanServer server;
  @override
  State<StaffQrPanel> createState() => _StaffQrPanelState();
}

class _StaffQrPanelState extends State<StaffQrPanel> {
  final codes = <int, EnrollmentCode>{};
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void action(void Function() f) {
    try {
      f();
      if (mounted) setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void showCode(int id, String name) {
    final code = codes[id];
    if (code == null ||
        DateTime.parse(code.expiresAt).isBefore(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce yeni QR oluşturun.')));
      return;
    }
    final url = '${widget.server.staffUrl}#enroll=${code.token}';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name · Cihaz Etkinleştirme QR'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(data: url, size: 240),
                SelectableText(url),
                const SizedBox(height: 12),
                Text(
                  'Tek kullanım · Son geçerlilik ${DateTime.parse(code.expiresAt).toLocal()}',
                ),
                const Text(
                  'Aynı laptop LAN sunucusu. QR kişisel erişim anahtarıdır; yalnızca ilgili çalışana gösterin.',
                ),
              ],
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server, auth = widget.server.auth;
    final employees = asMaps(server.store.read().data['employees']);
    return ExpansionTile(
      title: const Text('QR Yönetimi'),
      subtitle: const Text(
        'Personel cihazları · Şifresiz tek kullanımlık etkinleştirme',
      ),
      children: [
        Text(
          'Ortak LAN Server: ${server.staffUrl} · ${server.running ? 'Aktif' : 'Kapalı'}',
        ),
        const Text(
          'QR Yenile eski QR ve o çalışanın mevcut cihaz oturumlarını iptal eder. Yeni QR 10 dakika geçerlidir. Cihaz oturumu 30 gün veya yönetici iptaline kadar geçerlidir.',
        ),
        for (final e in employees)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e['name']} · ${e['active'] == true && auth.enabled(e['id'] as int) ? 'Erişim açık' : 'Erişim kapalı'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: e['active'] != true || !server.running
                            ? null
                            : () => action(
                                () => codes[e['id'] as int] = auth.issue(
                                  e['id'] as int,
                                ),
                              ),
                        child: const Text('Yeni Cihaz QR'),
                      ),
                      OutlinedButton(
                        onPressed: e['active'] != true || !server.running
                            ? null
                            : () => action(
                                () => codes[e['id'] as int] = auth.issue(
                                  e['id'] as int,
                                  revokeSessions: true,
                                ),
                              ),
                        child: const Text('QR Yenile'),
                      ),
                      OutlinedButton(
                        onPressed: codes.containsKey(e['id']) && server.running
                            ? () => showCode(e['id'] as int, '${e['name']}')
                            : null,
                        child: const Text('QR Göster'),
                      ),
                      OutlinedButton(
                        onPressed: () => action(() {
                          auth.disable(e['id'] as int);
                          codes.remove(e['id']);
                        }),
                        child: const Text('Erişimi Kapat'),
                      ),
                    ],
                  ),
                  for (final session in auth.sessions(e['id'] as int))
                    ListTile(
                      title: Text(
                        '${session['device_name']} · ${session['revoked_at'] == null ? 'Oturum' : 'İptal edildi'}',
                      ),
                      subtitle: Text(
                        'Etkinleştirme: ${session['created_at']} · Son kullanım: ${session['last_seen']}',
                      ),
                      trailing: session['revoked_at'] != null
                          ? null
                          : OutlinedButton(
                              onPressed: () =>
                                  action(() => auth.revoke('${session['id']}')),
                              child: const Text('Oturumu İptal Et'),
                            ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
