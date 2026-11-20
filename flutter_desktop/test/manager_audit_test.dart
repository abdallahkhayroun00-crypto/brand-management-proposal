import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';

Future<void> click(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<String> mountManager(WidgetTester t, Json s) async {
  final dir = Directory.systemTemp.createTempSync('nohut-manager-audit-'),
      file = '${dir.path}/db.sqlite3';
  final store = PosStore(databaseFile: file);
  store.replace(s, 0);
  store.dispose();
  t.view.physicalSize = const Size(1440, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    dir.deleteSync(recursive: true);
  });
  await t.pumpWidget(NohutFalafelApp(databaseFile: file, startServer: false));
  await t.pumpAndSettle();
  return file;
}

Json seed() => {
  ...emptyPosState(),
  'settings': {'autoPrint': false, 'qrAutoSync': false},
  'localMenu': [
    {'id': 0, 'name': 'Falafel', 'category': 'wrap', 'price': 140},
  ],
};
void main() {
  for (final hidden in [false, true])
    testWidgets(
      'cashier cart survives ${hidden ? 'withdrawn item' : 'price update'} and refresh is explicit',
      (t) async {
        final file = await mountManager(t, seed());
        await click(t, 'Sipariş Al');
        final falafelCard = find.ancestor(
          of: find.text('Falafel').first,
          matching: find.byType(Card),
        );
        final addFalafel = find.descendant(
          of: falafelCard.first,
          matching: find.text('Ekle'),
        );
        await t.ensureVisible(addFalafel);
        await t.tap(addFalafel);
        await t.pumpAndSettle();
        await t.tap(find.byType(DropdownButtonFormField<int>));
        await t.pumpAndSettle();
        await t.tap(find.textContaining('Masa 1').last);
        await t.pumpAndSettle();
        final other = PosStore(databaseFile: file);
        final snap = other.read(), next = copyJson(snap.data);
        final p = (next['localMenu'] as List).first as Map;
        p[hidden ? 'active' : 'price'] = hidden ? false : 150;
        other.replace(next, snap.revision);
        await click(t, 'Siparişi Kaydet');
        expect(find.text('Sipariş Sepeti'), findsOneWidget);
        expect(other.read().data['orders'], isEmpty);
        await click(t, 'Güncel Menü ve Masaları Al');
        if (hidden) {
          expect(
            find.textContaining('Satış dışı, satırı kaldırın'),
            findsOneWidget,
          );
          expect(
            t
                .widget<FilledButton>(
                  find.ancestor(
                    of: find.text('Siparişi Kaydet'),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          await t.tap(find.byTooltip('Satırı kaldır'));
          await t.pumpAndSettle();
          expect(find.text('Sepet boş'), findsOneWidget);
        } else {
          await click(t, 'Siparişi Kaydet');
          final order = asMaps(other.read().data['orders']).single;
          expect(orderTotalCents(order), 15000);
        }
        other.dispose();
        expect(t.takeException(), isNull);
      },
    );
  testWidgets(
    'old pickup debt opens its filtered order and historical refunds stay out of debt list',
    (t) async {
      final s = seed(),
          line = {
            'productId': 0,
            'name': 'Falafel',
            'price': 140,
            'qty': 1,
            'removed': <String>[],
            'note': '',
          };
      final old = newLocalOrder(
        state: s,
        source: 'Gel-Al',
        productLines: [line],
      );
      old['numberDay'] = '2026-01-01';
      old['createdAt'] = '2026-01-01T10:00:00Z';
      final closed = newLocalOrder(
        state: s,
        source: 'Masa',
        table: 1,
        productLines: [line],
      );
      recordPayment(closed, 14000, 'Kart');
      closeLocalTable(closed);
      refundPayment(closed, 0, 14000, 'Geçmiş iade');
      await mountManager(t, s);
      await click(t, 'Kasa & Ödemeler');
      expect(find.text('Kalan 140,00 ₺'), findsOneWidget);
      await click(t, 'Kalan 140,00 ₺');
      expect(find.text('Nakit / Kart'), findsOneWidget);
      expect(find.textContaining('Falafel'), findsWidgets);
      expect(t.takeException(), isNull);
    },
  );
}
