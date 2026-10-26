import 'package:flutter/material.dart';
import 'operations.dart';
import 'pos_logic.dart';

class DashboardInsights extends StatelessWidget {
  const DashboardInsights({
    super.key,
    required this.state,
    required this.onSource,
    required this.onReport,
  });
  final Json state;
  final ValueChanged<String> onSource;
  final VoidCallback onReport;
  Widget panel(Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
  @override
  Widget build(BuildContext context) {
    final orders = asMaps(state['orders']);
    final receipts = ledger(
      state,
    ).where((r) => ['Masa', 'Gel-Al'].contains(r.source));
    int paid(String method) => receipts
        .where((r) => r.method == method)
        .fold(0, (sum, r) => sum + r.amount);
    final cash = paid('Nakit'), card = paid('Kart'), total = cash + card;
    final sources = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sipariş Kaynakları',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tüm kayıtlar · Bir kaynağa dokunarak siparişlerini açın.',
            style: TextStyle(color: Color(0xff7c8b80), fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final source in ['Masa', 'Gel-Al', 'Trendyol Go', 'Yemeksepeti'])
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSource(source),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        source,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: orders.isEmpty
                              ? 0
                              : orders
                                        .where((o) => o['source'] == source)
                                        .length /
                                    orders.length,
                        ),
                        duration: const Duration(milliseconds: 280),
                        builder: (_, value, child) => ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 9,
                            backgroundColor: const Color(0xffedf2ee),
                            color: source == 'Trendyol Go'
                                ? const Color(0xffedb563)
                                : const Color(0xff89ad91),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${orders.where((o) => o['source'] == source).length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      size: 17,
                      color: Color(0xff93a398),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    final payments = panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Yerel Ödemeler',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tüm kayıtlar · İadeler düşülmüş tahsilat. Platform ödemeleri hariç.',
            style: TextStyle(color: Color(0xff7c8b80), fontSize: 12),
          ),
          const SizedBox(height: 20),
          for (final entry in [
            ('Nakit', cash, Icons.payments_outlined),
            ('Kart', card, Icons.credit_card_rounded),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xffecf5e9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(entry.$3, color: const Color(0xff183b2c)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.$1,
                          style: const TextStyle(
                            color: Color(0xff7c8b80),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatTry(entry.$2),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    total > 0 ? '%${(entry.$2 / total * 100).round()}' : '%0',
                    style: const TextStyle(
                      color: Color(0xff7c8b80),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: onReport,
            icon: const Icon(Icons.bar_chart_rounded, size: 18),
            label: const Text('Detaylı Raporları Aç'),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= 850
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sources),
                const SizedBox(width: 16),
                Expanded(child: payments),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [sources, const SizedBox(height: 16), payments],
            ),
    );
  }
}
