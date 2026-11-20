import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/floor_plan.dart';

void main() {
  setUpAll(() async {
    if (Platform.environment['NOHUT_UI_PREVIEW'] != null) {
      for (final entry in {
        'Barlow Semi Condensed': 'Barlow-Regular.ttf',
        'Bree Serif': 'BreeSerif-Regular.ttf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(rootBundle.load('assets/brand/fonts/${entry.value}'));
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  test(
    'floor placement rejects overlaps, walls and doorway without changing defaults',
    () {
      expect(validFloorPlacement(floorDefaults), isTrue);
      expect(
        validFloorPlacement({...floorDefaults, 1: floorDefaults[2]!}),
        isFalse,
      );
      expect(
        validFloorPlacement({
          ...floorDefaults,
          1: const Rect.fromLTWH(.12, .28, .14, .14),
        }),
        isFalse,
      );
      expect(
        validFloorPlacement({
          ...floorDefaults,
          1: const Rect.fromLTWH(.4, .3, .14, .14),
        }),
        isFalse,
      );
    },
  );

  testWidgets(
    'distinct notes survive cart review and persist as separate order lines',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync('nohut-ux-');
      final file = '${folder.path}/pos.sqlite3';
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        folder.deleteSync(recursive: true);
      });
      final store = PosStore(databaseFile: file);
      final seed = emptyPosState();
      seed['settings'] = {'autoPrint': false};
      seed['localMenu'] = [
        {'id': 0, 'name': 'Falafel Dürüm', 'price': 140, 'category': 'wrap'},
        {'id': 1, 'name': 'Ayran', 'price': 45, 'category': 'drink'},
      ];
      store.replace(seed, 0);
      store.dispose();
      final previewKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: previewKey,
          child: NohutFalafelApp(databaseFile: file, startServer: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sipariş Al').first);
      await tester.pumpAndSettle();
      for (final note in ['Sos ayrı', 'Acılı']) {
        await tester.tap(find.text('Not / Malzeme').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('customization-note')),
          note,
        );
        await tester.tap(find.text('Kaydet').last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Not: Sos ayrı'), findsOneWidget);
      expect(find.text('Not: Acılı'), findsOneWidget);
      final preview = Platform.environment['NOHUT_UI_PREVIEW'];
      if (preview != null) {
        await tester.runAsync(() async {
          final image =
              await (previewKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(preview).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('İçecekler').last);
      await tester.tap(find.text('İçecekler').last);
      await tester.pumpAndSettle();
      expect(find.text('Not: Sos ayrı'), findsOneWidget);
      final table = find.byType(DropdownButtonFormField<int>);
      await tester.tap(table);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Masa 1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siparişi Kaydet'));
      await tester.pumpAndSettle();
      final saved = PosStore(databaseFile: file);
      final order = asMaps(saved.read().data['orders']).single;
      expect(activeLines(order).map((l) => l['note']), ['Sos ayrı', 'Acılı']);
      expect(orderTotalCents(order), 28000);
      saved.dispose();
      expect(tester.takeException(), isNull, reason: 'order saved');
      await tester.ensureVisible(find.text('Nakit / Kart'));
      await tester.tap(find.text('Nakit / Kart'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kart').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ödemeyi Gözden Geçir'));
      await tester.pumpAndSettle();
      expect(find.text('Terminalde Onaylandı · Kaydet'), findsOneWidget);
      await tester.tap(find.text('Vazgeç').last);
      await tester.pumpAndSettle();
      final unpaid = PosStore(databaseFile: file);
      expect(asMaps(unpaid.read().data['orders']).single['payments'], isEmpty);
      unpaid.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small desktop keeps labeled navigation and readable tables at 150 percent text',
    (tester) async {
      final folder = Directory.systemTemp.createTempSync('nohut-compact-');
      final file = '${folder.path}/pos.sqlite3';
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        folder.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        NohutFalafelApp(databaseFile: file, startServer: false),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Menüyü aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masalar & Siparişler').last);
      await tester.pumpAndSettle();
      expect(find.text('Masa 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily shift controls are removed and online demo stays isolated',
    (tester) async {
      // The confirmation itself must not invoke the supplied state mutation.
      // Its cancellation behavior is covered through the manager cash screen.
      final folder = Directory.systemTemp.createTempSync('nohut-cash-');
      final file = '${folder.path}/pos.sqlite3';
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        folder.deleteSync(recursive: true);
      });
      final store = PosStore(databaseFile: file);
      final seed = emptyPosState();
      seed['settings'] = {'autoPrint': false};
      seed['localMenu'] = [
        {'id': 0, 'name': 'Falafel Dürüm', 'price': 140, 'category': 'wrap'},
      ];
      store.replace(seed, 0);
      store.dispose();
      await tester.pumpWidget(
        NohutFalafelApp(databaseFile: file, startServer: false),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kasa & Ödemeler').first);
      await tester.tap(find.text('Kasa & Ödemeler').first);
      await tester.pumpAndSettle();
      expect(find.text('Kasayı Aç'), findsNothing);
      expect(find.text('Kasayı Kapat'), findsNothing);
      expect(find.text('Yazdırma Kuyruğu'), findsNothing);
      await tester.ensureVisible(find.text('Online Siparişler').first);
      await tester.tap(find.text('Online Siparişler').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yemeksepeti').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Örnek Online Kart'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kabul bekliyor'), findsWidgets);
      final real = PosStore(databaseFile: file);
      expect(real.read().data['orders'], isEmpty);
      expect(real.read().data['printJobs'], isEmpty);
      real.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
