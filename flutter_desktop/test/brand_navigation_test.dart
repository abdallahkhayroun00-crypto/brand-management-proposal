import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/brand.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/order_reporting.dart';

void main() {
  testWidgets(
    'seven branded destinations include separate orders and reviews',
    (t) async {
      final dir = Directory.systemTemp.createTempSync('nohut-brand-');
      final file = '${dir.path}/db';
      final db = PosStore(databaseFile: file);
      final state = emptyPosState();
      state['settings'] = {'qrAutoSync': false, 'autoPrint': false};
      final today = DateTime.now().toUtc();
      final yesterday = today.subtract(const Duration(days: 1));
      state['trendyolGoOrders'] = [
        {
          'source': 'Trendyol Go',
          'orderNumber': 'PLATFORM-99',
          'createdAt': today.toIso8601String(),
          'status': 'Delivered',
          'paymentType': 'PAY_WITH_CARD',
          'totalCents': 80000,
          'lines': [{'qty': 2, 'name': 'Vegan Özel Tabağı'}],
        },
        {
          'source': 'Trendyol Go',
          'orderNumber': 'PLATFORM-98',
          'createdAt': yesterday.toIso8601String(),
          'status': 'Delivered',
          'totalCents': 4500,
          'lines': [{'qty': 1, 'name': 'Çay'}],
        },
      ];
      db.replace(state, db.read().revision);
      db.dispose();
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(() async {
        await t.pumpWidget(const SizedBox.shrink());
        t.view.resetPhysicalSize();
        t.view.resetDevicePixelRatio();
        dir.deleteSync(recursive: true);
      });
      await t.runAsync(() async {
        final body = FontLoader(NohutBrand.bodyFont)
          ..addFont(rootBundle.load('assets/brand/fonts/Barlow-Regular.ttf'))
          ..addFont(rootBundle.load('assets/brand/fonts/Barlow-Bold.ttf'));
        final heading = FontLoader(
          NohutBrand.headingFont,
        )..addFont(rootBundle.load('assets/brand/fonts/BreeSerif-Regular.ttf'));
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await Future.wait([body.load(), heading.load(), icons.load()]);
      });
      await t.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('brand-capture'),
          child: NohutFalafelApp(databaseFile: file, startServer: false),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('navigation-'),
        ),
        findsNWidgets(7),
      );
      expect(find.text('Personel Yönetimi'), findsNothing);
      expect(find.text('Online Siparişler'), findsOneWidget);
      await t.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/nohut-logo.webp'),
          t.element(find.byType(NohutFalafelApp)),
        ),
      );
      await t.pumpAndSettle();
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('brand-capture')),
      );
      await t.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final proof = File('build/desktop-brand-proof.png');
        proof.parent.createSync(recursive: true);
        proof.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.tap(find.byKey(const ValueKey('navigation-online')));
      await t.pumpAndSettle();
      expect(find.text('Uber Eats'), findsNothing);
      expect(find.text('Yemeksepeti'), findsOneWidget);
      expect(find.text('Değerlendirmeleri Getir'), findsNothing);
      expect(find.text('Teslim Edildi'), findsOneWidget);
      expect(find.text(istanbulStamp(today.toIso8601String())), findsOneWidget);
      expect(find.text('Platform no: PLATFORM-98'), findsNothing);
      await t.tap(find.text('Geçmiş'));
      await t.pumpAndSettle();
      expect(find.text('Platform no: PLATFORM-98'), findsOneWidget);
      expect(find.text('Platform no: PLATFORM-99'), findsNothing);
      await t.enterText(
        find.widgetWithText(TextField, 'Sipariş No / Kod'),
        'no-match',
      );
      await t.pumpAndSettle();
      expect(find.text('Platform no: PLATFORM-98'), findsNothing);
      await t.enterText(
        find.widgetWithText(TextField, 'Sipariş No / Kod'),
        'PLATFORM-98',
      );
      await t.pumpAndSettle();
      expect(find.text('Platform no: PLATFORM-98'), findsOneWidget);
      await t.tap(find.text('Bugüne Dön'));
      await t.pumpAndSettle();
      expect(find.text('Platform no: PLATFORM-99'), findsOneWidget);
      expect(find.text('Platform no: PLATFORM-98'), findsNothing);
      expect(find.text('PAY_WITH_CARD'), findsNothing);
      await t.tap(find.text('Migros Yemek'));
      await t.pumpAndSettle();
      expect(find.text('Migros Yemek · Bağlı değil'), findsOneWidget);
      expect(find.text('Migros Restoran Panelini Aç'), findsOneWidget);
      expect(find.text('Platform no: PLATFORM-99'), findsNothing);
      await t.tap(find.byKey(const ValueKey('navigation-reviews')));
      await t.pumpAndSettle();
      expect(find.text('Değerlendirmeleri Getir'), findsOneWidget);
      expect(find.text('Şube ID (Store ID)'), findsOneWidget);
      await t.tap(find.text('Google Maps'));
      await t.pumpAndSettle();
      expect(find.text('Google Maps’te Aç'), findsOneWidget);
      expect(find.text('Değerlendirmeleri Getir'), findsNothing);
      await t.tap(find.text('Yemeksepeti'));
      await t.pumpAndSettle();
      expect(find.text('Partner Panelini Aç'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('navigation-settings')));
      await t.pumpAndSettle();
      for (final tab in ['Personel', 'Bağlantı', 'Yazıcı']) {
        await t.tap(find.text(tab).first);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      expect(find.text('Windows · Fiş görseli'), findsOneWidget);
      expect(find.text('Hizalama Testi Yazdır'), findsOneWidget);
    },
  );
}
