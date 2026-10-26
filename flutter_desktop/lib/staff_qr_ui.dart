import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'lan_server.dart';
import 'pos_store.dart';
import 'pos_logic.dart';

class StaffQrPanel extends StatefulWidget {
  const StaffQrPanel({super.key, required this.server, required this.editor});
  final PosLanServer server;
  final Widget editor;
  @override
  State<StaffQrPanel> createState() => _StaffQrPanelState();
}

class _StaffQrPanelState extends State<StaffQrPanel> {
  final codes = <int, EnrollmentCode>{};
  int? selected;
  bool admin = false;
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

  Widget card(Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
  @override
  Widget build(BuildContext context) {
    final server = widget.server, auth = server.auth;
    final people = asMaps(server.store.read().data['employees']);
    if (!people.any((p) => p['id'] == selected)) {
      selected = people.firstOrNull?['id'] as int?;
    }
    final person = people.where((p) => p['id'] == selected).firstOrNull;
    final code = codes[selected];
    final valid =
        code != null && DateTime.parse(code.expiresAt).isAfter(DateTime.now());
    final enabled =
        person?['active'] == true && server.running && server.available;
    final sessions = selected == null ? <Json>[] : auth.sessions(selected!);
    final active = sessions
        .where(
          (s) =>
              s['revoked_at'] == null &&
              DateTime.parse('${s['expires_at']}').isAfter(DateTime.now()),
        )
        .toList();
    final qrCard = card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            person == null
                ? 'Personel seçin'
                : '${person['name']} · Telefon Bağla',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bir kez okut. Vardiya boyunca kullan.',
            style: TextStyle(color: Color(0xff7c8b80)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: enabled
                ? () => action(() => codes[selected!] = auth.issue(selected!))
                : null,
            icon: const Icon(Icons.qr_code_scanner),
            label: Text(
              valid
                  ? 'Yeni Telefon İçin QR Oluştur'
                  : 'Telefon Bağla · QR Oluştur',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffe4e9e3)),
            ),
            child: valid && server.running
                ? QrImageView(
                    data: '${server.staffUrl}#enroll=${code.token}',
                    size: 300,
                    backgroundColor: Colors.white,
                  )
                : const SizedBox(
                    width: 300,
                    height: 180,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_rounded,
                          size: 96,
                          color: Color(0xff93ac9b),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Personeli seçin ve Telefon Bağla’ya basın.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffedf5e9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Text(
                  '10 dakika = yalnızca ilk eşleştirme',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Telefon etkinleşince oturum 30 gün açık kalır. 10+ saatlik vardiya boyunca tekrar QR okutmanız gerekmez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          if (valid)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'QR son kullanım: ${DateTime.parse(code.expiresAt).toLocal().toString().substring(11, 16)} · Tek kullanımlık',
                style: const TextStyle(color: Color(0xff7c8b80), fontSize: 12),
              ),
            ),
          if (!server.running)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Telefon bağlantısı kapalı. Aşağıdaki bağlantı ayarlarını kontrol edin.',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
        ],
      ),
    );
    final devices = card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.smartphone_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bağlı cihazlar · ${active.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Her telefon kendi oturumunu korur. Aynı bilgisayara ve aynı restoran verilerine bağlanır.',
            style: TextStyle(color: Color(0xff7c8b80), height: 1.5),
          ),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 38),
              child: Column(
                children: [
                  Icon(
                    Icons.phonelink_setup_rounded,
                    size: 42,
                    color: Color(0xff9db6a4),
                  ),
                  SizedBox(height: 10),
                  Text('Henüz bağlı telefon yok.'),
                ],
              ),
            ),
          for (final session in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_android_rounded),
              title: Text('${session['device_name']}'),
              subtitle: const Text('Oturum açık · 30 gün'),
              trailing: TextButton(
                onPressed: () => action(() => auth.revoke('${session['id']}')),
                child: const Text('Bağlantıyı Kes'),
              ),
            ),
          const Divider(height: 32),
          if (selected != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => action(() {
                    auth.disable(selected!);
                    codes.remove(selected);
                  }),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Erişimi Kapat'),
                ),
                TextButton(
                  onPressed: enabled
                      ? () => action(
                          () => codes[selected!] = auth.issue(
                            selected!,
                            revokeSessions: true,
                          ),
                        )
                      : null,
                  child: const Text('QR ve Tüm Oturumları Yenile'),
                ),
              ],
            ),
          const SizedBox(height: 10),
          const Text(
            'Yenileme eski QR’ı ve seçili personelin tüm telefon oturumlarını kapatır.',
            style: TextStyle(fontSize: 12, color: Color(0xff7c8b80)),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ekibiniz ve telefon bağlantıları tek yerde.',
          style: TextStyle(color: Color(0xff7c8b80)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Telefon Bağlantıları'),
              selected: !admin,
              onSelected: (_) => setState(() => admin = false),
            ),
            ChoiceChip(
              label: const Text('Personel Bilgileri'),
              selected: admin,
              onSelected: (_) => setState(() => admin = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (admin)
          card(widget.editor)
        else ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in people)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xffe6efe3),
                    child: Text('${p['name']}'.substring(0, 1)),
                  ),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${p['name']} · ${p['active'] == true && auth.enabled(p['id'] as int) ? 'Erişim açık' : 'Erişim kapalı'}',
                    ),
                  ),
                  selected: selected == p['id'],
                  onSelected: (_) => setState(() => selected = p['id'] as int),
                ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (ctx, constraints) => constraints.maxWidth >= 950
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: qrCard),
                      const SizedBox(width: 18),
                      Expanded(flex: 5, child: devices),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [qrCard, const SizedBox(height: 18), devices],
                  ),
          ),
        ],
        const SizedBox(height: 20),
        card(
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: Icon(
              server.running ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: server.running
                  ? const Color(0xff42704a)
                  : Colors.deepOrange,
            ),
            title: Text(
              server.running
                  ? 'Ortak Wi-Fi bağlantısı açık'
                  : 'Wi-Fi bağlantısını kontrol edin',
            ),
            subtitle: const Text('Tüm personel aynı bilgisayara bağlanır'),
            children: [
              SelectableText(server.staffUrl),
              const SizedBox(height: 12),
              if (server.addresses.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: server.selectedIp,
                  decoration: const InputDecoration(
                    labelText: 'Bilgisayarın Wi-Fi adresi',
                  ),
                  items: server.addresses
                      .map((ip) => DropdownMenuItem(value: ip, child: Text(ip)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) server.chooseIp(v);
                  },
                ),
              if (server.error != null)
                Text(
                  server.error!,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: server.discover,
                    child: const Text('Bağlantıyı Yenile'),
                  ),
                  if (!server.running)
                    FilledButton(
                      onPressed: server.start,
                      child: const Text('Bağlantıyı Başlat'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Telefon ve bilgisayar aynı özel Wi-Fi ağında olmalı. Uygulama açık, bilgisayar uyanık kalmalı. Genel sunucu adresi kişisel QR yerine geçmez.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
