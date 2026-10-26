import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';

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
    final noto = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    await noto.load();
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
    openCash(state, 10000);
    state['localMenu'] = [
      {'id': 0, 'name': 'Falafel Dürüm', 'category': 'wrap', 'price': 140},
      {'id': 1, 'name': 'Ayran', 'category': 'drink', 'price': 30},
    ];
    seedPlatformMenu(state, asMaps(state['localMenu']));
    final first = asMaps(state['orders']).first;
    recordPayment(first, 14000, 'Nakit', receivedCents: 14000);
    refundPayment(first, 0, 2000, 'Örnek iade');
    moveCash(state, -1000, 'Örnek sarf gideri');
    importPlatform(state, platformFixture(state, 'Trendyol Go', 'card'));
    importPlatform(state, platformFixture(state, 'Yemeksepeti', 'card'));
    final completed = importPlatform(
      state,
      platformFixture(state, 'Trendyol Go', 'card'),
    )!;
    externalPlatformEvent(state, completed['id'] as int, 'Delivered');
    sampleClaim(state, completed['id'] as int, 'PAY_BACK');
    sampleReview(state, 'Trendyol Go');
    sampleSettlement(state, completed['id'] as int);
    queuePlatform(state, 'sync', 'Trendyol Go', 'Trendyol Go', {});
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
          '${output.path}/preview-$name-v7.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }

    Future<void> navigate(String label) async {
      await tester.scrollUntilVisible(
        find.text(label).first,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    await capture('dashboard');

    await tester.tap(find.text('Masalar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masa 3'));
    await tester.pumpAndSettle();
    await capture('tables');
    await tester.tap(find.text('Tüm Siparişler').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-row-1201')));
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
    await navigate('Fiş & Fatura');
    await capture('documents-bill');
    await tester.tap(find.byKey(const ValueKey('work-tab-Satış Belgeleri')));
    await tester.pumpAndSettle();
    await capture('documents-invoices');
    await navigate('Kasa & Ödemeler');
    await capture('cash-open-orders');
    for (final e in {
      'Günlük Kasa': 'cash-session',
      'Kasa Geçmişi': 'cash-history',
      'Nakit Hareketleri': 'cash-movements',
    }.entries) {
      await tester.tap(find.byKey(ValueKey('work-tab-${e.key}')));
      await tester.pumpAndSettle();
      await capture(e.value);
    }
    await navigate('Personel & QR');
    await capture('staff-qr');
    await tester.tap(find.text('Personel Bilgileri'));
    await tester.pumpAndSettle();
    await capture('staff-directory');
    await navigate('Raporlar');
    await capture('reports-summary');
    for (final e in {
      'Tahsilatlar': 'reports-collections',
      'Ürünler': 'reports-products',
      'Personel': 'reports-staff',
      'Platform Mutabakatı': 'reports-finance',
    }.entries) {
      await tester.tap(find.byKey(ValueKey('work-tab-${e.key}')));
      await tester.pumpAndSettle();
      await capture(e.value);
    }
    await navigate('Ayarlar');
    await capture('settings-general');
    for (final e in {
      'Menü & Fiyatlar': 'settings-menu',
      'Platform API': 'settings-api',
      'Yazıcı': 'settings-printer',
      'Veri & Yedek': 'settings-backup',
    }.entries) {
      await tester.tap(find.byKey(ValueKey('settings-section-${e.key}')));
      await tester.pumpAndSettle();
      if (e.key == 'Menü & Fiyatlar') {
        final row = find
            .byWidgetPredicate(
              (w) =>
                  w is ListTile &&
                  w.key is ValueKey &&
                  '${(w.key as ValueKey).value}'.startsWith(
                    'settings-product-',
                  ),
            )
            .first;
        await tester.tap(row);
        await tester.pumpAndSettle();
      }
      await capture(e.value);
    }
    await navigate('Online Siparişler');
    await capture('online-orders');
    for (final e in {
      'Mağaza': 'online-store',
      'Menü': 'online-menu',
      'İade Talepleri': 'online-claims',
      'Değerlendirmeler': 'online-reviews',
      'Faturalar': 'online-invoices',
      'Senkronizasyon': 'online-sync',
    }.entries) {
      await tester.tap(find.text(e.key).first);
      await tester.pumpAndSettle();
      await capture(e.value);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    folder.deleteSync(recursive: true);
  });
}
