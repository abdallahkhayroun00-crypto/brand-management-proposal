import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';

void main() {
  test('five tables, order IDs, pickup-only phone and batch printing', () {
    final db = emptyPosState();
    final first = newLocalOrder(state: db, source: 'Masa', table: 3,
      productLines: [{
        'productId': 0, 'productKey': 'Falafel Dürüm',
        'name': 'Falafel Dürüm', 'price': 140.0, 'qty': 2,
        'removed': [], 'note': ''
      }]);
    expect(first['id'], 1200);
    expect(activeTable(db, 3)?['id'], 1200);
    expect(orderTotalCents(first), 28000);
    expect(orderDueCents(first), 28000);
    addOrderBatch(db, 1200, [{
      'productId': 35, 'productKey': 'Büyük Ayran',
      'name': 'Büyük Ayran', 'price': 40.0, 'qty': 1,
      'removed': [], 'note': ''
    }]);
    final updated = mutableOrder(db, 1200)!;
    expect((updated['batches'] as List).length, 2);
    expect(orderTotalCents(updated), 32000);
    expect((db['printJobs'] as List).length, 2);
    expect(() => newLocalOrder(state: db, source: 'Masa', table: 6,
      productLines: [{'price': 140.0, 'qty': 1}]), throwsFormatException);
    expect(() => newLocalOrder(state: db, source: 'Kurye',
      productLines: [{'price': 140.0, 'qty': 1}]), throwsFormatException);

    final pickup = newLocalOrder(state: db, source: 'Gel-Al',
      pickupChannel: 'Telefon', productLines: [{
        'productId': 0, 'productKey': 'Falafel Dürüm',
        'name': 'Falafel Dürüm', 'price': 140.0, 'qty': 1,
        'removed': [], 'note': ''
      }]);
    expect(pickup['pickupChannel'], 'Telefon');
    expect(pickup['table'], null);
  });

  test('partial payment and cash change, table remains until closed', () {
    final db = emptyPosState();
    final order = newLocalOrder(state: db, source: 'Masa', table: 1,
      productLines: [{
        'productId': 0, 'productKey': 'Falafel Dürüm',
        'name': 'Falafel Dürüm', 'price': 140.0, 'qty': 2,
        'removed': [], 'note': ''
      }]);
    recordPayment(order, 14000, 'Nakit', receivedCents: 15000);
    expect((order['payments'] as List).last['change'], 10.0);
    expect(orderDueCents(order), 14000);
    expect(() => closeLocalTable(order), throwsFormatException);
    recordPayment(order, 14000, 'Kart');
    expect(orderDueCents(order), 0);
    closeLocalTable(order);
    expect(activeTable(db, 1), null);
    expect(() => recordPayment(order, 100, 'Nakit', receivedCents: 100),
      throwsFormatException);
  });

  test('SQLite optimistic revisions reject stale updates and persist', () {
    final folder = Directory.systemTemp.createTempSync('nohut-flutter-test-');
    final file = '${folder.path}${Platform.pathSeparator}pos.sqlite3';
    try {
      final store = PosStore(databaseFile: file);
      final a = store.read(), b = store.read();
      expect(a.revision, 0);
      expect(a.data['orders'], isEmpty);
      final next = copyJson(a.data);
      newLocalOrder(state: next, source: 'Gel-Al',
        productLines: [{
          'productId': 0, 'productKey': 'Falafel Dürüm',
          'name': 'Falafel Dürüm', 'price': 140.0, 'qty': 1,
          'removed': [], 'note': ''
        }]);
      expect(store.replace(next, a.revision).ok, true);
      expect(store.replace(b.data, b.revision).ok, false);
      expect(store.read().revision, 1);
      store.dispose();
      final reopened = PosStore(databaseFile: file);
      expect(reopened.read().data['orders'], hasLength(1));
      expect(reopened.read().revision, 1);
      reopened.dispose();
    } finally {
      try { folder.deleteSync(recursive: true); } catch (_) {}
    }
  });
}
