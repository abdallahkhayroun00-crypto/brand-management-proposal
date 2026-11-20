/// Receipt numbers are daily display numbers. Internal IDs never reset.
String istanbulDay(DateTime instant) => instant
    .toUtc()
    .add(const Duration(hours: 3))
    .toIso8601String()
    .substring(0, 10);

bool validBusinessDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final parsed = DateTime.tryParse(value);
  return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
}

bool validBusinessRange(String from, String to) =>
    (from.isEmpty || validBusinessDate(from)) &&
    (to.isEmpty || validBusinessDate(to)) &&
    (from.isEmpty || to.isEmpty || from.compareTo(to) <= 0);

/// Receipts use 4 digits per Istanbul calendar day (0001, 0002 ...).
/// The immutable SQLite order ID remains independent of this display number.
String displayOrderNumber(Map order) {
  final number = order['dailyNumber'];
  if (number is int && number >= 0) {
    return number.toString().padLeft(4, '0');
  }
  return '${order['id']}';
}

/// UTC instant of the next 00:00 in Türkiye (fixed UTC+03:00).
/// Calculating in UTC avoids dependency on Windows regional time settings.
DateTime nextIstanbulMidnightUtc(DateTime instant) {
  final local = instant.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(
    local.year,
    local.month,
    local.day + 1,
  ).subtract(const Duration(hours: 3));
}

/// Include transactions on the business day in which they actually occurred.
bool onIstanbulDay(Object? rawTimestamp, String day) {
  if (rawTimestamp is! String) return false;
  final stamp = DateTime.tryParse(rawTimestamp);
  return stamp != null && istanbulDay(stamp) == day;
}

/// Reserve one daily display sequence across local and imported platform orders.
/// Existing assigned numbers never change on restart or remote status refresh.
/// New imports use their original Turkish business date but receive numbers in
/// the order they are first stored locally; late API sync cannot reorder tickets.
void assignDailyNumbers(Map<String, dynamic> state) {
  final local = (state['orders'] as List).cast<Map>();
  final remote = state['trendyolGoOrders'] is List
      ? (state['trendyolGoOrders'] as List).whereType<Map>().toList()
      : <Map>[];
  final all = <Map>[...local, ...remote];
  final next = <String, int>{};
  for (final order in all) {
    if (order['dailyNumber'] is int && order['numberDay'] is String) {
      final n = order['dailyNumber'] as int;
      final day = order['numberDay'] as String;
      if (n > (next[day] ?? 0)) next[day] = n;
    }
  }
  for (final order in all) {
    if (order['dailyNumber'] is int && order['numberDay'] is String) continue;
    final created = DateTime.tryParse('${order['createdAt']}');
    if (created == null) continue;
    final day = istanbulDay(created);
    final number = (next[day] ?? 0) + 1;
    order['numberDay'] = day;
    order['dailyNumber'] = number;
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
    if (staff.isNotEmpty &&
        !batches.any(
          (b) => '${b['staff']}'.toLowerCase().contains(staff.toLowerCase()),
        )) {
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
