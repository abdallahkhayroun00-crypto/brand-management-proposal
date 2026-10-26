import 'package:flutter/material.dart';
import 'ticket_document.dart';
import 'pos_logic.dart';
import 'workspace_ui.dart';

class TicketPaper extends StatelessWidget {
  const TicketPaper({super.key, required this.document});
  final TicketDocument document;
  @override
  Widget build(BuildContext context) {
    final d = document;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 350,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe4e9e3)),
          boxShadow: const [
            BoxShadow(color: Color(0x0c183b2c), blurRadius: 20),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'NotoSans',
            fontSize: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/nohut-wordmark.png',
                width: 210,
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                d.heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Divider(color: Colors.black, thickness: 2, height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      d.destination,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        d.reference,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        istanbulTime(d.stamp).replaceAll(' · ', ' '),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              if (d.externalCode.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Platform Sipariş: ${d.externalCode}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              const Divider(color: Colors.black, height: 32),
              for (final l in d.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 25,
                        child: Text(
                          '${l.quantity}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            for (final r in l.removed)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Çıkar: $r',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            if (l.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  l.note,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (d.kind != TicketKind.correction)
                        Text(
                          formatTry(l.amountCents),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              const Divider(color: Colors.black),
              Text('Toplam Ürün: ${d.quantity}'),
              const Divider(color: Colors.black, height: 28),
              if (d.kind == TicketKind.bill &&
                  d.lineSubtotalCents != d.totalCents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Ürün toplamı: ${formatTry(d.lineSubtotalCents)}\nPlatform tutar farkı: ${formatTry(d.totalCents - d.lineSubtotalCents)}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              if (d.kind != TicketKind.correction)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.totalLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      formatTry(d.totalCents),
                      style: TextStyle(
                        fontSize: d.platformTotalCents == null ? 20 : 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              if (d.platformTotalCents != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (d.kind == TicketKind.newOrder &&
                          d.platformTotalCents != d.totalCents)
                        Text(
                          'Platform tutar farkı: ${formatTry(d.platformTotalCents! - d.totalCents)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'PLATFORM SİPARİŞ TOPLAMI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            formatTry(d.platformTotalCents!),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tahsilat / kurye platforma aittir.',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              if (d.kind == TicketKind.bill) ...[
                const SizedBox(height: 12),
                Text(
                  'Alınan: ${formatTry(d.paidCents)}\nKalan: ${formatTry(d.dueCents)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final p in d.payments)
                  Text(p, style: const TextStyle(fontSize: 11)),
              ],
              const Divider(color: Colors.black, height: 30),
              const Text(
                'Afiyet Olsun',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const Text('Nohut Falafel', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Text(
                d.legal,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
