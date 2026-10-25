import 'pos_logic.dart';
import 'operations.dart';

const platformSources = ['Trendyol Go', 'Yemeksepeti'];
const remoteStates = [
  'Created',
  'Picking',
  'Invoiced',
  'Shipped',
  'Delivered',
  'Cancelled',
  'UnSupplied',
];

/// Persisted simulation adapter. No network request or credential storage exists.
Json platformHub(Json state) {
  return (state.putIfAbsent(
            'integrations',
            () => {
              'version': 4,
              'sequence': 1,
              'stores': {
                for (final src in platformSources)
                  src: {
                    'storeId': 'DEMO-${src == 'Trendyol Go' ? 'TG' : 'YS'}',
                    'supplierId': 'DEMO-SUPPLIER',
                    'mode': 'GO',
                    'open': true,
                    'environment': 'DEMO',
                    'connection': 'Bağlı değil',
                    'acceptFlow': src == 'Yemeksepeti' ? 'indirect' : 'direct',
                    'migrated': false,
                    'hours': List.generate(
                      7,
                      (_) => {
                        'start': '11:00',
                        'end': '21:30',
                        'closed': false,
                      },
                    ),
                  },
              },
              'menu': {for (final src in platformSources) src: <dynamic>[]},
              'jobs': <dynamic>[],
              'claims': <dynamic>[],
              'reviews': <dynamic>[],
              'invoices': <dynamic>[],
              'settlements': <dynamic>[],
              'seen': <dynamic>[],
            },
          )
          as Map)
      .cast<String, dynamic>();
}

Json storeConfig(Json s, String source) =>
    (platformHub(s)['stores'][source] as Map).cast<String, dynamic>();
String platformId(Json s, String prefix) {
  final hub = platformHub(s), next = hub['sequence'] as int;
  hub['sequence'] = next + 1;
  return '$prefix-$next';
}

void seedPlatformMenu(Json s, List<Json> products) {
  final hub = platformHub(s);
  for (final source in platformSources) {
    final menu = hub['menu'][source] as List;
    if (menu.isNotEmpty) continue;
    for (final p in products.where((p) => p['price'] is num)) {
      menu.add({
        'id': '${source == 'Trendyol Go' ? 'TG' : 'YS'}-${p['id']}',
        'localId': p['id'],
        'name': p['name'],
        'cat': p['category'],
        'price': p['price'],
        'status': 'ACTIVE',
        'categoryStatus': 'ACTIVE',
        'ingredients': [],
        'modifierGroups': p['category'] == 'wrap'
            ? [
                {
                  'id': 'sauce-${p['id']}',
                  'name': 'Sos seçimi',
                  'min': 1,
                  'max': 1,
                  'options': [
                    {
                      'id': 'regular',
                      'name': 'Standart sos',
                      'price': 0,
                      'active': true,
                    },
                    {
                      'id': 'hot',
                      'name': 'Acılı sos',
                      'price': 0,
                      'active': true,
                    },
                  ],
                },
              ]
            : [],
      });
    }
  }
}

bool allowedRemote(String old, String next) {
  if (!remoteStates.contains(next)) return false;
  if (old == next) return true;
  if (['Delivered', 'Cancelled', 'UnSupplied'].contains(old)) return false;
  if (['Cancelled', 'UnSupplied'].contains(next)) return true;
  return remoteStates.indexOf(next) > remoteStates.indexOf(old);
}

