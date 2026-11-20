import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/receipt_printer.dart';
import 'package:nohut_falafel_desktop/trendyol_go_readonly.dart';

void main() {
  test('kitchen tickets print once and skip canceled and test orders', () async {
    final dir = Directory.systemTemp.createTempSync('nohut-tgo');
    final store = PosStore(databaseFile: '${dir.path}/db');
    final tickets = <String>[];
    final printer = ReceiptPrinter(store, transport: (text, _) async {
      tickets.add(text);
    });
    addTearDown(() {
      printer.dispose();
      store.dispose();
      dir.deleteSync(recursive: true);
    });
    final state = emptyPosState();
    state['settings'] = {'printerName': 'Test', 'receiptPolicy': 'onPayment'};
    final order = normalizeTgoPackage({
      'id': 'test-id',
      'orderNumber': '101',
      'packageStatus': 'Created',
      'isCourierNearby': true,
      'estimatedPickupTimeMin': 1700000000000,
      'lines': [
        {
          'name': 'Falafel',
          'modifierProducts': [{'name': 'Humus'}],
        },
      ],
      'customerNote': 'Soğansız',
    });
    expect(order['courierNearby'], true);
    expect(order['courierEtaFrom'], '2023-11-14T22:13:20.000Z');
    state['trendyolGoOrders'] = [
      {...order, 'kitchenPrintState': 'Bekliyor'},
      {...order, 'orderNumber': '102', 'status': 'Cancelled', 'kitchenPrintState': 'Bekliyor'},
      {...order, 'orderNumber': '103', 'testPackage': true, 'kitchenPrintState': 'Bekliyor'},
    ];
    expect(store.replace(state, store.read().revision).ok, true);
    for (var attempt = 0; attempt < 4; attempt++) {
      await printer.pump();
    }
    expect(tickets, hasLength(1));
    expect(tickets.single, allOf(contains('101'), contains('Falafel'), contains('Humus'), contains('Soğansız')));
    expect(
      tgoOrders(store.read().data).map((order) => order['kitchenPrintState']),
      ['Kuyruğa gönderildi', 'Atlandı', 'Atlandı'],
    );
  });
}
