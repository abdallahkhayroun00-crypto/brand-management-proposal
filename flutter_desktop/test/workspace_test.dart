import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/order_workspace.dart';
import 'package:nohut_falafel_desktop/printer_workspace.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/operations.dart';

void main() {
  testWidgets(
    'narrow order panel assigns a product to a guest and refunds a receipt',
    (tester) async {
      tester.view.physicalSize = const Size(420, 650);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = emptyPosState();
      final order = newLocalOrder(
        state: state,
        source: 'Masa',
        table: 3,
        productLines: [
          {
            'name': 'Falafel',
            'productId': 0,
            'price': 100.01,
            'qty': 2,
            'removed': [],
            'note': '',
          },
        ],
      );
      addGuest(order, 'Ali');
      int? payingGuest;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => OrderWorkspace(
                order: order,
                edit: (change) {
                  refresh(() => change(state));
                  return true;
                },
                onAdd: () {},
                onPay: () {},
                onClose: () {},
                onGuestPay: (guest) => payingGuest = guest['id'] as int,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('order-payment'))).bottom,
        lessThan(650),
      );
      expect(find.text('Falafel'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('detail-tab-Hesap Böl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('guest-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('check-line-1:0')));
      await tester.tap(find.byKey(const ValueKey('check-line-1:0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('assign-product')));
      await tester.tap(find.byKey(const ValueKey('assign-product')));
      await tester.pumpAndSettle();
      expect(guestBalance(order, 1), 20002);
      await tester.ensureVisible(find.text('Kişi Ödemesi'));
      await tester.tap(find.text('Kişi Ödemesi'));
      expect(payingGuest, 1);
      recordPayment(order, 10001, 'Kart', guestId: 1);
      await tester.tap(find.byKey(const ValueKey('detail-tab-Tahsilatlar')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kısmi / Tam İade'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '25.01');
      await tester.enterText(find.byType(TextField).at(1), 'Müşteri iadesi');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(orderPaidCents(order), 7500);
      expect(guestBalance(order, 1), 12502);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'printer selection previews the batch, filters errors and prevents completed replay',
    (tester) async {
      tester.view.physicalSize = const Size(960, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = emptyPosState();
      newLocalOrder(
        state: state,
        source: 'Gel-Al',
        productLines: [
          {
            'name': 'Ayran',
            'productId': 0,
            'price': 30,
            'qty': 2,
            'removed': [],
            'note': '',
          },
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => PrinterWorkspace(
                state: state,
                edit: (change) {
                  refresh(() => change(state));
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        contains('Ayran'),
      );
      await tester.tap(find.text('Demo Test Araçları'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hata Simülasyonu'));
      await tester.pumpAndSettle();
      expect(asMaps(state['printJobs']).single['state'], 'Hata');
      await tester.tap(find.text('Hata · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Test Araçları'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tekrar Dene · Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamamlanan · 1'));
      await tester.pumpAndSettle();
      expect(asMaps(state['printJobs']).single['attempts'], 2);
      expect(find.text('Demo Test Araçları'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