Json platformFixture(Json s, String source, String kind) {
  final menu = asMaps(platformHub(s)['menu'][source])
      .where((m) => m['status'] == 'ACTIVE' && m['categoryStatus'] == 'ACTIVE')
      .toList();
  if (!platformSources.contains(source) ||
      menu.isEmpty ||
      storeConfig(s, source)['open'] != true) {
    throw const FormatException('Önce örnek menüyü ve mağazayı açın');
  }
  final p = menu.first,
      id = platformId(s, 'PACKAGE'),
      unit = cents(menu.first['price']) + 1000;
  final modifiers = <String>[];
  for (final group in asMaps(p['modifierGroups'])) {
    final available = asMaps(
      group['options'],
    ).where((o) => o['active'] == true && cents(o['price']) == 0).toList();
    final minimum = group['min'] as int;
    if (available.length < minimum) {
      throw const FormatException('Zorunlu ücretsiz seçenek eksik');
    }
    modifiers.addAll(available.take(minimum).map((o) => '${o['name']}'));
  }
  return {
    'source': source,
    'packageId': id,
    'orderId': 'ORDER-$id',
    'orderCode': 'DEMO-${s['nextId']}',
    'revision': 1,
    'status': 'Created',
    'createdAt': utcNow(),
    'storePickupSelected': kind == 'pickup',
    'collection': kind == 'cod' ? 'Pending' : 'Collected',
    'paymentType': kind == 'cod'
        ? 'PAY_WITH_ON_DELIVERY'
        : kind == 'meal'
        ? 'MEAL_CARD'
        : 'PAY_WITH_CARD',
    'customerName': 'DEMO MÜŞTERİ',
    'address': 'DEMO · Platform kuryesi',
    'pinCode': 'DEMO-1234',
    'callCenterPhone': 'DEMO-IVR',
    'pickupEtaState': 'SUCCESS',
    'etaMin': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 15))
        .toIso8601String(),
    'etaMax': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 20))
        .toIso8601String(),
    'orderTotal': fromCents(unit * 2 - 1000),
    'discount': 10,
    'sellerDiscount': 5,
    'note': 'Tamamen örnek sipariş',
    'items': List.generate(
      2,
      (i) => {
        'packageItemId': '$id-${i + 1}',
        'productId': p['id'],
        'localId': p['localId'],
        'name': p['name'],
        'quantity': 1,
        'unitSellingPrice': fromCents(unit),
        'modifiers': modifiers,
        'removed': ['Soğan'],
        'note': 'Sos ayrı',
      },
    ),
  };
}

List<Json> expandPlatformLines(Json packet) {
  final ids = <String>{};
  return asMaps(packet['items']).expand((p) {
    final qty = p['quantity'];
    if (qty is! int ||
        qty < 1 ||
        qty > 1000 ||
        p['packageItemId'] is! String ||
        !ids.add(p['packageItemId'] as String) ||
        p['unitSellingPrice'] is! num ||
        !(p['unitSellingPrice'] as num).isFinite ||
        cents(p['unitSellingPrice']) < 0) {
      throw const FormatException('Geçersiz platform ürünü');
    }
    return List.generate(
      qty,
      (i) => <String, dynamic>{
        'packageItemId': qty == 1
            ? p['packageItemId']
            : '${p['packageItemId']}:$i',
        'productId': p['localId'],
        'productKey': p['name'],
        'name': p['name'],
        'price': p['unitSellingPrice'],
        'qty': 1,
        'removed': p['removed'] ?? [],
        'note':
            '${(p['modifiers'] as List? ?? []).join(', ')} · ${p['note'] ?? ''}',
      },
    );
  }).toList();
}

void queueKitchen(Json s, Json o, Json batch) {
  final jobs = s['printJobs'] as List;
  if (!asMaps(
    jobs,
  ).any((j) => j['orderId'] == o['id'] && j['batchId'] == batch['id'])) {
    jobs.add({
      'orderId': o['id'],
      'batchId': batch['id'],
      'state': 'Bekliyor',
      'created': nowTime(),
    });
  }
}

void platformCollected(Json o) {
  if (o['platformCollection'] == 'Collected') return;
  o['platformCollection'] = 'Collected';
  (o['payments'] as List).add({
    'method': 'Platform',
    'amount': fromCents(orderTotalCents(o)),
    'createdAt': utcNow(),
    'time': nowTime(),
    'by': o['source'],
  });
}

void platformAdjustment(Json o, int signed, String reason) {
  if (signed == 0) return;
  (o.putIfAbsent('platformAdjustments', () => <dynamic>[]) as List).add({
    'amount': fromCents(signed),
    'stamp': utcNow(),
    'reason': reason,
  });
}

