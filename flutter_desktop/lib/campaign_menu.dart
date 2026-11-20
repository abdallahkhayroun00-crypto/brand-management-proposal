import 'pos_logic.dart';

String campaignText(Object? value) =>
    value is Map ? (value['tr'] ?? '').toString() : (value ?? '').toString();
int campaignProductId(String id) {
  var hash = 2166136261;
  for (final unit in id.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
  }
  return -100000 - hash;
}

bool campaignAvailable(Map c, DateTime now) {
  if (c['active'] != true ||
      c['id'] is! String ||
      c['price'] is! num ||
      !(c['price'] as num).isFinite ||
      cents(c['price']) < 0)
    return false;
  final start = c['startsAt'] == null
      ? null
      : DateTime.tryParse(c['startsAt'].toString());
  final end = c['endsAt'] == null
      ? null
      : DateTime.tryParse(c['endsAt'].toString());
  if (c['startsAt'] != null && start == null ||
      c['endsAt'] != null && end == null)
    return false;
  return (start == null || !now.isBefore(start)) &&
      (end == null || now.isBefore(end));
}

List<Json> campaignProducts(Json state, {DateTime? now}) {
  final menu = asMaps(state['localMenu']), result = <Json>[], ids = <int>{};
  for (final c in asMaps(state['qrCampaigns'])) {
    if (!campaignAvailable(c, now ?? DateTime.now().toUtc()) ||
        c['items'] is! List)
      continue;
    final title = campaignText(c['title']), components = <Json>[];
    var valid = true;
    for (final item in c['items'] as List) {
      final label = campaignText(item),
          match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(label);
      final count = match == null ? 1 : int.tryParse(match.group(1)!) ?? 0;
      var name = match?.group(2) ?? label;
      // Approved QR artwork uses the small Eker Ayran for this offer.
      if (name == 'Eker Ayran') name = 'Küçük Ayran';
      Json? p = menu.where((p) => p['name'] == name).firstOrNull;
      if (p == null && (c['items'] as List).length == 1)
        p = menu.where((p) => p['name'] == title).firstOrNull;
      if (p == null ||
          p['active'] == false ||
          p['price'] is! num ||
          count < 1 ||
          count > 20 ||
          components.length + count > 50) {
        valid = false;
        break;
      }
      for (var i = 0; i < count; i++)
        components.add({
          'slot': components.length,
          'productId': p['id'],
          'name': p['name'],
          'description': p['description'],
          'price': p['price'],
          'basePrice': p['price'],
          'qty': 1,
          'note': '',
          'removed': <String>[],
          'adjustmentCents': 0,
        });
    }
    if (!valid || components.isEmpty || title.isEmpty) continue;
    final id = campaignProductId(c['id'] as String);
    if (!ids.add(id)) throw const FormatException('Kampanya kimliği çakıştı');
    result.add({
      'id': id,
      'campaignId': c['id'],
      'name': title,
      'category': 'campaign',
      'price': c['price'],
      'active': true,
      'components': components,
      'description': {'tr': (c['items'] as List).map(campaignText).join(' + ')},
      'startsAt': c['startsAt'],
      'endsAt': c['endsAt'],
    });
  }
  return result;
}

List<Json> orderingProducts(Json state) => [
  ...campaignProducts(state),
  ...asMaps(state['localMenu']),
  ...asMaps(state['internalMenu']),
  {
    'id': 2000000000,
    'name': 'Ek Lavaş',
    'category': 'side',
    'price': 10,
    'active': true,
  },
];
int componentExtraCents(Map line) => asMaps(
  line['components'],
).fold<int>(0, (n, c) => n + (c['adjustmentCents'] as int? ?? 0));
List<Json> mergeCampaignComponents(List<Json> baseline, Object? requested) {
  if (requested == null) return baseline.map((c) => copyJson(c)).toList();
  if (requested is! List ||
      requested.length != baseline.length ||
      asMaps(requested).length != baseline.length)
    throw const FormatException('Kampanya içeriği değişti; menüyü yenileyin');
  final rows = asMaps(requested), result = <Json>[];
  for (var i = 0; i < baseline.length; i++) {
    final base = baseline[i], row = rows[i];
    if (row['slot'] != base['slot'] ||
        row['productId'] != base['productId'] ||
        row['qty'] != 1 ||
        row['adjustmentCents'] != null && row['adjustmentCents'] is! int ||
        row['note'] != null && row['note'] is! String ||
        row['removed'] is! List ||
        (row['removed'] as List).any((r) => r is! String || r.length > 100))
      throw const FormatException('Kampanya bileşeni geçersiz');
    final delta = row['adjustmentCents'] as int? ?? 0;
    final note = (row['note'] ?? '').toString(),
        removed = (row['removed'] as List).cast<String>();
    if (note.length > 500 ||
        removed.length > 50 ||
        delta.abs() > 10000000 ||
        cents(base['basePrice'] ?? base['price']) + delta < 0 ||
        delta != 0 && note.trim().isEmpty)
      throw const FormatException('Bileşen farkı / not geçersiz');
    result.add({
      ...base,
      'price': fromCents(cents(base['basePrice'] ?? base['price']) + delta),
      'basePrice': base['basePrice'] ?? base['price'],
      'note': note,
      'removed': removed,
      'adjustmentCents': delta,
      'qty': 1,
    });
  }
  return result;
}

Json prepareCampaignLine(Json state, Json request) {
  final product = campaignProducts(state)
      .where(
        (p) =>
            p['id'] == request['productId'] &&
            (request['campaignId'] == null ||
                request['campaignId'] == p['campaignId']),
      )
      .firstOrNull;
  if (product == null)
    throw const FormatException(
      'Kampanya artık aktif değil veya içeriği satış dışı',
    );
  final components = mergeCampaignComponents(
    asMaps(product['components']),
    request['components'],
  );
  if (request['adjustmentCents'] != null && request['adjustmentCents'] is! int)
    throw const FormatException('Fiyat farkı geçersiz');
  final delta = request['adjustmentCents'] as int? ?? 0;
  if (delta.abs() > 10000000 ||
      delta != 0 && (request['note'] ?? '').toString().trim().isEmpty)
    throw const FormatException('Farkın nedenini not edin');
  final total =
      cents(product['price']) +
      delta +
      componentExtraCents({'components': components});
  if (total < 0)
    throw const FormatException('Kampanya fiyatı sıfırın altına inemez');
  return {
    ...request,
    'productId': product['id'],
    'productKey': product['name'],
    'name': product['name'],
    'campaignId': product['campaignId'],
    'basePrice': product['price'],
    'price': fromCents(total),
    'components': components,
  };
}

String campaignComponentDetails(Map c) => [
  if ((c['removed'] as List? ?? []).isNotEmpty)
    'Çıkar: ' + (c['removed'] as List).join(', '),
  if ((c['note'] ?? '').toString().isNotEmpty) (c['note']).toString(),
  if ((c['adjustmentCents'] as int? ?? 0) != 0)
    formatTry(c['adjustmentCents'] as int),
].join(' · ');
