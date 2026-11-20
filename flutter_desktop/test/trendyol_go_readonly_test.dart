import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/trendyol_go_readonly.dart';

void main() {
  final payload = <String, dynamic>{
    'id': 5000,
    'orderNumber': 'TG-101',
    'supplierId': 12345,
    'storeId': 456,
    'packageStatus': 'Picking',
    'packageCreationDate': 1763503200000,
    'packageModificationDate': 1763503260000,
    'totalPrice': 355.50,
    'customerNote': 'Sos ayrı olsun',
    'payment': {'paymentType': 'ONLINE'},
    'lines': [
      {
        'name': 'Falafel Dürüm',
        'unitSellingPrice': 160.00,
        'items': [
          {'isCancelled': false},
          {'isCancelled': false},
        ],
        'modifierProducts': [
          {'name': 'Ekstra humus'},
        ],
      },
    ],
  };

  test(
    'Platform price and total remain authoritative, not shop-menu price',
    () {
      final o = normalizeTgoPackage(payload);
      expect(o['source'], 'Trendyol Go');
      expect(o['totalCents'], 35550);
      expect(o['customerNote'], 'Sos ayrı olsun');
      final lines = o['lines'] as List;
      expect(lines.single['unitPriceCents'], 16000);
      expect(lines.single['qty'], 2);
      expect((lines.single['options'] as List).single, 'Ekstra humus');
    },
  );

  test('Cancelled or test orders are not counted as sales', () {
    final order = normalizeTgoPackage(payload);
    expect(tgoCountsAsSale(order), false); // Picking is not a completed sale.
    expect(tgoCountsAsSale({...order, 'status': 'Delivered'}), true);
    expect(tgoCountsAsSale({...order, 'status': 'Cancelled'}), false);
    expect(tgoCountsAsSale({...order, 'testPackage': true}), false);
  });

  test('Rejects packages without a stable external identifier', () {
    expect(
      () => normalizeTgoPackage({...payload, 'id': null}),
      throwsFormatException,
    );
  });
}