/// Idempotent import by source/package and increasing source revision.
Json? importPlatform(Json s, Json packet) {
  final source = packet['source'], version = packet['revision'];
  if (!platformSources.contains(source) ||
      version is! int ||
      version < 1 ||
      packet['packageId'] is! String ||
      '${packet['packageId']}'.isEmpty ||
      !remoteStates.contains(packet['status']) ||
      packet['orderTotal'] is! num ||
      !(packet['orderTotal'] as num).isFinite ||
      cents(packet['orderTotal']) < 0) {
    throw const FormatException('Geçersiz platform paketi');
  }
  final lines = expandPlatformLines(packet);
  if (lines.isEmpty &&
      !['Delivered', 'Cancelled', 'UnSupplied'].contains(packet['status'])) {
    throw const FormatException('Platform ürünü yok');
  }
  final existing = asMaps(s['orders'])
      .where(
        (o) =>
            o['source'] == source &&
            o['platformPackageId'] == packet['packageId'],
      )
      .firstOrNull;
  Json o;
  if (existing != null) {
    o = mutableOrder(s, existing['id'] as int)!;
    if (version <= (o['platformRevision'] as int)) return null;
    if (!allowedRemote('${o['demoRemoteStatus']}', '${packet['status']}')) {
      return null;
    }
    final before = orderTotalCents(o);
    final current = checkLines(o);
    // Record corrections without reprinting already imported kitchen batches.
    final changed =
        current.length != lines.length ||
        current.any(
          (l) => !lines.any(
            (n) =>
                n['packageItemId'] == l.line['packageItemId'] &&
                n['price'] == l.line['price'] &&
                n['note'] == l.line['note'],
          ),
        );
    if (changed) {
      for (final b in (o['batches'] as List).cast<Map>()) {
        for (final l in (b['lines'] as List).cast<Map>()) {
          l['voided'] = true;
        }
      }
      final batchId = (o['batches'] as List).length + 1;
      final batch = <String, dynamic>{
        'id': batchId,
        'staff': 'Platform',
        'createdAt': utcNow(),
        'time': nowTime(),
        'lines': lines,
      };
      (o['batches'] as List).add(batch);
      if (['Picking', 'Invoiced'].contains(packet['status'])) {
        queueKitchen(s, o, batch);
      }
      (o['events'] as List).add(
        '${utcNow()} · Platform ürün revizyonu · önceki parti yerine güncel parti',
      );
    }
    o['platformSnapshot'] = copyJson(packet);
    o['platformCancelledAmount'] = 0;
    if (o['platformCollection'] == 'Collected') {
      platformAdjustment(
        o,
        orderTotalCents(o) - before,
        'Platform revizyonu · DEMO',
      );
    }
  } else {
    final id = s['nextId'] as int;
    s['nextId'] = id + 1;
    o = {
      'id': id,
      'source': source,
      'table': null,
      'created': nowTime(),
      'createdAt': packet['createdAt'] ?? utcNow(),
      'closed': false,
      'cancelled': false,
      'batches': <dynamic>[
        {
          'id': 1,
          'staff': 'Platform',
          'time': nowTime(),
          'createdAt': utcNow(),
          'lines': lines,
        },
      ],
      'payments': <dynamic>[],
      'events': <dynamic>[],
      'platformSnapshot': copyJson(packet),
      'platformPackageId': packet['packageId'],
      'platformCollection': 'Pending',
      'platformCancelledAmount': 0,
    };
    (s['orders'] as List).add(o);
  }
  o['platformRevision'] = version;
  o['platformPickup'] = packet['storePickupSelected'] == true;
  o['platformDeliveryType'] = o['platformPickup'] == true
      ? 'GEL-AL'
      : 'Platform kuryesi';
  o['demoRemoteStatus'] = packet['status'];
  o['platformPaymentLabel'] = '${packet['paymentType']} · Tahsilat: platform';
  if (packet['collection'] == 'Collected') platformCollected(o);
  final terminal = [
    'Delivered',
    'Cancelled',
    'UnSupplied',
  ].contains(packet['status']);
  o['closed'] = terminal;
  if (['Cancelled', 'UnSupplied'].contains(packet['status'])) {
    if (o['platformCollection'] == 'Collected' && o['cancelled'] != true) {
      platformAdjustment(o, -orderTotalCents(o), 'Platform iptali · DEMO');
    }
    o['cancelled'] = true;
  }
  if (['Picking', 'Invoiced'].contains(packet['status'])) {
    for (final b in asMaps(
      o['batches'],
    ).where((b) => asMaps(b['lines']).any((l) => l['voided'] != true))) {
      queueKitchen(s, o, b);
    }
  }
  final cfg = storeConfig(s, '$source');
  cfg['lastSync'] = utcNow();
  cfg['cursor'] = packet['createdAt'];
  final seen = platformHub(s)['seen'] as List,
      identity = '$source:${packet['packageId']}';
  if (!seen.contains(identity)) seen.add(identity);
  return o;
}

