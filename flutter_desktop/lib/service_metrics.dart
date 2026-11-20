import 'package:flutter/material.dart';
import 'brand.dart';
import 'operations.dart';
import 'order_reporting.dart';
import 'pos_logic.dart';

String elapsedService(Json o) {
  final start = DateTime.tryParse('${o['createdAt']}'),
      ready = DateTime.tryParse('${o['readyAt']}'),
      end = DateTime.tryParse('${o['deliveredAt']}');
  String span(DateTime? a, DateTime? b) => a == null || b == null
      ? '—'
      : '${b.difference(a).inMinutes.clamp(0, 99999)} dk';
  return 'Hazırlık: ${span(DateTime.tryParse('${o['serviceStartedAt']}') ?? start, ready ?? (o['serviceStatus'] == 'Hazırlanıyor' ? DateTime.now() : null))} · Teslim: ${span(ready, end ?? (o['serviceStatus'] == 'Hazır' ? DateTime.now() : null))} · Toplam: ${span(start, end ?? DateTime.now())}';
}

class StaffMetrics extends StatelessWidget {
  const StaffMetrics({super.key, required this.state, required this.day});
  final Json state;
  final String day;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Json>>{};
    for (final o in asMaps(state['orders']).where(
      (o) =>
          !isPlatform(o) &&
          o['cancelled'] != true &&
          onIstanbulDay(o['createdAt'], day),
    )) {
      final first = asMaps(o['batches']).firstOrNull;
      final name = '${first?['staff'] ?? 'Kasa (PC)'}';
      groups.putIfAbsent(name, () => []).add(o);
    }
    final additions = <String, int>{};
    for (final order in asMaps(state['orders'])) {
      if (isPlatform(order) || order['cancelled'] == true) continue;
      for (final batch in asMaps(order['batches']).skip(1)) {
        if (!onIstanbulDay(batch['createdAt'], day) ||
            !asMaps(batch['lines']).any(
              (line) => line['correction'] != true && line['voided'] != true,
            )) {
          continue;
        }
        final name = '${batch['staff'] ?? 'Kasa (PC)'}';
        additions.update(name, (count) => count + 1, ifAbsent: () => 1);
        groups.putIfAbsent(name, () => []);
      }
    }
    const columns = ['Sipariş', 'Masa', 'Gel-Al', 'Ek Sipariş', 'Satış'];
    final theme = Theme.of(context);
    final entries = groups.entries.map((entry) {
      final orders = entry.value;
      final tableCount = orders.where((o) => o['source'] == 'Masa').length;
      final pickupCount = orders.where((o) => o['source'] == 'Gel-Al').length;
      final sales = orders.fold<int>(0, (sum, o) => sum + orderTotalCents(o));
      return (
        entry.key,
        [
          '${orders.length}',
          '$tableCount',
          '$pickupCount',
          '${additions[entry.key] ?? 0}',
          formatTry(sales),
        ],
      );
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_outlined, color: NohutBrand.green),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Personel', style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('Bugün henüz personel siparişi yok.'),
            if (entries.isNotEmpty)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 500) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (name, values) in entries) ...[
                          const Divider(height: 16),
                          Text(name, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < columns.length; i++)
                                Text('${columns[i]} ${values[i]}'),
                            ],
                          ),
                        ],
                      ],
                    );
                  }
                  Widget cell(
                    String text, {
                    bool numeric = false,
                    bool header = false,
                    bool strong = false,
                  }) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Text(
                      text,
                      textAlign: numeric ? TextAlign.end : TextAlign.start,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: header ? NohutBrand.green : null,
                        fontWeight: header || strong ? FontWeight.w700 : null,
                      ),
                    ),
                  );
                  return Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      5: FlexColumnWidth(1.5),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: theme.dividerColor),
                    ),
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: Color(0xffe5ebdf),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        children: [
                          cell('Çalışan', header: true),
                          for (final label in columns)
                            cell(label, numeric: true, header: true),
                        ],
                      ),
                      for (final (name, values) in entries)
                        TableRow(
                          children: [
                            cell(name, strong: true),
                            for (var i = 0; i < values.length; i++)
                              cell(
                                values[i],
                                numeric: true,
                                strong: i == values.length - 1,
                              ),
                          ],
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
