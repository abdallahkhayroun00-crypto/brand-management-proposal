import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pos_logic.dart';

const floorDefaults = <int, Rect>{
  1: Rect.fromLTWH(.456, .130, .143, .135),
  2: Rect.fromLTWH(.255, .165, .130, .113),
  3: Rect.fromLTWH(.265, .424, .343, .174),
  4: Rect.fromLTWH(.261, .710, .346, .178),
  5: Rect.fromLTWH(.032, .676, .076, .148),
};

Map<int, Rect> positionsFromJson(Object? value) {
  final parsed = <int, Rect>{...floorDefaults};
  if (value is! Map) return parsed;
  for (final number in floorDefaults.keys) {
    final p = value['$number'];
    if (p is Map && p['x'] is num && p['y'] is num) {
      final base = floorDefaults[number]!;
      final x = (p['x'] as num).toDouble();
      final y = (p['y'] as num).toDouble();
      if (x >= 0 && y >= 0 && x + base.width <= 1 &&
          y + base.height <= 1) {
        parsed[number] = Rect.fromLTWH(x, y, base.width, base.height);
      }
    }
  }
  return parsed;
}

Map<String, dynamic> positionsToJson(Map<int, Rect> positions) => {
  for (final entry in positions.entries)
    '${entry.key}': {'x': entry.value.left, 'y': entry.value.top},
};

class RestaurantFloorPlan extends StatelessWidget {
  const RestaurantFloorPlan({
    super.key,
    required this.state,
    required this.onTable,
    required this.positions,
    required this.editing,
    required this.onMove,
    this.selected,
  });
  final Json state;
  final ValueChanged<int> onTable;
  final Map<int, Rect> positions;
  final bool editing;
  final void Function(int table, Offset normalizedDelta) onMove;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final occupied = List.generate(5, (i) => activeTable(state, i + 1))
        .where((o) => o != null).length;
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xfffefefb),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.chair_outlined, color: Color(0xff285940)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Restoran Yerleşimi',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
              _legend('Boş ${5 - occupied}', const Color(0xff85ad91)),
              const SizedBox(width: 12),
              _legend('Dolu $occupied', const Color(0xffdfaf58)),
            ]),
            const SizedBox(height: 10),
            Text(editing
              ? '✥ Sürükle · Yeni konumları kaydet veya iptal et.'
              : 'KAPI ve sandalyelerle gerçek restoran düzeni · 5 masa. Boş masaya dokunarak sipariş aç.',
              style: const TextStyle(color: Color(0xff718275), fontSize: 12)),
            const SizedBox(height: 15),
            LayoutBuilder(builder: (context, constraints) {
              final width = math.max(740.0, constraints.maxWidth);
              final height = width * 640 / 1075;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _FloorPainter(positions))),
                    Positioned(left: width * .137, top: height * .274,
                      child: const Text('KAPI', style: TextStyle(
                        color: Color(0xffbd6b5c), fontSize: 13,
                        letterSpacing: 2, fontWeight: FontWeight.w900))),
                    Positioned(right: 22, top: height * .36,
                      child: const Text('OTURMA ALANI', style: TextStyle(
                        color: Color(0xffa0b5a0), fontSize: 10,
                        letterSpacing: 2, fontWeight: FontWeight.bold))),
                    for (final n in [2, 1, 3, 4, 5])
                      _table(context, n, width, height),
                  ]),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(children: [
    CircleAvatar(radius: 5, backgroundColor: color),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
  ]);

  Widget _table(BuildContext context, int n, double width, double height) {
    final r = positions[n] ?? floorDefaults[n]!;
    final order = activeTable(state, n);
    final busy = order != null;
    final color = busy ? const Color(0xffffe5b2) : const Color(0xffeaf3e7);
    final accent = busy ? const Color(0xffb78643) : const Color(0xff679e7a);
    return Positioned(
      left: r.left * width, top: r.top * height,
      width: r.width * width, height: r.height * height,
      child: GestureDetector(
        onTap: editing ? null : () => onTable(n),
        onPanUpdate: editing ? (details) =>
            onMove(n, Offset(details.delta.dx / width, details.delta.dy / height))
            : null,
        child: Tooltip(
          message: busy
              ? 'Masa $n · Dolu · Kalan ${formatTry(orderDueCents(order))}'
              : 'Masa $n · Boş · Yeni sipariş',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(n == 5 ? 8 : 14),
              border: Border.all(color: selected == n && !editing
                ? const Color(0xff27673f) : accent, width: selected == n ? 3 : 2),
              boxShadow: const [BoxShadow(
                color: Color(0x210c4229), blurRadius: 14, offset: Offset(0, 7))],
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Masa $n', style: TextStyle(
                      color: busy ? const Color(0xff794d20) : const Color(0xff23553a),
                      fontWeight: FontWeight.w900, fontSize: n == 5 ? 13 : 17)),
                    const SizedBox(height: 4),
                    Text(busy ? '● Dolu' : '○ Boş', style: TextStyle(
                      fontSize: n == 5 ? 10 : 12,
                      color: busy ? const Color(0xff8a5c23) : const Color(0xff3c7d56))),
                    if (n != 5) ...[
                      const SizedBox(height: 4),
                      Text(busy ? formatTry(orderDueCents(order)) : 'Yeni Sipariş',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloorPainter extends CustomPainter {
  const _FloorPainter(this.tables);
  final Map<int, Rect> tables;

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xffdf968c)..strokeWidth = 3;
    canvas.drawLine(Offset(0, size.height * .333),
      Offset(size.width * .118, size.height * .333), wall);
    canvas.drawLine(Offset(size.width * .221, size.height * .333),
      Offset(size.width, size.height * .333), wall);
    final chairOuter = Paint()..color = const Color(0xffddb25a);
    final chairInner = Paint()..color = const Color(0xffffe5a2);
    void chair(double x, double y) {
      final p = Offset(size.width * x, size.height * y);
      canvas.drawCircle(p, 10, chairOuter);
      canvas.drawCircle(p, 7, chairInner);
      canvas.drawCircle(p, 3.3, chairOuter);
    }
    for (final n in tables.keys) {
      final r = tables[n]!;
      if (n == 1 || n == 2) {
        chair(r.left - .016, r.center.dy);
        chair(r.right + .016, r.center.dy);
      } else if (n == 5) {
        chair(r.center.dx, r.top - .018);
        chair(r.center.dx, r.bottom + .024);
      } else {
        chair(r.left + r.width * .19, r.top - .018);
        chair(r.left + r.width * .76, r.top - .018);
        chair(r.right + .035, r.center.dy);
        chair(r.left + r.width * .19, r.bottom + .024);
        chair(r.left + r.width * .76, r.bottom + .024);
      }
    }
    final dash = Paint()
      ..color = const Color(0xffdbe4d8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13, 13, size.width - 26, size.height - 26),
        const Radius.circular(13)), dash);
  }

  @override
  bool shouldRepaint(covariant _FloorPainter old) => old.tables != tables;
}
