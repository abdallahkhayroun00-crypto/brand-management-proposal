import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/order_actions.dart';
import 'package:nohut_falafel_desktop/staff_commands.dart';
import 'package:nohut_falafel_desktop/receipt_printer.dart';
import 'package:nohut_falafel_desktop/card_terminal.dart';

Json fixture() => {
  ...emptyPosState(),
  'settings': {
    'receiptPolicy': 'onPayment',
    'printerName': 'fake',
    'autoPrint': false,
  },
  'localMenu': [
    {'id': 0, 'name': 'Falafel', 'category': 'wrap', 'price': 140},
  ],
};
Json row() => {
  'productId': 0,
  'name': 'Falafel',
  'price': 140,
  'qty': 2,
  'note': '',
  'removed': <String>[],
};

class FakeGateway implements InposGateway {
  @override
  bool get ready => true;
  int sends = 0, queries = 0;
  TerminalReply reply = const TerminalReply(TerminalStatus.unknown);
  @override
  Future<TerminalReply> pay(String ref, int amount) async {
    sends++;
    return reply;
  }

  @override
  Future<TerminalReply> inquire(String ref) async {
    queries++;
    return reply;
  }
}

void main() {
  late Directory dir;
  late PosStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('nohut16-');
    store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
    store.replace(fixture(), 0);
  });
  tearDown(() {
    store.dispose();
    dir.deleteSync(recursive: true);
  });
  Json command(String id, {String? action, Json fields = const {}}) => {
    'requestId': id,
    'expectedRevision': store.read().revision,
    'staffId': 1,
    if (action != null) 'action': action,
    ...fields,
  };
  test(
    'phone order lifecycle retains ID/history, suppresses kitchen printing and prints only opted-in payment',
    () async {
      final created = submitStaffOrder(
        store,
        command(
          'create_0001',
          fields: {
            'source': 'Masa',
            'table': 1,
            'lines': [
              {'productId': 0, 'qty': 2},
            ],
          },
        ),
      );
      final id = created['orderId'] as int;
      expect(store.read().data['printJobs'], isEmpty);
      submitStaffAction(
        store,
        command(
          'edit_000001',
          action: 'editLine',
          fields: {
            'orderId': id,
            'key': '1:0',
            'qty': 1,
            'note': 'Az sos',
            'removed': ['Domates'],
          },
        ),
      );
      submitStaffAction(
        store,
        command(
          'move_000001',
          action: 'move',
          fields: {'orderId': id, 'table': 4},
        ),
      );
      expect(mutableOrder(store.read().data, id)!['table'], 4);
      submitStaffOrder(
        store,
        command(
          'add_000001',
          fields: {
            'orderId': id,
            'source': 'Masa',
            'table': 4,
            'lines': [
              {'productId': 0, 'qty': 1},
            ],
          },
        ),
      );
      expect(store.read().data['orders'], hasLength(1));
      expect(
        () => submitStaffAction(
          store,
          command('serve_00001', action: 'status', fields: {'orderId': id}),
        ),
        throwsFormatException,
      );
      final pay = command(
        'pay_0000001',
        action: 'pay',
        fields: {
          'orderId': id,
          'amountCents': 28000,
          'method': 'Nakit',
          'receivedCents': 30000,
          'confirmed': true,
          'printReceipt': true,
        },
      );
      submitStaffAction(store, pay);
      submitStaffAction(store, pay);
      final current = store.read().data;
      expect(asMaps(current['printJobs']), hasLength(1));
      expect(asMaps(mutableOrder(current, id)!['payments']), hasLength(1));
      expect(
        asMaps(current['staffNotices']).where((n) => n['id'] == 'pay_0000001'),
        hasLength(1),
      );
      final texts = <String>[];
      final printer = ReceiptPrinter(
        store,
        transport: (text, name) async {
          texts.add(text);
        },
      );
      await printer.pump();
      await printer.pump();
      printer.dispose();
      expect(texts, hasLength(1));
      expect(texts.single, contains('HESAP ÖZETİ'));
      expect(texts.single, contains('280,00'));
      submitStaffAction(
        store,
        command('close_00001', action: 'close', fields: {'orderId': id}),
      );
      expect(mutableOrder(store.read().data, id)!['closed'], true);
      expect(activeTable(store.read().data, 4), isNull);
    },
  );
  test(
    'line deletion and table moves guard money, guest allocations, occupied tables and closed orders',
    () {
      final s = fixture(),
          o = newLocalOrder(
            state: fixture(),
            source: 'Masa',
            table: 1,
            productLines: [row()],
          );
      s['orders'] = [o];
      s['nextId'] = 1201;
      recordPayment(o, 20000, 'Kart');
      expect(
        () => editLocalLine(o, '1:0', 1, '', [], 'Ömer'),
        throwsFormatException,
      );
      expect(o['batches'][0]['lines'][0]['qty'], 2);
      newLocalOrder(state: s, source: 'Masa', table: 2, productLines: [row()]);
      expect(() => moveLocalTable(s, o, 2, 'Ömer'), throwsFormatException);
      expect(o['table'], 1);
      refundPayment(o, 0, 20000, 'Ürün değişti');
      editLocalLine(o, '1:0', 0, 'İptal', [], 'Ömer');
      expect(orderTotalCents(o), 0);
      expect(o['lineEdits'], hasLength(1));
    },
  );
  test(
    'pay without receipt never creates print job; inactive and stale staff mutations cannot write',
    () {
      final s = fixture();
      newLocalOrder(state: s, source: 'Masa', table: 1, productLines: [row()]);
      store.replace(s, store.read().revision);
      final stale = command(
        'stale_00001',
        action: 'status',
        fields: {'orderId': 1200, 'status': 'Hazır'},
      );
      submitStaffAction(
        store,
        command(
          'payment_no1',
          action: 'pay',
          fields: {
            'orderId': 1200,
            'amountCents': 10000,
            'method': 'Kart',
            'confirmed': true,
            'printReceipt': false,
          },
        ),
      );
      expect(store.read().data['printJobs'], isEmpty);
      expect(
        () => submitStaffAction(store, stale),
        throwsA(isA<StaffConflict>()),
      );
      expect(
        () => submitStaffAction(store, {
          ...command('inactive_01', action: 'close', fields: {'orderId': 1200}),
          'staffId': 999,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'inPOS unavailable never charges or records; unknown outcome is queried without a second charge',
    () async {
      final s = fixture();
      newLocalOrder(state: s, source: 'Masa', table: 1, productLines: [row()]);
      store.replace(s, store.read().revision);
      expect(
        (await InposPayments(
          store,
          UnavailableInpos(),
        ).pay(1200, 28000, 'offline_001')).status,
        TerminalStatus.unavailable,
      );
      expect(store.read().data['terminalAttempts'], isNull);
      final gateway = FakeGateway();
      final coordinator = InposPayments(store, gateway);
      await coordinator.pay(1200, 28000, 'device_0001');
      expect(orderPaidCents(mutableOrder(store.read().data, 1200)!), 0);
      expect(
        () => recordPayment(
          mutableOrder(store.read().data, 1200)!,
          28000,
          'Kart',
        ),
        throwsFormatException,
      );
      gateway.reply = const TerminalReply(
        TerminalStatus.approved,
        transactionId: 'bank_tx_1',
        amountCents: 28000,
      );
      await coordinator.pay(1200, 28000, 'device_0001');
      await coordinator.reconcile('device_0001');
      expect(gateway.sends, 1);
      expect(gateway.queries, 2);
      expect(orderPaidCents(mutableOrder(store.read().data, 1200)!), 28000);
      expect(
        asMaps(mutableOrder(store.read().data, 1200)!['payments']),
        hasLength(1),
      );
    },
  );
  test(
    'inPOS decline and cancellation retain unpaid balance; mismatched approval remains unresolved',
    () async {
      final s = fixture();
      newLocalOrder(state: s, source: 'Masa', table: 1, productLines: [row()]);
      store.replace(s, store.read().revision);
      final g = FakeGateway();
      g.reply = const TerminalReply(TerminalStatus.declined);
      final c = InposPayments(store, g);
      await c.pay(1200, 28000, 'decline_001');
      expect(orderPaidCents(mutableOrder(store.read().data, 1200)!), 0);
      expect(mutableOrder(store.read().data, 1200)!['terminalPending'], isNull);
      g.reply = const TerminalReply(
        TerminalStatus.approved,
        transactionId: 'bad',
        amountCents: 1,
      );
      await c.pay(1200, 28000, 'mismatch_01');
      expect(orderPaidCents(mutableOrder(store.read().data, 1200)!), 0);
      expect(
        mutableOrder(store.read().data, 1200)!['terminalPending'],
        'mismatch_01',
      );
    },
  );
}