List<List<Json>> validateHours(List<Json> hours) {
  if (hours.length != 7) throw const FormatException('7 gün gerekli');
  final days = List.generate(7, (_) => <Json>[]);
  int minute(String text) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
      throw const FormatException('Saat HH:mm olmalı');
    }
    final p = text.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  for (var day = 0; day < 7; day++) {
    final h = hours[day];
    if (h['closed'] == true) continue;
    final start = minute('${h['start']}'), end = minute('${h['end']}');
    if (start == end) throw const FormatException('Açılış kapanış aynı olamaz');
    days[day].add({'start': start, 'end': end > start ? end : 1440});
    if (end < start && end > 0) {
      days[(day + 1) % 7].add({'start': 0, 'end': end});
    }
  }
  for (final day in days) {
    day.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
    for (var i = 1; i < day.length; i++) {
      if ((day[i]['start'] as int) < (day[i - 1]['end'] as int)) {
        throw const FormatException('Gece yarısı saatleri çakışıyor');
      }
    }
  }
  return days;
}

Json queuePlatform(
  Json s,
  String type,
  String source,
  Object target,
  Json payload,
) {
  if (!platformSources.contains(source)) {
    throw const FormatException('Platform geçersiz');
  }
  final order = asMaps(
    s['orders'],
  ).where((o) => '${o['id']}' == '$target').firstOrNull;
  if (order != null && ['stage', 'live'].contains(order['integrationMode'])) {
    throw const FormatException(
      'Gerçek platform siparişi DEMO işlemiyle değiştirilemez',
    );
  }
  if (source == 'Yemeksepeti' && !['accept', 'ready', 'sync'].contains(type)) {
    throw const FormatException(
      'Yemeksepeti restoran yeteneği doğrulanmadı; kapalı',
    );
  }
  final hub = platformHub(s), key = '$type:$source:$target';
  if (asMaps(
    hub['jobs'],
  ).any((j) => j['key'] == key && j['status'] == 'Bekliyor')) {
    throw const FormatException('İstek zaten bekliyor');
  }
  final job = <String, dynamic>{
    'id': platformId(s, 'REQ'),
    'key': key,
    'type': type,
    'source': source,
    'target': '$target',
    'payload': copyJson(payload),
    'status': 'Bekliyor',
    'createdAt': utcNow(),
    'attempts': 1,
    'requestId': platformId(s, 'TRACE'),
    'error': '',
    'retryAfter': null,
  };
  (hub['jobs'] as List).insert(0, job);
  return job;
}

Json findRecord(Json s, String collection, Object id) =>
    (platformHub(s)[collection] as List)
        .cast<Map>()
        .firstWhere(
          (r) => '${r['id']}' == '$id',
          orElse: () => throw const FormatException('Kayıt bulunamadı'),
        )
        .cast<String, dynamic>();
void retryPlatform(Json s, String id, {DateTime? now}) {
  final j = findRecord(s, 'jobs', id);
  if (j['status'] != 'Hata' ||
      j['results'] != null ||
      (j['retryAfter'] is int &&
          (now ?? DateTime.now()).millisecondsSinceEpoch <
              (j['retryAfter'] as int))) {
    throw const FormatException(
      'Geri çekilme süresini bekleyin / başarısız satırları yeni istekle gönderin',
    );
  }
  j['status'] = 'Bekliyor';
  j['attempts'] = (j['attempts'] as int) + 1;
  j['requestId'] = platformId(s, 'TRACE');
}

void resolvePlatform(Json s, String id, {bool fail = false}) {
  final j = findRecord(s, 'jobs', id);
  final order = asMaps(
    s['orders'],
  ).where((o) => '${o['id']}' == '${j['target']}').firstOrNull;
  if (order != null && ['stage', 'live'].contains(order['integrationMode'])) {
    throw const FormatException(
      'Gerçek platform siparişi DEMO işlemiyle değiştirilemez',
    );
  }
  if (j['status'] != 'Bekliyor') {
    throw const FormatException('İstek beklemiyor');
  }
  if (fail) {
    j['status'] = 'Hata';
    j['error'] = '429 · DEMO';
    j['retryAfter'] = DateTime.now().millisecondsSinceEpoch + 10000;
    return;
  }
  try {
    applyPlatformResult(s, j);
    j['status'] = 'Tamamlandı';
    j['completedAt'] = utcNow();
    j['error'] = '';
  } on FormatException catch (e) {
    j['status'] = 'Hata';
    j['error'] = e.message;
  }
}

