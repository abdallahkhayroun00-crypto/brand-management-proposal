/// Receipt numbers are daily display numbers. Internal IDs never reset.
String istanbulDay(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 3))
    .toIso8601String()
    .substring(0, 10);

String displayOrderNumber(Map order) =>
    '${order['dailyNumber'] ?? order['id']}';

void assignDailyNumbers(Map<String, dynamic> state) {
  final orders = (state['orders'] as List).cast<Map>();
  final next = <String, int>{};
  for (final o in orders) {
    if (o['dailyNumber'] is int && o['numberDay'] is String) {
      final n = o['dailyNumber'] as int, day = o['numberDay'] as String;
      if (n > (next[day] ?? 0)) next[day] = n;
    }
  }
  // Stored insertion order also handles imports with earlier platform timestamps.
  for (final o in orders) {
    if (o['dailyNumber'] is int && o['numberDay'] is String) continue;
    final stamp = DateTime.tryParse('${o['createdAt']}');
    if (stamp == null) continue; // Do not invent a date for historical records.
    final day = istanbulDay(stamp), number = (next[day] ?? 0) + 1;
    o['numberDay'] = day;
    o['dailyNumber'] = number;
    next[day] = number;
  }
}

/// Order arrivals, not payments or extra batches. Cancelled/unaccepted orders excluded.
List<int> hourlyOrderCounts(
  Iterable<Map> orders, {
  String from = '',
  String to = '',
  String source = 'Tümü',
  String staff = '',
}) {
  final buckets = List<int>.filled(24, 0);
  for (final o in orders) {
    if (o['cancelled'] == true || o['demoRemoteStatus'] == 'Created') continue;
    if (source != 'Tümü' && o['source'] != source) continue;
    final batches = (o['batches'] as List? ?? []).whereType<Map>();
    if (staff.isNotEmpty && !batches.any((b) => '${b['staff']}' == staff)) {
      continue;
    }
    final stamp = DateTime.tryParse('${o['createdAt']}');
    if (stamp == null) continue;
    final day = istanbulDay(stamp);
    if (from.isNotEmpty && day.compareTo(from) < 0 ||
        to.isNotEmpty && day.compareTo(to) > 0) {
      continue;
    }
    buckets[stamp.toUtc().add(const Duration(hours: 3)).hour]++;
  }
  return buckets;
}

String istanbulStamp(Object? value) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return 'Tarih bilinmiyor';
  return parsed
      .toUtc()
      .add(const Duration(hours: 3))
      .toIso8601String()
      .substring(0, 16)
      .replaceAll('T', ' ');
}
