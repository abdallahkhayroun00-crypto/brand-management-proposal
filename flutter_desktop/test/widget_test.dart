import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';
import 'package:nohut_falafel_desktop/operations.dart';

void main() {
  testWidgets(
    'PC categorized product cards preserve basket across filters and save quantities to chosen table',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync('nohut-composer-'),
          file = '${folder.path}/pos.sqlite3';
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        folder.deleteSync(recursive: true);
      });
      final seed = PosStore(databaseFile: file), s = seed.read().data;
      s['localMenu'] = [
        {'id': 0, 'name': 'Falafel Dürüm', 'category': 'wrap', 'price': 140},
        {
          'id': 1,
          'name': 'Falafel Porsiyon',
          'category': 'plate',
          'price': 200,
        },
        {'id': 2, 'name': 'Ayran', 'category': 'drink', 'price': 30},
      ];
      seed.replace(s, 0);
      seed.dispose();
      await tester.pumpWidget(
        NohutFalafelApp(databaseFile: file, startServer: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Sipariş Al'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('product-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('select-table-2')));
      await tester.tap(find.byKey(const ValueKey('product-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('category-drink')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('product-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('basket-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('basket-2')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('catalog-search')),
        'Porsiyon',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('category-wrap')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('catalog-search')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byTooltip('Falafel Dürüm artır'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('save-order')));
      await tester.pumpAndSettle();
      final saved = PosStore(databaseFile: file),
          order = asMaps(saved.read().data['orders']).single;
      expect(order['table'], 2);
      expect(orderTotalCents(order), 31000);
      expect(
        checkLines(order).fold<int>(0, (n, l) => n + (l.line['qty'] as int)),
        3,
      );
      saved.dispose();
    },
  );
  for (final size in [const Size(1600, 900), const Size(1280, 720)]) {
    testWidgets(
      'manager and workflow navigation at ${size.width} without role chooser',
      (tester) async {
        final folder = Directory.systemTemp.createTempSync('nohut-widget-'),
            file = '${folder.path}/pos.sqlite3';
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          folder.deleteSync(recursive: true);
        });
        final store = PosStore(databaseFile: file), s = emptyPosState();
        final o = newLocalOrder(
          state: s,
          source: 'Masa',
          table: 3,
          productLines: [
            {
              'name': 'Falafel',
              'productId': 0,
              'price': 100.01,
              'qty': 2,
              'removed': [],
              'note': 'Sos ayrı',
            },
          ],
        );
        addGuest(o, 'Ali');
        allocateProduct(o, 1, '1:0', 10001);
        recordPayment(o, 10001, 'Kart', guestId: 1);
        s['localMenu'] = [
          {'id': 0, 'name': 'Falafel', 'category': 'wrap', 'price': 100.01},
        ];
        seedPlatformMenu(s, asMaps(s['localMenu']));
        final remote = importPlatform(
          s,
          platformFixture(s, 'Trendyol Go', 'card'),
        )!;
        externalPlatformEvent(s, remote['id'] as int, 'Delivered');
        sampleClaim(s, remote['id'] as int, 'PAY_BACK');
        sampleReview(s, 'Trendyol Go');
        queuePlatform(s, 'sync', 'Trendyol Go', 'Trendyol Go', {});
        openCash(s, 50000);
        store.replace(s, 0);
        store.dispose();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          NohutFalafelApp(databaseFile: file, startServer: false),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Initial dashboard');
        expect(find.text('Genel Bakış'), findsWidgets);
        expect(find.byType(MaterialApp), findsOneWidget);
        for (final label in [
          'Masalar',
          'Tüm Siparişler',
          'Kasa & Ödemeler',
          'Yazdırma Kuyruğu',
          'Personel & QR',
          'Raporlar',
          'Ayarlar',
          'Online Siparişler',
        ]) {
          await tester.ensureVisible(find.text(label).first);
          await tester.tap(find.text(label).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          expect(find.text(label), findsAtLeastNWidgets(2));
          if (label == 'Personel & QR') {
            expect(find.text('Personel Wi-Fi'), findsNothing);
            expect(
              tester.getRect(find.text('Telefon Bağla · QR Oluştur')).bottom,
              lessThan(size.height),
            );
            expect(find.text('Telefon Bağlantıları'), findsOneWidget);
          }
        }
        for (final tab in [
          'Mağaza',
          'Menü',
          'İade Talepleri',
          'Değerlendirmeler',
          'Faturalar',
          'Senkronizasyon',
          'Siparişler',
        ]) {
          await tester.tap(find.text(tab).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: tab);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