void applyPlatformResult(Json s, Json j) {
  final p = (j['payload'] as Map).cast<String, dynamic>(),
      src = j['source'] as String;
  final target = j['target'], type = j['type'], cfg = storeConfig(s, src);
  final o = mutableOrder(s, int.tryParse('$target') ?? -1);
  if (['accept', 'ready', 'cancel'].contains(type)) {
    if (o == null ||
        o['source'] != src ||
        o['cancelled'] == true ||
        o['demoRemoteStatus'] != p['expected']) {
      throw const FormatException('409 · Sipariş durumu değişti');
    }
  }
  switch (type) {
    case 'accept':
      if (cfg['acceptFlow'] != 'direct' ||
          o!['demoRemoteStatus'] != 'Created' ||
          p['preparationTime'] is! int ||
          (p['preparationTime'] as int) < 1 ||
          (p['preparationTime'] as int) > 180) {
        throw const FormatException(
          'Vendor App kabulü / hazırlık süresi kontrol edilmeli',
        );
      }
      o['demoRemoteStatus'] = 'Picking';
      o['preparationTime'] = p['preparationTime'];
      queueKitchen(s, o, asMaps(o['batches']).first);
    case 'ready':
      if (o!['demoRemoteStatus'] != 'Picking') {
        throw const FormatException('Önce hazırlanıyor olmalı');
      }
      o['demoRemoteStatus'] = 'Invoiced';
    case 'cancel':
      if (src != 'Trendyol Go' ||
          ![621, 622, 623, 627].contains(p['reasonId'])) {
        throw const FormatException('İptal nedeni geçersiz');
      }
      final selectedIds = (p['itemIds'] as List).cast<String>().toSet();
      final selected = checkLines(
        o!,
      ).where((l) => selectedIds.contains(l.line['packageItemId'])).toList();
      if (selected.isEmpty || selected.length != selectedIds.length) {
        throw const FormatException('409 · İptal ürünü değişti');
      }
      final all = checkLines(o), before = orderTotalCents(o);
      final gross = asMaps(o['batches'])
          .expand((b) => asMaps(b['lines']))
          .where((l) => l['correction'] != true)
          .fold<int>(0, (n, l) => n + cents(l['price']) * (l['qty'] as int));
      final raw = selected.fold<int>(0, (n, l) => n + l.total);
      final refund = selected.length == all.length
          ? before
          : (raw * cents(o['platformSnapshot']['orderTotal']) / gross)
                .round()
                .clamp(0, before)
                .toInt();
      for (final b in (o['batches'] as List).cast<Map>()) {
        for (final l in (b['lines'] as List).cast<Map>()) {
          if (selectedIds.contains(l['packageItemId'])) l['voided'] = true;
        }
      }
      o['platformCancelledAmount'] = fromCents(
        cents(o['platformCancelledAmount']) + refund,
      );
      if (o['platformCollection'] == 'Collected') {
        platformAdjustment(o, -refund, 'Restoran iptali · DEMO');
      }
      final batch = <String, dynamic>{
        'id': (o['batches'] as List).length + 1,
        'staff': 'Platform',
        'time': nowTime(),
        'createdAt': utcNow(),
        'lines': [
          for (final l in selected)
            {
              ...l.line,
              'name': 'İPTAL: ${l.line['name']}',
              'price': 0,
              'correction': true,
              'voided': false,
              'note': 'Neden ${p['reasonId']}',
            },
        ],
      };
      (o['batches'] as List).add(batch);
      queueKitchen(s, o, batch);
      if (selected.length == all.length) {
        o['closed'] = true;
        o['cancelled'] = true;
        o['demoRemoteStatus'] = 'UnSupplied';
      }
    case 'menu-status':
      final m = (platformHub(s)['menu'][src] as List).cast<Map>().firstWhere(
        (m) => m['id'] == target,
      );
      if (!['ACTIVE', 'PASSIVE'].contains(p['status'])) {
        throw const FormatException('Geçersiz ürün durumu');
      }
      m['status'] = p['status'];
    case 'category-status':
      if (!['ACTIVE', 'PASSIVE'].contains(p['status'])) {
        throw const FormatException('Geçersiz kategori durumu');
      }
      for (final m in (platformHub(s)['menu'][src] as List).cast<Map>().where(
        (m) => m['cat'] == target,
      )) {
        m['categoryStatus'] = p['status'];
      }
    case 'price':
      final results = <Json>[];
      final items = asMaps(p['items']);
      for (var i = 0; i < items.length; i++) {
        final row = items[i];
        final m = (platformHub(s)['menu'][src] as List)
            .cast<Map>()
            .where((m) => m['id'] == row['id'])
            .firstOrNull;
        final ok =
            m != null &&
            row['price'] is num &&
            (row['price'] as num).isFinite &&
            cents(row['price']) > 0 &&
            !(p['partial'] == true && i == items.length - 1);
        if (ok) m['price'] = row['price'];
        results.add({
          'id': row['id'],
          'status': ok ? 'SUCCESS' : 'FAILED',
          'failureReasons': ok ? [] : ['DEMO satır reddi'],
        });
      }
      j['results'] = results;
      if (items.isEmpty || results.any((r) => r['status'] == 'FAILED')) {
        throw const FormatException(
          'Kısmi fiyat sonucu; başarısız satırları kontrol edin',
        );
      }
    case 'store':
      cfg['open'] = p['open'] == true;
    case 'hours':
      final hours = asMaps(p['hours']);
      validateHours(hours);
      cfg['hours'] = hours;
    case 'sync':
      cfg['lastSync'] = utcNow();
      cfg['connection'] = 'DEMO · canlı bağlı değil';
    case 'claim':
      final c = findRecord(s, 'claims', target);
      if (c['status'] != 'WaitingInAction' ||
          DateTime.parse('${c['deadline']}').isBefore(DateTime.now()) ||
          '${p['note'] ?? ''}'.trim().isEmpty ||
          !['accept', 'reject'].contains(p['decision'])) {
        throw const FormatException('Talep süresi / yanıt geçersiz');
      }
      final selected = (p['itemIds'] as List).cast<String>().toSet();
      final items = (c['items'] as List).cast<Map>();
      if (selected.isEmpty ||
          items
                  .where(
                    (i) =>
                        selected.contains(i['id']) &&
                        i['status'] == 'WaitingInAction',
                  )
                  .length !=
              selected.length) {
        throw const FormatException('Talep ürün seçimi geçersiz');
      }
      for (final item in items.where((i) => selected.contains(i['id']))) {
        item['status'] = p['decision'] == 'accept' ? 'Accepted' : 'Unresolved';
        item['note'] = p['note'];
      }
      c['status'] = items.any((i) => i['status'] == 'WaitingInAction')
          ? 'WaitingInAction'
          : items.any((i) => i['status'] == 'Unresolved')
          ? 'Unresolved'
          : 'Accepted';
    case 'reply':
      final r = findRecord(s, 'reviews', target);
      if (cfg['migrated'] == true ||
          ['WAITING_FOR_APPROVE', 'APPROVED'].contains(r['replyStatus']) ||
          '${p['text'] ?? ''}'.trim().isEmpty) {
        throw const FormatException('Yorum yanıtı uygun değil');
      }
      r['reply'] = p['text'];
      r['replyStatus'] = 'WAITING_FOR_APPROVE';
    case 'invoice':
      final uri = Uri.tryParse('${p['url']}');
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          o == null ||
          o['source'] != src ||
          o['cancelled'] == true ||
          o['demoRemoteStatus'] == 'Created') {
        throw const FormatException('HTTPS fatura / sipariş geçersiz');
      }
      if (asMaps(platformHub(s)['invoices']).any(
        (i) =>
            '${i['orderId']}' == '$target' && i['status'] != 'Silindi (demo)',
      )) {
        throw const FormatException('Önce mevcut bağlantıyı silin');
      }
      (platformHub(s)['invoices'] as List).add({
        'id': platformId(s, 'INV'),
        'source': src,
        'orderId': o['id'],
        'url': uri.toString(),
        'createdAt': utcNow(),
        'status': 'Gönderildi (demo)',
      });
    case 'invoice-delete':
      findRecord(s, 'invoices', target)['status'] = 'Silindi (demo)';
    default:
      throw const FormatException('Desteklenmeyen simülasyon isteği');
  }
}

