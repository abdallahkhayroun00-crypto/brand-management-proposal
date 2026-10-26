import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/ticket_document.dart';
import 'package:nohut_falafel_desktop/ticket_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'export the actual app renderer using reference ticket contents',
    () async {
      final output = Directory(
        Platform.environment['NOHUT_PDF_SAMPLE_DIR'] ?? '../output/pdf',
      )..createSync(recursive: true);
      final s = emptyPosState();
      s['nextId'] = 1025;
      final o = newLocalOrder(
        state: s,
        source: 'Masa',
        table: 4,
        productLines: [
          {
            'name': 'Falafel Dürüm',
            'qty': 2,
            'price': 140,
            'note': '1× Soğansız\n1× Acısız\n2× Tahinli sos ekstra',
            'removed': [],
          },
          {
            'name': 'Sade Humus',
            'qty': 1,
            'price': 160,
            'note': '',
            'removed': [],
          },
          {
            'name': 'Büyük Ayran',
            'qty': 1,
            'price': 40,
            'note': '',
            'removed': [],
          },
          {
            'name': 'Doğanay Acılı Şalgam',
            'qty': 1,
            'price': 35,
            'note': '',
            'removed': [],
          },
        ],
      );
      (o['batches'] as List).first['createdAt'] = '2026-10-25T11:05:00Z';
      freezeKitchenTickets(s);
      final initial = kitchenTicket(s, asMaps(s['printJobs']).first);
      addOrderBatch(s, 1025, [
        {
          'name': 'Büyük Ayran',
          'qty': 2,
          'price': 40,
          'note': '',
          'removed': [],
        },
        {
          'name': 'Doğanay Acısız Şalgam',
          'qty': 1,
          'price': 35,
          'note': '',
          'removed': [],
        },
      ]);
      (o['batches'] as List).last['createdAt'] = '2026-10-25T11:22:00Z';
      final additional = kitchenTicket(s, asMaps(s['printJobs']).last);
      recordPayment(o, 20000, 'Nakit', receivedCents: 20000);
      recordPayment(o, 10000, 'Kart');
      final bill = billDocument(o);
      final samples = {
        'Yeni-Siparis-80mm.pdf': initial,
        'Ek-Siparis-80mm.pdf': additional,
        'Hesap-Ozeti-80mm.pdf': bill,
      };
      for (final entry in samples.entries) {
        await File(
          '${output.path}/${entry.key}',
        ).writeAsBytes(await TicketPdf.build(entry.value), flush: true);
      }
      expect(initial.totalCents, 51500);
      expect(additional.totalCents, 11500);
      expect(bill.totalCents, 63000);
      expect(bill.dueCents, 33000);
    },
  );
}
