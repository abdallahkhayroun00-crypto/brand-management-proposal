import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/order_actions.dart';
import 'package:nohut_falafel_desktop/product_customization.dart';
import 'package:nohut_falafel_desktop/staff_commands.dart';
import 'package:nohut_falafel_desktop/order_reporting.dart';
import 'updates16_test.dart' show fixture, row;

void main() {
  test('product shares commit atomically and print only the paid share', () {
    final state = fixture();
    final order = newLocalOrder(
      state: state,
      source: 'Masa',
      table: 1,
      productLines: [row()],
    );
    final receipt = recordProductPayment(
      order,
      {'1:0': 7000},
      7000,
      'Karışık',
      cashCents: 3000,
      receivedCents: 5000,
    );
    expect(allocatedTo(order, '1:0'), 7000);
    expect(orderPaidCents(order), 7000);
    expect(asMaps(order['payments']).first['change'], 20);
    expect(receipt, contains('0,5 ×'));
    expect(receipt, contains('Toplam 70,00'));
    final before = copyJson(order);
    expect(
      () => recordProductPayment(order, {'1:0': 28000}, 28000, 'Kart'),
      throwsFormatException,
    );
    expect(order, before);
    expect(
      () => recordProductPayment(
        order,
        {'1:0': 1000},
        1000,
        'Nakit',
        receivedCents: 900,
      ),
      throwsFormatException,
    );
    expect(order, before);
    recordProductPayment(order, {'1:0': 21000}, 21000, 'Kart');
    expect(orderDueCents(order), 0);
    PosStore.validate(state);
  });

  test(
    'manual modifiers conserve base price and quantity; paid/allocated reductions cannot corrupt totals',
    () {
      final s = fixture(), line = row();
      applyLineCustomization(line, 2500, 'Sarma yerine kıymalı sembusek', [
        'Sarma',
      ]);
      validateCashierDraft(s, [line]);
      final o = newLocalOrder(
        state: s,
        source: 'Masa',
        table: 1,
        productLines: [line],
      );
      expect(orderTotalCents(o), 33000);
      expect(line['basePrice'], 140);
      expect(billText(o), contains('Adet farkı: 25,00 ₺'));
      recordPayment(o, 30000, 'Kart');
      expect(
        () => editLocalLine(
          o,
          '1:0',
          2,
          'İndirim',
          [],
          'Ömer',
          adjustmentCents: -1000,
        ),
        throwsFormatException,
      );
      expect(orderTotalCents(o), 33000);
      expect(
        () => applyLineCustomization(row(), -15000, 'İndirim', []),
        throwsFormatException,
      );
      expect(
        () => applyLineCustomization(row(), 2000, '', []),
        throwsFormatException,
      );
    },
  );
  test(
    'mixed payments atomically preserve person allocations, failed combinations write nothing',
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
      splitEqually(o, 2);
      expect(guestBalance(o, 1), 14000);
      recordMixedPayment(o, 14000, 4000, guestId: 1);
      expect(guestBalance(o, 1), 0);
      expect(orderDueCents(o), 14000);
      expect(asMaps(o['payments']).map((p) => p['method']), ['Nakit', 'Kart']);
      final before = copyJson(o);
      expect(
        () => recordMixedPayment(o, 15000, 4000, guestId: 2),
        throwsFormatException,
      );
      expect(o, before);
      recordMixedPayment(o, 14000, 7000, guestId: 2);
      expect(orderDueCents(o), 0);
      PosStore.validate(s);
    },
  );
  test(
    'durable phone split/mixed retry and permanent delete reclaim only last display number',
    () {
      final dir = Directory.systemTemp.createTempSync('nohut-custom-');
      final store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      try {
        store.replace(fixture(), 0);
        Json cmd(String id, String action, Json fields) => {
          'requestId': id,
          'expectedRevision': store.read().revision,
          'staffId': 1,
          'action': action,
          ...fields,
        };
        final create = cmd('create_custom_001', '', {
          'source': 'Masa',
          'table': 1,
          'lines': [
            {
              'productId': 0,
              'qty': 2,
              'note': 'Ek sembusek',
              'removed': [],
              'adjustmentCents': 1000,
            },
          ],
        });
        final result = submitStaffOrder(store, create);
        final id = result['orderId'] as int;
        submitStaffAction(
          store,
          cmd('split_custom_001', 'splitEqual', {'orderId': id, 'count': 2}),
        );
        final pay = cmd('mixed_custom_001', 'payMixed', {
          'orderId': id,
          'amountCents': 15000,
          'cashCents': 5000,
          'guestId': 1,
          'confirmed': true,
          'printReceipt': true,
        });
        submitStaffAction(store, pay);
        submitStaffAction(store, pay);
        expect(
          asMaps(mutableOrder(store.read().data, id)!['payments']),
          hasLength(2),
        );
        expect(store.read().data['printJobs'], hasLength(1));
        expect(
          () => submitStaffAction(
            store,
            cmd('serve_custom_001', 'status', {'orderId': id}),
          ),
          throwsFormatException,
        );
        final beforeNumber = displayOrderNumber(
          mutableOrder(store.read().data, id)!,
        );
        final del = cmd('delete_custom_001', 'delete', {
          'orderId': id,
          'confirmed': true,
        });
        submitStaffAction(store, del);
        submitStaffAction(store, del);
        expect(store.read().data['orders'], isEmpty);
        expect(store.read().data['printJobs'], isEmpty);
        expect(store.read().data['staffNotices'], isEmpty);
        final next = submitStaffOrder(
          store,
          cmd('create_custom_002', '', {
            'source': 'Masa',
            'table': 1,
            'lines': [
              {'productId': 0, 'qty': 1, 'note': '', 'removed': []},
            ],
          }),
        );
        expect(next['orderNumber'], beforeNumber);
        expect(next['orderId'], greaterThan(id));
      } finally {
        store.dispose();
        dir.deleteSync(recursive: true);
      }
    },
  );
  test(
    'per-item allocations support two identical meals and reject duplicate assignment',
    () {
      final o = newLocalOrder(
        state: fixture(),
        source: 'Masa',
        table: 1,
        productLines: [row()],
      );
      addGuest(o, 'Mehmet');
      addGuest(o, 'Bassil');
      allocateProduct(o, 1, '1:0', 14000);
      allocateProduct(o, 2, '1:0', 14000);
      expect(() => allocateProduct(o, 2, '1:0', 28000), throwsFormatException);
      expect(guestBalance(o, 1), 14000);
      expect(guestBalance(o, 2), 14000);
    },
  );
}