void externalPlatformEvent(Json s, int id, String next) {
  final o = mutableOrder(s, id)!;
  if (!isPlatform(o) ||
      !allowedRemote('${o['demoRemoteStatus']}', next) ||
      (next == 'Shipped' && o['platformPickup'] == true)) {
    throw const FormatException('Geçersiz gelen platform olayı');
  }
  final before = orderTotalCents(o);
  o['demoRemoteStatus'] = next;
  o['platformRevision'] = (o['platformRevision'] as int) + 1;
  if (next == 'Picking') queueKitchen(s, o, asMaps(o['batches']).first);
  if (['Delivered', 'Cancelled', 'UnSupplied'].contains(next)) {
    o['closed'] = true;
  }
  if (['Cancelled', 'UnSupplied'].contains(next)) {
    if (o['platformCollection'] == 'Collected' && o['cancelled'] != true) {
      platformAdjustment(o, -before, 'Gelen iptal · DEMO');
    }
    o['cancelled'] = true;
  }
  (o['events'] as List).add(
    '${utcNow()} · Gelen platform olayı (DEMO) · $next',
  );
}

void sampleClaim(Json s, int id, String type) {
  final o = mutableOrder(s, id)!;
  if (o['source'] != 'Trendyol Go' ||
      o['demoRemoteStatus'] != 'Delivered' ||
      o['cancelled'] == true ||
      !['PAY_BACK', 'PRODUCT_RESEND'].contains(type)) {
    throw const FormatException('Teslim edilmiş Trendyol Go siparişi gerekli');
  }
  if (asMaps(platformHub(s)['claims']).any((c) => c['orderId'] == id)) {
    throw const FormatException('Talep zaten var');
  }
  (platformHub(s)['claims'] as List).add({
    'id': platformId(s, 'CLAIM'),
    'source': 'Trendyol Go',
    'orderId': id,
    'packageId': o['platformPackageId'],
    'status': 'WaitingInAction',
    'type': type,
    'createdAt': utcNow(),
    'deadline': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 4))
        .toIso8601String(),
    'reason': 'DEMO · Ürün bildirimi',
    'images': [],
    'items': [
      for (final l in checkLines(o))
        {
          'id': platformId(s, 'ITEM'),
          'packageItemId': l.line['packageItemId'],
          'name': l.line['name'],
          'amount': fromCents(l.total ~/ 2),
          'status': 'WaitingInAction',
        },
    ],
  });
}

