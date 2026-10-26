import 'package:flutter/material.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'workspace_ui.dart';

class StaffDirectory extends StatefulWidget {
  const StaffDirectory({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  State<StaffDirectory> createState() => _StaffDirectoryState();
}

class _StaffDirectoryState extends State<StaffDirectory> {
  String search = '', filter = 'Tümü';
  Future<void> change([Json? person]) async {
    final name = TextEditingController(text: '${person?['name'] ?? ''}');
    var role = '${person?['role'] ?? 'Personel'}';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(person == null ? 'Personel Ekle' : 'Personel Düzenle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Ad'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Görev'),
                  items: [
                    for (final r in ['Personel', 'Yönetici'])
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => refresh(() => role = v!),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Görev etiketi telefonda ödeme veya online kabul yetkisi vermez.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (widget.edit(
                  (s) => saveEmployee(
                    s,
                    person?['id'] as int?,
                    name.text,
                    role,
                    person?['active'] == true || person == null,
                  ),
                )) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final all = asMaps(widget.state['employees']),
        rows = all
            .where(
              (p) =>
                  '${p['name']}'.toLowerCase().contains(search.toLowerCase()) &&
                  (filter == 'Tümü' ||
                      (filter == 'Aktif') == (p['active'] == true)),
            )
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading(
          'Personel Yönetimi',
          '${all.length} personel · QR ve cihaz erişimi Telefon Bağlantıları sekmesinde.',
          action: FilledButton.icon(
            onPressed: change,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Personel Ekle'),
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Personel ara',
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        const SizedBox(height: 12),
        WorkTabs(
          values: const ['Tümü', 'Aktif', 'Pasif'],
          selected: filter,
          onChanged: (v) => setState(() => filter = v),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const SizedBox(
            height: 140,
            child: WorkEmpty(title: 'Personel bulunamadı'),
          ),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in rows)
                SizedBox(
                  width: c.maxWidth > 700
                      ? (c.maxWidth - 24) / 3
                      : (c.maxWidth - 12) / 2,
                  child: WorkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xffedf3e8),
                              child: Text(
                                '${p['name']}'.substring(0, 1),
                                style: const TextStyle(color: pine),
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: p['active'] == true,
                              onChanged: (v) => widget.edit(
                                (s) => saveEmployee(
                                  s,
                                  p['id'] as int,
                                  '${p['name']}',
                                  '${p['role']}',
                                  v,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${p['name']}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${p['role']} · ${p['active'] == true ? 'Aktif' : 'Pasif'}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => change(p),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Düzenle'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
