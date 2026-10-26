import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';

void main() {
  testWidgets('capture native workspace previews', (tester) async {
    final font = FontLoader('Segoe UI')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    final mono = FontLoader('Consolas')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(r'C:\Windows\Fonts\consola.ttf').readAsBytesSync(),
          ),
        ),
      );
    await mono.load();
    final output = Directory(
      Platform.environment['NOHUT_CAPTURE_DIR'] ??
          '${Directory.systemTemp.path}/nohut-workspace-previews',
    )..createSync(recursive: true);
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    final folder = Directory.systemTemp.createTempSync('nohut-preview-');
    final db = '${folder.path}/qa.sqlite3';
    final store = PosStore(databaseFile: db), state = emptyPosState();
    for (final table in [1, 3, 4]) {
      newLocalOrder(
        state: state,
        source: 'Masa',
        table: table,
        productLines: [
          {
            'name': 'Falafel Dürüm',
            'productId': 0,
            'price': 140,
            'qty': 2,
            'removed': ['Soğan'],
            'note': 'Sos ayrı',
          },
          {
            'name': 'Ayran',
            'productId': 1,
            'price': 30,
            'qty': 2,
            'removed': [],
            'note': '',
          },
        ],
      );
    }
    store.replace(state, 0);
    store.dispose();
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: NohutFalafelApp(databaseFile: db, startServer: false),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/brand-logo.jpeg'),
        boundary.currentContext!,
      );
    });
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final img = await render.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/preview-$name-v5.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    await tester.tap(find.text('Masalar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masa 3'));
    await tester.pumpAndSettle();
    await capture('tables');
    await tester.tap(find.text('Tüm Siparişler').first);
    await tester.pumpAndSettle();
    await capture('orders');
    await tester.tap(find.byKey(const ValueKey('detail-tab-Hesap Böl')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kişi Ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Ali');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guest-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('check-line-1:0')));
    await tester.tap(find.byKey(const ValueKey('check-line-1:0')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('assign-product')));
    await tester.tap(find.byKey(const ValueKey('assign-product')));
    await tester.pumpAndSettle();
    await capture('guest-split');
    await tester.tap(find.text('Yazdırma Kuyruğu').first);
    await tester.pumpAndSettle();
    await capture('printer');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    folder.deleteSync(recursive: true);
  });
}