void sampleReview(Json s, String source) {
  if (source != 'Trendyol Go' || storeConfig(s, source)['migrated'] == true) {
    throw const FormatException('Yorum erişimi kapalı');
  }
  (platformHub(s)['reviews'] as List).add({
    'id': platformId(s, 'REVIEW'),
    'source': source,
    'orderCode': 'DEMO',
    'score': 4,
    'flavor': 4,
    'service': 5,
    'delivery': 4,
    'text': 'DEMO · Falafel lezzetliydi.',
    'createdAt': utcNow(),
    'replyStatus': 'NONE',
    'reply': '',
  });
}

void sampleSettlement(Json s, int id) {
  final o = mutableOrder(s, id)!;
  if (o['source'] != 'Trendyol Go' ||
      o['demoRemoteStatus'] != 'Delivered' ||
      o['cancelled'] == true ||
      asMaps(platformHub(s)['settlements']).any((r) => r['orderId'] == id)) {
    throw const FormatException('Mutabakat için uygun sipariş yok / zaten var');
  }
  final gross = cents(o['platformSnapshot']['orderTotal']),
      refund = cents(o['platformCancelledAmount']);
  final commission = ((gross - refund) * .15).round();
  (platformHub(s)['settlements'] as List).add({
    'id': platformId(s, 'FIN'),
    'source': o['source'],
    'orderId': id,
    'gross': fromCents(gross),
    'refund': fromCents(refund),
    'commission': fromCents(commission),
    'discount': o['platformSnapshot']['sellerDiscount'] ?? 0,
    'net': fromCents(gross - refund - commission),
    'paymentOrderId': platformId(s, 'PAYMENT'),
    'paymentStatus': 'Eşleşmedi (demo)',
    'stamp': utcNow(),
  });
}
