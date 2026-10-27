import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/order_reporting.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/receipt_printer.dart';

List<Json> productLines() => [
  {
    'productId': 0,
    'name': 'Falafel',
    'productKey': 'Falafel',
    'qty': 1,
    'price': 140.0,
    'removed': [],
    'note': '',
  },
];
void main() {
  test('daily numbering resets at Istanbul midnight, never internal IDs', () {
    final state = <String, dynamic>{
      'orders': [
        {'id': 1200, 'createdAt': '2026-10-27T20:59:59Z'},
        {'id': 1201, 'createdAt': '2026-10-27T21:00:00Z'},
        {'id': 1202, 'createdAt': '2026-10-27T22:00:00Z'},
        {'id': 1203},
      ],
    };
    assignDailyNumbers(state);
    assignDailyNumbers(state);
    final orders = (state['orders'] as List).cast<Map>();
    expect(orders.map((o) => o['dailyNumber']), [1, 1, 2, null]);
    expect(orders.map((o) => o['id']), [1200, 1201, 1202, 1203]);
    expect(orders[1]['numberDay'], '2026-10-28');
  });
  test('hourly workload counts arrivals, not payments or added products', () {
    final orders = <Map>[
      {
        'source': 'Masa',
        'createdAt': '2026-10-27T21:30:00Z',
        'batches': [
          {'staff': 'A'},
          {'staff': 'A'},
        ],
      },
      {'source': 'Gel-Al', 'createdAt': '2026-10-27T20:30:00Z', 'batches': []},
      {
        'source': 'Masa',
        'cancelled': true,
        'createdAt': '2026-10-27T21:40:00Z',
        'batches': [],
      },
      {
        'source': 'Yemeksepeti',
        'demoRemoteStatus': 'Created',
        'createdAt': '2026-10-27T21:40:00Z',
        'batches': [],
      },
    ];
    final counts = hourlyOrderCounts(
      orders,
      from: '2026-10-28',
      to: '2026-10-28',
    );
    expect(counts[0], 1);
    expect(counts.reduce((a, b) => a + b), 1);
    expect(hourlyOrderCounts(orders, source: 'Gel-Al')[23], 1);
  });
  for (final fail in [false, true]) {
    test('one persistent printer job, failure=$fail', () async {
      final dir = Directory.systemTemp.createTempSync('nohut-printer-test-');
      final store = PosStore(databaseFile: '${dir.path}/test.sqlite3');
      var calls = 0;
      final printer = ReceiptPrinter(
        store,
        transport: (text, name) async {
          calls++;
          expect(text, contains('#$calls'));
          expect(name, 'TEST');
          if (fail) throw StateError('Offline');
          if (calls != 1) return;
          final snap = store.read(), s = copyJson(store.read().data);
          newLocalOrder(
            state: s,
            source: 'Gel-Al',
            productLines: productLines(),
          );
          // Simulate another phone committing while the printer is busy.
          store.replace(s, snap.revision);
        },
      );
      try {
        final snap = store.read(), s = copyJson(store.read().data);
        s['settings'] = {'printerName': 'TEST', 'autoPrint': true};
        newLocalOrder(
          state: s,
          source: 'Masa',
          table: 1,
          productLines: productLines(),
        );
        store.replace(s, snap.revision);
        await printer.pump();
        expect(calls, 1);
        final job = (store.read().data['printJobs'] as List).first as Map;
        expect(job['state'], fail ? 'Kontrol gerekli' : 'Kuyruğa gönderildi');
        if (fail) {
          await printer.pump();
          expect(calls, 1);
        } else {
          expect((store.read().data['orders'] as List).length, 2);
          await printer.pump();
          await printer.pump();
          expect(calls, 2);
        }
      } finally {
        printer.dispose();
        store.dispose();
        dir.deleteSync(recursive: true);
      }
    });
  }
  test('crash in flight is held for manual inspection', () {
    final dir = Directory.systemTemp.createTempSync('nohut-recovery-');
    final store = PosStore(databaseFile: '${dir.path}/test.sqlite3');
    final snap = store.read(), s = copyJson(store.read().data);
    newLocalOrder(state: s, source: 'Gel-Al', productLines: productLines());
    ((s['printJobs'] as List).first as Map)['state'] = 'Gönderiliyor';
    store.replace(s, snap.revision);
    final printer = ReceiptPrinter(store, transport: (_, _) async {});
    try {
      printer.start();
      expect(
        ((store.read().data['printJobs'] as List).first as Map)['state'],
        'Kontrol gerekli',
      );
    } finally {
      printer.dispose();
      store.dispose();
      dir.deleteSync(recursive: true);
    }
  });
}
