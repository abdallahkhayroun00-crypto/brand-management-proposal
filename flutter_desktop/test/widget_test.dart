import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';
import 'package:nohut_falafel_desktop/operations.dart';

void main() {
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
