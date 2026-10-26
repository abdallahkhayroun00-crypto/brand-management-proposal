import 'package:flutter/material.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'workspace_ui.dart';

class CashWorkspace extends StatefulWidget {
  const CashWorkspace({
    super.key,
    required this.state,
    required this.edit,
    required this.onOrder,
  });
  final Json state;
  final EditState edit;
  final ValueChanged<int> onOrder;
  @override
  State<CashWorkspace> createState() => _CashWorkspaceState();
}

class _CashWorkspaceState extends State<CashWorkspace> {
  String tab = 'Açık Hesaplar', search = '';
  Future<void> open() async {
    final v = await askFields(context, 'Kasayı Aç', [
      ('Açılış bakiyesi ₺', '0'),
    ]);
    if (v != null) widget.edit((s) => openCash(s, parseMoney(v[0])));
  }

  Future<void> move(int direction) async {
    final v = await askFields(
      context,
      direction == 1 ? 'Kasa Giriş' : 'Kasa Çıkış',
      [('Tutar ₺', ''), ('Açıklama', '')],
    );
    if (v != null) {
      widget.edit((s) => moveCash(s, direction * parseMoney(v[0]), v[1]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = copyJson(widget.state),
        active = activeCash(s),
        book = cashBook(s);
    final openOrders = asMaps(s['orders'])
        .where(
          (o) =>
              !isPlatform(o) &&
              o['cancelled'] != true &&
              o['closed'] != true &&
              orderDueCents(o) > 0,
        )
        .toList();
    final orders = openOrders
        .where(
          (o) => '${o['id']} ${o['table']} ${o['source']}'
              .toLowerCase()
              .contains(search.toLowerCase()),
        )
        .toList();
    final sessions = asMaps(book['sessions']).reversed.toList(),
        movements = asMaps(book['movements']).reversed.toList();
    Widget body;
    if (tab == 'Açık Hesaplar') {
      body = WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('cash-search'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Sipariş veya masa ara',
              ),
              onChanged: (v) => setState(() => search = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WorkTable(
                headings: const [
                  'Sipariş',
                  'Kaynak / Masa',
                  'Toplam',
                  'Alınan',
                  'Kalan',
                ],
                rows: [
                  for (final o in orders)
                    [
                      '#${o['id']}',
                      '${o['source']}${o['table'] == null ? '' : ' · Masa ${o['table']}'}',
                      formatTry(orderTotalCents(o)),
                      formatTry(orderPaidCents(o)),
                      formatTry(orderDueCents(o)),
                    ],
                ],
                onRow: (i) => widget.onOrder(orders[i]['id'] as int),
                empty: 'Açık ödeme bulunmuyor.',
              ),
            ),
          ],
        ),
      );
    } else if (tab == 'Günlük Kasa') {
      body = WorkCard(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: const Color(0xffedf3e8),
                    child: Icon(
                      active == null ? Icons.lock_outline : Icons.point_of_sale,
                      color: pine,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active == null
                              ? 'Kasa kapalı'
                              : 'Kasa #${active['id']} · Açık',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          active == null
                              ? 'Vardiyaya başlamak için açılış bakiyesini girin.'
                              : 'Açılış ${istanbulTime(active['openedAt'])}',
                          style: const TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (active == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: open,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Kasayı Aç'),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 30,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Açılış Nakdi',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        Text(
                          formatTry(active['openingCents'] as int),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Beklenen Nakit',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        Text(
                          formatTry(expectedCash(s, active)),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: pine,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => move(1),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Kasa Giriş'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => move(-1),
                      icon: const Icon(Icons.remove, size: 18),
                      label: const Text('Kasa Çıkış'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        final v = await askFields(context, 'Kapanış Sayımı', [
                          ('Sayılan nakit ₺', ''),
                        ]);
                        if (v != null) {
                          widget.edit((s) => closeCash(s, parseMoney(v[0])));
                        }
                      },
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Sayım ve Kapanış'),
                    ),
                  ],
                ),
              ],
              const Divider(height: 40),
              const Text(
                'Nakit sayımı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Beklenen nakit = açılış + vardiya içindeki yerel nakit tahsilatı − nakit iadeleri + girişler − çıkışlar. Kart ve platform ödemeleri kasadaki nakit değildir. Kapanış sayımı ve fark geçmişte korunur.',
                style: TextStyle(fontSize: 12, height: 1.7, color: muted),
              ),
            ],
          ),
        ),
      );
    } else if (tab == 'Kasa Geçmişi') {
      body = WorkCard(
        child: WorkTable(
          headings: const [
            'Kasa / Durum',
            'Açılış · İstanbul',
            'Beklenen',
            'Sayılan',
            'Fark',
          ],
          rows: [
            for (final c in sessions)
              [
                '#${c['id']} · ${c['closedAt'] == null ? 'Açık' : 'Kapalı'}',
                istanbulTime(c['openedAt']),
                formatTry(
                  c['closedAt'] == null
                      ? expectedCash(s, c)
                      : c['expectedCents'] as int,
                ),
                c['closedAt'] == null
                    ? '—'
                    : formatTry(c['countedCents'] as int),
                c['closedAt'] == null
                    ? '—'
                    : formatTry(c['differenceCents'] as int),
              ],
          ],
          onRow: (i) {
            final c = sessions[i];
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Kasa #${c['id']}'),
                content: Text(
                  'Açılış: ${istanbulTime(c['openedAt'])}\nKapanış: ${istanbulTime(c['closedAt'])}\nAçılış bakiyesi: ${formatTry(c['openingCents'] as int)}\nBeklenen: ${formatTry(c['closedAt'] == null ? expectedCash(s, c) : c['expectedCents'] as int)}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      body = WorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: active == null ? null : () => move(1),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Kasa Giriş'),
                ),
                OutlinedButton.icon(
                  onPressed: active == null ? null : () => move(-1),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Kasa Çıkış'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: WorkTable(
                headings: const [
                  'Kasa',
                  'Açıklama',
                  'Tarih · İstanbul',
                  'Tutar',
                ],
                rows: [
                  for (final m in movements)
                    [
                      '#${m['sessionId']}',
                      '${m['note']}',
                      istanbulTime(m['at']),
                      formatTry(m['cents'] as int),
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
          'Kasa & Ödemeler',
          'Ödeme ve sayım yalnızca bilgisayardan yapılır. Banka POS / ÖKC bağlı değil.',
        ),
        SizedBox(
          height: 96,
          child: Row(
            children: [
              Expanded(
                child: WorkMetric(
                  label: 'Açık Hesaplar',
                  value: '${openOrders.length}',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => setState(() => tab = 'Açık Hesaplar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WorkMetric(
                  label: 'Restoran Alacağı',
                  value: formatTry(
                    openOrders.fold<int>(0, (n, o) => n + orderDueCents(o)),
                  ),
                  icon: Icons.payments_outlined,
                  onTap: () => setState(() => tab = 'Açık Hesaplar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WorkMetric(
                  label: active == null ? 'Günlük Kasa' : 'Beklenen Nakit',
                  value: active == null
                      ? 'Kapalı'
                      : formatTry(expectedCash(s, active)),
                  icon: Icons.point_of_sale,
                  onTap: () => setState(() => tab = 'Günlük Kasa'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        WorkTabs(
          values: const [
            'Açık Hesaplar',
            'Günlük Kasa',
            'Kasa Geçmişi',
            'Nakit Hareketleri',
          ],
          selected: tab,
          onChanged: (v) => setState(() => tab = v),
        ),
        const SizedBox(height: 14),
        Expanded(child: body),
      ],
    );
  }
}
