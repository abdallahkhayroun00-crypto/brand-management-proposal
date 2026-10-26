import 'dart:math' as math;
import 'package:flutter/material.dart';

const pine = Color(0xff183b2c), muted = Color(0xff748477);

String istanbulTime(Object? value, {bool dateOnly = false}) {
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '—';
  final d = parsed.toUtc().add(const Duration(hours: 3));
  String two(int n) => '$n'.padLeft(2, '0');
  final date = '${two(d.day)}.${two(d.month)}.${d.year}';
  return dateOnly ? date : '$date · ${two(d.hour)}:${two(d.minute)}';
}

class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.child, this.padding = 18});
  final Widget child;
  final double padding;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: EdgeInsets.all(padding), child: child),
  );
}

class WorkTabs extends StatelessWidget {
  const WorkTabs({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final value in values)
        ChoiceChip(
          key: ValueKey('work-tab-$value'),
          showCheckmark: false,
          selected: value == selected,
          selectedColor: pine,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: value == selected ? Colors.white : pine,
          ),
          label: Text(value),
          onSelected: (_) => onChanged(value),
        ),
    ],
  );
}

class WorkMetric extends StatelessWidget {
  const WorkMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.selected = false,
  });
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: selected ? const Color(0xffe4efdf) : Colors.white,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: pine),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.arrow_outward, size: 14, color: muted),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: pine,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkEmpty extends StatelessWidget {
  const WorkEmpty({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.search_off,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: const Color(0xff9aaf9f)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class WorkTable extends StatelessWidget {
  const WorkTable({
    super.key,
    required this.headings,
    required this.rows,
    this.onRow,
    this.empty = 'Bu filtrede kayıt yok.',
  });
  final List<String> headings;
  final List<List<String>> rows;
  final ValueChanged<int>? onRow;
  final String empty;
  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? WorkEmpty(
          title: empty,
          message: 'Tarih ve kaynak filtrelerini kontrol edin.',
        )
      : LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(c.maxWidth, headings.length * 145.0),
              height: c.maxHeight,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xfff3f6ef),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final h in headings)
                          Expanded(
                            child: Text(
                              h,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) => Material(
                        color: i.isEven
                            ? Colors.white
                            : const Color(0xfffafbf8),
                        child: InkWell(
                          key: ValueKey('report-row-$i'),
                          onTap: onRow == null ? null : () => onRow!(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xffedf0e9)),
                              ),
                            ),
                            child: Row(
                              children: [
                                for (final value in rows[i])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        value,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                if (onRow != null)
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: muted,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
}

Widget workHeading(String title, String subtitle, {Widget? action}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: pine,
              ),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
      ?action,
    ],
  ),
);
