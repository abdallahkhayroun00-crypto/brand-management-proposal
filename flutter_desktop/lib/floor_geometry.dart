/// Shared normalized restaurant geometry for native PC and staff Chrome.
const floorGeometry = <int, List<double>>{
  1: [.456, .130, .143, .135],
  2: [.255, .165, .130, .113],
  3: [.265, .424, .343, .174],
  4: [.261, .710, .346, .178],
  5: [.032, .676, .076, .148],
};

List<Map<String, dynamic>> sharedFloor(Object? saved) => [
  for (final entry in floorGeometry.entries)
    (() {
      final p = saved is Map ? saved['${entry.key}'] : null;
      final base = entry.value;
      final valid =
          p is Map &&
          p['x'] is num &&
          p['y'] is num &&
          (p['x'] as num) >= 0 &&
          (p['y'] as num) >= 0 &&
          (p['x'] as num) + base[2] <= 1 &&
          (p['y'] as num) + base[3] <= 1;
      return <String, dynamic>{
        'number': entry.key,
        'x': valid ? p['x'] : base[0],
        'y': valid ? p['y'] : base[1],
        'w': base[2],
        'h': base[3],
      };
    })(),
];
