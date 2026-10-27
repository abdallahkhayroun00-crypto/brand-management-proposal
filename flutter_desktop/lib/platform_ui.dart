import 'order_reporting.dart';

import 'package:flutter/material.dart';

import 'pos_logic.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'platform_workflows.dart';

class PlatformPanel extends StatefulWidget {
  const PlatformPanel({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  State<PlatformPanel> createState() => _PlatformPanelState();
}

class _PlatformPanelState extends State<PlatformPanel> {
  String tab = 'Siparişler',
      source = 'Trendyol Go',
      status = 'Tümü',
      search = '',
      reviewFrom = '',
      reviewTo = '',
      reviewReply = 'Tümü',
      reviewComment = 'Tümü';
  final selectedMenu = <String>{}, selectedItems = <String>{};
  final claimItems = <String>{};
  static const tabs = [
    'Siparişler',
    'Mağaza',
    'Menü',
    'İade Talepleri',
    'Değerlendirmeler',
    'Faturalar',
    'Senkronizasyon',
  ];
  bool edit(void Function(Json) f) => widget.edit(f);
  Widget button(String label, void Function()? action) => Padding(
    padding: const EdgeInsets.only(right: 6, bottom: 6),
    child: OutlinedButton(onPressed: action, child: Text(label)),
  );
  Widget dropdown(
    String value,
    List<String> options,
    ValueChanged<String> change,
  ) => SizedBox(
    width: 215,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      key: ValueKey('$tab:$value:${options.join()}'),
      initialValue: value,
      items: options
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (v) => setState(() => change(v!)),
    ),
  );
  void request(String type, Object target, Json p) =>
      edit((s) => queuePlatform(s, type, source, target, p));
  Json hub() => platformHub(copyJson(widget.state));
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Online Siparişler · DEMO'),
      info(
        'Gerçek platform API’si bağlı değil. Test istekleri Senkronizasyon ekranında açık sonuç bekler. Kurye ve tahsilat platforma aittir.',
      ),
      dropdown(source, platformSources, (v) {
        source = v;
        status = 'Tümü';
        selectedMenu.clear();
        selectedItems.clear();
      }),
      if (source == 'Yemeksepeti')
        info(
          'Yemeksepeti restoran yönetim yetenekleri doğrulanmadı. Mağaza, menü, talep, yorum, fatura ve finans yazmaları kapalı.',
        ),
      Wrap(
        spacing: 6,
        children: [
          for (final t in tabs)
            ChoiceChip(
              label: Text(t),
              selected: tab == t,
              onSelected: (_) => setState(() {
                tab = t;
                status = 'Tümü';
                search = '';
              }),
            ),
        ],
      ),
      const SizedBox(height: 15),
      switch (tab) {
        'Mağaza' => stores(),
        'Menü' => menu(),
        'İade Talepleri' => claims(),
        'Değerlendirmeler' => reviews(),
        'Faturalar' => invoices(),
        'Senkronizasyon' => sync(),
        _ => orders(),
      },
    ],
  );
  Widget orders() {
    final rows = asMaps(widget.state['orders'])
        .where(
          (o) =>
              o['source'] == source &&
              (status == 'Tümü' || o['demoRemoteStatus'] == status),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          children: [
            dropdown(status, ['Tümü', ...remoteStates], (v) => status = v),
            for (final kind in [
              ('card', 'Online Kart'),
              ('cod', 'Teslimatta'),
              ('meal', 'Yemek Kartı'),
              ('pickup', 'Platform Gel-Al'),
            ])
              button(
                'Örnek ${kind.$2}',
                () => edit(
                  (s) => importPlatform(s, platformFixture(s, source, kind.$1)),
                ),
              ),
          ],
        ),
        if (rows.isEmpty) info('Bu filtrede platform siparişi yok.'),
        for (final o in rows.reversed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  panelTitle(
                    '#${displayOrderNumber(o)} · ${o['platformPackageId']} · ${o['demoRemoteStatus']}',
                  ),
                  Text(
                    'Toplam ${formatTry(orderTotalCents(o))} · ${o['platformDeliveryType']} · Tahsilat ${o['platformCollection']}',
                  ),
                  Text(
                    '${o['platformPaymentLabel']} · Sipariş revizyonu ${o['platformRevision']}',
                  ),
                  Text(
                    'İndirim ${o['platformSnapshot']?['discount'] ?? 0} ₺ · PIN ${o['platformSnapshot']?['pinCode'] ?? '—'} · Arama ${o['platformSnapshot']?['callCenterPhone'] ?? '—'}',
                  ),
                  Text(
                    'Kurye ETA ${o['platformSnapshot']?['etaMin'] ?? '—'} → ${o['platformSnapshot']?['etaMax'] ?? '—'} · ${o['platformSnapshot']?['pickupEtaState'] ?? '—'}',
                  ),
                  if (o['cancelled'] != true) ...[
                    if (o['demoRemoteStatus'] == 'Created')
                      Wrap(
                        children: [
                          if (storeConfig(
                                copyJson(widget.state),
                                source,
                              )['acceptFlow'] ==
                              'direct')
                            button('Kabul İste', () async {
                              final v = await askFields(
                                context,
                                'Kabul İsteği',
                                [('Hazırlık süresi (1–180 dakika)', '20')],
                              );
                              if (v != null) {
                                edit((s) {
                                  final prep = parseInteger(v[0]);
                                  if (prep < 1 || prep > 180) {
                                    throw const FormatException(
                                      'Hazırlık süresi 1–180 dakika',
                                    );
                                  }
                                  queuePlatform(s, 'accept', source, o['id'], {
                                    'expected': 'Created',
                                    'preparationTime': prep,
                                  });
                                });
                              }
                            })
                          else
                            info(
                              'Kabul Vendor App üzerinden gelen olayı bekler.',
                            ),
                        ],
                      ),
                    if (o['demoRemoteStatus'] == 'Picking')
                      button(
                        'Hazır Bildirimi İste',
                        () =>
                            request('ready', o['id'], {'expected': 'Picking'}),
                      ),
                    for (final l in checkLines(o))
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selectedItems.contains(
                          '${l.line['packageItemId']}',
                        ),
                        title: Text(
                          '${l.line['qty']} × ${l.line['name']} · ${formatTry(l.total)}',
                        ),
                        subtitle: Text(
                          '${l.line['note']} · Çıkar: ${(l.line['removed'] as List? ?? []).join(', ')}',
                        ),
                        onChanged:
                            source == 'Trendyol Go' && o['closed'] != true
                            ? (v) => setState(() {
                                if (v == true) {
                                  selectedItems.add(
                                    '${l.line['packageItemId']}',
                                  );
                                } else {
                                  selectedItems.remove(
                                    '${l.line['packageItemId']}',
                                  );
                                }
                              })
                            : null,
                      ),
                    if (source == 'Trendyol Go' && o['closed'] != true)
                      button('Seçili Ürünleri İptal İste', () async {
                        final ids = checkLines(o)
                            .where(
                              (l) => selectedItems.contains(
                                l.line['packageItemId'],
                              ),
                            )
                            .map((l) => l.line['packageItemId'])
                            .toList();
                        final v = await askFields(
                          context,
                          'Trendyol Go İptal',
                          [('Neden: 621 / 622 / 623 / 627', '621')],
                        );
                        if (v != null) {
                          edit((s) {
                            final reason = parseInteger(v[0]);
                            if (ids.isEmpty ||
                                ![621, 622, 623, 627].contains(reason)) {
                              throw const FormatException(
                                'Ürün ve geçerli neden seçin',
                              );
                            }
                            queuePlatform(s, 'cancel', source, o['id'], {
                              'expected': o['demoRemoteStatus'],
                              'reasonId': reason,
                              'itemIds': ids,
                            });
                          });
                        }
                      }),
                    ExpansionTile(
                      title: const Text('Test: Gelen Platform Olayları'),
                      children: [
                        Wrap(
                          children: [
                            for (final next in [
                              'Picking',
                              'Invoiced',
                              'Shipped',
                              'Delivered',
                              'Cancelled',
                            ])
                              if (allowedRemote(
                                    '${o['demoRemoteStatus']}',
                                    next,
                                  ) &&
                                  o['demoRemoteStatus'] != next &&
                                  !(next == 'Shipped' &&
                                      o['platformPickup'] == true))
                                button(
                                  'Test: $next',
                                  () => edit(
                                    (s) => externalPlatformEvent(
                                      s,
                                      o['id'] as int,
                                      next,
                                    ),
                                  ),
                                ),
                            if (o['platformCollection'] != 'Collected')
                              button(
                                'Test: Tahsilat Onayı',
                                () => edit(
                                  (s) => platformCollected(
                                    mutableOrder(s, o['id'] as int)!,
                                  ),
                                ),
                              ),
                            if (source == 'Trendyol Go' &&
                                o['demoRemoteStatus'] == 'Delivered') ...[
                              for (final type in ['PAY_BACK', 'PRODUCT_RESEND'])
                                button(
                                  'Örnek Talep $type',
                                  () => edit(
                                    (s) => sampleClaim(s, o['id'] as int, type),
                                  ),
                                ),
                            ],
                            button(
                              'Test: Paketi Tekrar Al',
                              () => edit(
                                (s) => importPlatform(
                                  s,
                                  copyJson(
                                    (o['platformSnapshot'] as Map)
                                        .cast<String, dynamic>(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  ExpansionTile(
                    title: const Text('Sipariş Geçmişi'),
                    children: [
                      for (final e in o['events'] as List)
                        ListTile(title: Text('$e')),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget stores() {
    final cfg = storeConfig(copyJson(widget.state), source),
        blocked = source == 'Yemeksepeti';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Mağaza ve Haftalık Saatler'),
        Text(
          '${cfg['storeId']} · ${cfg['supplierId']} · ${cfg['open'] == true ? 'Açık' : 'Kapalı'}',
        ),
        Wrap(
          children: [
            button(
              cfg['open'] == true ? 'Mağazayı Kapat İste' : 'Mağazayı Aç İste',
              blocked
                  ? null
                  : () =>
                        request('store', source, {'open': cfg['open'] != true}),
            ),
            button('Kabul Akışı (Yerel Senaryo)', () async {
              final v = await askFields(
                context,
                'Kabul Akışı · Yalnızca Senaryo',
                [('direct / indirect', '${cfg['acceptFlow']}')],
              );
              if (v != null) {
                edit((s) {
                  if (!['direct', 'indirect'].contains(v[0])) {
                    throw const FormatException('direct / indirect seçin');
                  }
                  storeConfig(s, source)['acceptFlow'] = v[0];
                });
              }
            }),
          ],
        ),
        SwitchListTile(
          title: const Text('Uber Eats geçişi · Yerel Senaryo'),
          value: cfg['migrated'] == true,
          onChanged: blocked
              ? null
              : (v) => edit((s) => storeConfig(s, source)['migrated'] = v),
        ),
        for (var day = 0; day < 7; day++)
          Builder(
            builder: (context) {
              final index = day, h = asMaps(cfg['hours'])[day];
              return ListTile(
                title: Text(
                  '${['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'][day]} · ${h['closed'] == true ? 'Kapalı' : '${h['start']} → ${h['end']}'}',
                ),
                trailing: button(
                  'Saat İsteği',
                  blocked
                      ? null
                      : () async {
                          final v =
                              await askFields(context, 'Haftalık Saatler', [
                                ('Başlangıç HH:mm', '${h['start']}'),
                                ('Bitiş HH:mm', '${h['end']}'),
                                (
                                  'Kapalı: evet / hayır',
                                  h['closed'] == true ? 'evet' : 'hayır',
                                ),
                              ]);
                          if (v != null) {
                            edit((s) {
                              final hours = asMaps(cfg['hours']);
                              hours[index] = {
                                'start': v[0],
                                'end': v[1],
                                'closed': v[2] == 'evet',
                              };
                              validateHours(hours);
                              queuePlatform(s, 'hours', source, source, {
                                'hours': hours,
                              });
                            });
                          }
                        },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget menu() {
    final rows = asMaps(hub()['menu'][source]),
        blocked = source == 'Yemeksepeti';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Platform Menü ve Ürünler'),
        info(
          'Yerel eşleme ve örnek platform fiyatları ayrı. Eski sipariş fiyatları değişmez.',
        ),
        TextFormField(
          key: ValueKey('$tab:$source'),
          decoration: const InputDecoration(
            labelText: 'Ürün / platform ID ara',
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        Wrap(
          children: [
            button(
              'Seçili Fiyatları Gönder',
              blocked
                  ? null
                  : () async {
                      final v = await askFields(context, 'Toplu Fiyat İsteği', [
                        ('Yeni fiyat ₺', ''),
                        ('Son satır hata: evet / hayır', 'hayır'),
                      ]);
                      if (v != null) {
                        edit((s) {
                          if (selectedMenu.isEmpty) {
                            throw const FormatException('Ürün seçin');
                          }
                          queuePlatform(s, 'price', source, 'bulk', {
                            'partial': v[1] == 'evet',
                            'items': [
                              for (final id in selectedMenu)
                                {
                                  'id': id,
                                  'price': fromCents(parseMoney(v[0])),
                                },
                            ],
                          });
                        });
                      }
                    },
            ),
            for (final category in rows.map((m) => '${m['cat']}').toSet())
              button(
                '$category Aç/Kapat',
                blocked
                    ? null
                    : () async {
                        final v = await askFields(context, 'Kategori Durumu', [
                          ('ACTIVE / PASSIVE', 'ACTIVE'),
                        ]);
                        if (v != null) {
                          request('category-status', category, {
                            'status': v[0],
                          });
                        }
                      },
              ),
          ],
        ),
        for (final m in rows.where(
          (m) => '${m['name']} ${m['id']}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        ))
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  value: selectedMenu.contains(m['id']),
                  title: Text('${m['name']} · ${formatTry(cents(m['price']))}'),
                  subtitle: Text(
                    '${m['id']} · Yerel ${m['localId'] ?? 'Eşlenmedi'} · ${m['status']} / ${m['categoryStatus']}',
                  ),
                  onChanged: blocked
                      ? null
                      : (v) => setState(() {
                          if (v == true) {
                            selectedMenu.add('${m['id']}');
                          } else {
                            selectedMenu.remove(m['id']);
                          }
                        }),
                ),
                Wrap(
                  children: [
                    button(
                      'Ürün Aç/Kapat İste',
                      blocked
                          ? null
                          : () => request('menu-status', m['id'], {
                              'status': m['status'] == 'ACTIVE'
                                  ? 'PASSIVE'
                                  : 'ACTIVE',
                            }),
                    ),
                    button(
                      'Yerel Ürün Eşle',
                      blocked
                          ? null
                          : () async {
                              final v =
                                  await askFields(context, 'Yerel Eşleme', [
                                    (
                                      'Yerel ürün ID (boş = eşlenmedi)',
                                      '${m['localId'] ?? ''}',
                                    ),
                                  ]);
                              if (v != null) {
                                edit((s) {
                                  final localId = v[0].isEmpty
                                      ? null
                                      : parseInteger(v[0]);
                                  if (localId != null &&
                                      !asMaps(
                                        s['localMenu'],
                                      ).any((p) => p['id'] == localId)) {
                                    throw const FormatException(
                                      'Yerel ürün yok',
                                    );
                                  }
                                  final row =
                                      (platformHub(s)['menu'][source] as List)
                                          .cast<Map>()
                                          .firstWhere(
                                            (r) => r['id'] == m['id'],
                                          );
                                  row['localId'] = localId;
                                });
                              }
                            },
                    ),
                    for (final group in asMaps(m['modifierGroups']))
                      button(
                        '${group['name']} · Yerel Seçenek Senaryosu',
                        blocked
                            ? null
                            : () async {
                                final v = await askFields(
                                  context,
                                  'Seçenek Kullanılabilirliği · API Değil',
                                  [
                                    ('Seçenek ID', 'regular'),
                                    ('Aktif: evet / hayır', 'evet'),
                                  ],
                                );
                                if (v != null) {
                                  edit((s) {
                                    final row =
                                        (platformHub(s)['menu'][source] as List)
                                            .cast<Map>()
                                            .firstWhere(
                                              (r) => r['id'] == m['id'],
                                            );
                                    final g = (row['modifierGroups'] as List)
                                        .cast<Map>()
                                        .firstWhere(
                                          (r) => r['id'] == group['id'],
                                        );
                                    final options = (g['options'] as List)
                                            .cast<Map>(),
                                        option = (g['options'] as List)
                                            .cast<Map>()
                                            .where((r) => r['id'] == v[0])
                                            .firstOrNull;
                                    if (option == null) {
                                      throw const FormatException(
                                        'Seçenek yok',
                                      );
                                    }
                                    option['active'] = v[1] == 'evet';
                                    if (options
                                            .where(
                                              (p) =>
                                                  p['active'] == true &&
                                                  cents(p['price']) == 0,
                                            )
                                            .length <
                                        (g['min'] as int)) {
                                      throw const FormatException(
                                        'Zorunlu ücretsiz seçenek korunmalı',
                                      );
                                    }
                                  });
                                }
                              },
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget claims() {
    final rows = asMaps(hub()['claims']).where(
      (c) =>
          c['source'] == source && (status == 'Tümü' || c['status'] == status),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('İade Talepleri'),
        info(
          'Talep kabulü kasadan iade oluşturmaz. İtiraz platform incelemesine gider.',
        ),
        dropdown(status, [
          'Tümü',
          'WaitingInAction',
          'Unresolved',
          'Accepted',
          'Rejected',
        ], (v) => status = v),
        for (final c in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['id']} · #${c['orderId']} · ${c['type']} · ${c['status']}',
                  ),
                  Text(
                    'Son yanıt ${c['deadline']} · Kanıt: ${(c['images'] as List? ?? []).length} görsel',
                  ),
                  Text('${c['reason']}'),
                  for (final item in asMaps(c['items']))
                    CheckboxListTile(
                      value: claimItems.contains(item['id']),
                      title: Text(
                        '${item['name']} · ${formatTry(cents(item['amount']))} · ${item['status']}',
                      ),
                      onChanged: item['status'] != 'WaitingInAction'
                          ? null
                          : (v) => setState(() {
                              if (v == true) {
                                claimItems.add('${item['id']}');
                              } else {
                                claimItems.remove(item['id']);
                              }
                            }),
                    ),
                  Wrap(
                    children: [
                      for (final decision in ['accept', 'reject'])
                        button(
                          decision == 'accept'
                              ? 'Seçili Kabul İste'
                              : 'Seçili İtiraz İste',
                          source == 'Yemeksepeti'
                              ? null
                              : () async {
                                  final v = await askFields(
                                    context,
                                    'Talep Yanıtı',
                                    [('Açıklama (itiraz 5000 · Diğer)', '')],
                                  );
                                  if (v != null) {
                                    request('claim', c['id'], {
                                      'decision': decision,
                                      'reasonId': 5000,
                                      'note': v[0],
                                      'itemIds': asMaps(c['items'])
                                          .where(
                                            (i) => claimItems.contains(i['id']),
                                          )
                                          .map((i) => i['id'])
                                          .toList(),
                                    });
                                  }
                                },
                        ),
                      if (c['status'] == 'Unresolved')
                        for (final finalStatus in ['Accepted', 'Rejected'])
                          button(
                            'Test: $finalStatus',
                            () => edit((s) {
                              final claim = findRecord(s, 'claims', c['id']);
                              claim['status'] = finalStatus;
                              claim['completionDate'] = utcNow();
                            }),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget reviews() {
    final cfg = storeConfig(copyJson(widget.state), source),
        blocked = source == 'Yemeksepeti' || cfg['migrated'] == true;
    final all = asMaps(
      hub()['reviews'],
    ).where((r) => r['source'] == source).toList();
    final rows = all.where((r) {
      final stamp = '${r['createdAt']}',
          date =
              DateTime.tryParse(stamp)
                  ?.toUtc()
                  .add(const Duration(hours: 3))
                  .toIso8601String()
                  .substring(0, 10) ??
              '';
      final hasText = '${r['text'] ?? ''}'.isNotEmpty,
          hasReply = '${r['reply'] ?? ''}'.isNotEmpty;
      return (status == 'Tümü' || r['replyStatus'] == status) &&
          '${r['text']} ${r['orderCode']}'.toLowerCase().contains(
            search.toLowerCase(),
          ) &&
          (reviewFrom.isEmpty || date.compareTo(reviewFrom) >= 0) &&
          (reviewTo.isEmpty || date.compareTo(reviewTo) <= 0) &&
          (reviewReply == 'Tümü' || hasReply == (reviewReply == 'Var')) &&
          (reviewComment == 'Tümü' || hasText == (reviewComment == 'Var'));
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        panelTitle('Değerlendirmeler'),
        if (blocked)
          info('Bu senaryoda yorum erişimi kapalı.')
        else ...[
          Wrap(
            children: [
              for (final key in ['score', 'flavor', 'service', 'delivery'])
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '$key: ${all.isEmpty ? '—' : (all.fold<num>(0, (n, r) => n + (r[key] as num)) / all.length).toStringAsFixed(1)} / 5',
                  ),
                ),
            ],
          ),
          Wrap(
            children: [
              button(
                'Örnek Yorum Al',
                () => edit((s) => sampleReview(s, source)),
              ),
              dropdown(status, [
                'Tümü',
                'NONE',
                'WAITING_FOR_APPROVE',
                'APPROVED',
                'REJECTED',
              ], (v) => status = v),
              button('Yorum Filtreleri', () async {
                final v = await askFields(context, 'Yorum Filtreleri', [
                  ('Metin / sipariş kodu', search),
                  ('Başlangıç YYYY-MM-DD', reviewFrom),
                  ('Bitiş YYYY-MM-DD', reviewTo),
                  ('Yanıt: Tümü / Var / Yok', reviewReply),
                  ('Yorum metni: Tümü / Var / Yok', reviewComment),
                ]);
                if (v != null && mounted) {
                  setState(() {
                    search = v[0];
                    reviewFrom = v[1];
                    reviewTo = v[2];
                    reviewReply = v[3];
                    reviewComment = v[4];
                  });
                }
              }),
            ],
          ),
          for (final r in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['score']}/5 · ${r['text']} · ${r['replyStatus']}',
                    ),
                    Text('Yanıt: ${r['reply'] ?? ''}'),
                    Wrap(
                      children: [
                        button('Yanıtı Onaya Gönder', () async {
                          final v = await askFields(context, 'Yorum Yanıtı', [
                            ('Restoran yanıtı', '${r['reply'] ?? ''}'),
                          ]);
                          if (v != null) {
                            request('reply', r['id'], {'text': v[0]});
                          }
                        }),
                        if (r['replyStatus'] == 'WAITING_FOR_APPROVE')
                          for (final outcome in ['APPROVED', 'REJECTED'])
                            button(
                              'Test: $outcome',
                              () => edit(
                                (s) => findRecord(
                                  s,
                                  'reviews',
                                  r['id'],
                                )['replyStatus'] = outcome,
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget invoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Fatura Bağlantıları'),
      info(
        'Mali fatura üretmez. Hazır bildirimi fatura değildir. Değiştirmeden önce eski bağlantıyı silin.',
      ),
      for (final o in asMaps(widget.state['orders']).where(
        (o) =>
            o['source'] == source &&
            o['demoRemoteStatus'] != 'Created' &&
            o['cancelled'] != true,
      ))
        button(
          '#${displayOrderNumber(o)} Fatura Bağlantısı İste',
          source == 'Yemeksepeti'
              ? null
              : () async {
                  final v = await askFields(context, 'Fatura Bağlantısı', [
                    ('HTTPS bağlantısı', ''),
                  ]);
                  if (v != null) request('invoice', o['id'], {'url': v[0]});
                },
        ),
      for (final i in asMaps(
        hub()['invoices'],
      ).where((i) => i['source'] == source))
        ListTile(
          title: Text('#${i['orderId']} · ${i['status']}'),
          subtitle: SelectableText('${i['url']}'),
          trailing: button(
            'Silme İsteği',
            i['status'] == 'Silindi (demo)' || source == 'Yemeksepeti'
                ? null
                : () => request('invoice-delete', i['id'], {}),
          ),
        ),
    ],
  );
  Widget sync() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      panelTitle('Senkronizasyon ve İşlem Günlüğü'),
      dropdown(status, [
        'Tümü',
        'Bekliyor',
        'Tamamlandı',
        'Hata',
      ], (v) => status = v),
      button(
        'Test: Kaçan Sipariş Kurtarma',
        () =>
            edit((s) => importPlatform(s, platformFixture(s, source, 'card'))),
      ),
      for (final j in asMaps(hub()['jobs']).where(
        (j) =>
            j['source'] == source &&
            (status == 'Tümü' || j['status'] == status),
      ))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${j['id']} · ${j['type']} · ${j['target']} · ${j['status']}',
                ),
                SelectableText(
                  'Request ID: ${j['requestId']} · Deneme ${j['attempts']} · ${j['createdAt']}',
                ),
                if ('${j['error'] ?? ''}'.isNotEmpty) Text('${j['error']}'),
                for (final result in asMaps(j['results']))
                  Text(
                    '${result['id']}: ${result['status']} · ${result['failureReasons']}',
                  ),
                Wrap(
                  children: [
                    if (j['status'] == 'Bekliyor') ...[
                      button(
                        'Test: Başarılı Sonuç',
                        () => edit((s) => resolvePlatform(s, '${j['id']}')),
                      ),
                      button(
                        'Test: 429 Hata',
                        () => edit(
                          (s) => resolvePlatform(s, '${j['id']}', fail: true),
                        ),
                      ),
                    ],
                    if (j['status'] == 'Hata' && j['results'] == null)
                      button(
                        'Yeniden Dene',
                        () => edit((s) => retryPlatform(s, '${j['id']}')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
