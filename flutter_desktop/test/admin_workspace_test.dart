import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/reports_workspace.dart';
import 'package:nohut_falafel_desktop/platform_api.dart';
import 'package:nohut_falafel_desktop/cash_workspace.dart';

class TestSecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'report date, method and refund filters match CSV; product row opens its order',
    (tester) async {
      viewport(tester);
      final folder = Directory.systemTemp.createTempSync('nohut-reports-');
      addTearDown(() => folder.deleteSync(recursive: true));
      final state = emptyPosState();
      final recent = newLocalOrder(
        state: state,
        source: 'Masa',
        table: 1,
        productLines: [
          {
            'name': 'Falafel',
            'price': 100,
            'qty': 2,
            'removed': [],
            'note': '',
          },
        ],
      );
      recordPayment(recent, 10000, 'Nakit', receivedCents: 10000);
      refundPayment(recent, 0, 2500, 'Kısmi iade');
      final old = newLocalOrder(
        state: state,
        source: 'Gel-Al',
        productLines: [
          {'name': 'Ayran', 'price': 30, 'qty': 1, 'removed': [], 'note': ''},
        ],
      );
      recordPayment(old, 3000, 'Kart');
      old['createdAt'] = '2020-01-01T10:00:00Z';
      (old['batches'] as List).first['createdAt'] = '2020-01-01T10:00:00Z';
      (old['payments'] as List).first['createdAt'] = '2020-01-01T10:00:00Z';
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsWorkspace(
              state: state,
              edit: (_) => true,
              onOrder: (id) => opened = id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bugün'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('work-tab-Tahsilatlar')));
      await tester.pumpAndSettle();
      expect(find.text('#${old['id']} · Gel-Al'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('report-Yöntem-Tümü')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kart').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-row-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('report-Yöntem-Kart')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nakit').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-İşlem-Tümü')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İade').last);
      await tester.pumpAndSettle();
      expect(find.text('-25,00 ₺'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('report-export')));
      await tester.pumpAndSettle();
      final csvPath = '${folder.path}/refund.csv';
      await tester.enterText(find.byType(TextField).last, csvPath);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final csv = File(csvPath).readAsStringSync();
      expect(csv, contains('"\'-2500"'));
      expect(csv, contains('"İade"'));
      expect(csv, isNot(contains('"Kart"')));
      await tester.tap(find.byKey(const ValueKey('work-tab-Ürünler')));
      await tester.pumpAndSettle();
      expect(find.text('Ayran'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('report-row-0')));
      expect(opened, recent['id']);
      await tester.tap(find.text('Tüm Tarihler'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('report-search-Ürünler')),
        'Ayran',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-row-0')),
          matching: find.text('Ayran'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('report-row-0')));
      expect(opened, old['id']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings price save preserves sold check; API keys stay outside SQLite; backup is readable',
    (tester) async {
      viewport(tester);
      final folder = Directory.systemTemp.createTempSync('nohut-settings-'),
          file = '${folder.path}/pos.sqlite3';
      final secrets = TestSecrets();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        folder.deleteSync(recursive: true);
      });
      final seed = PosStore(databaseFile: file), state = emptyPosState();
      state['localMenu'] = [
        {'id': 0, 'name': 'Falafel', 'category': 'wrap', 'price': 100},
      ];
      final order = newLocalOrder(
        state: state,
        source: 'Masa',
        table: 1,
        productLines: [
          {
            'name': 'Falafel',
            'productId': 0,
            'price': 100,
            'qty': 1,
            'removed': [],
            'note': '',
          },
        ],
      );
      seed.replace(state, 0);
      seed.dispose();
      await tester.pumpWidget(
        NohutFalafelApp(
          databaseFile: file,
          startServer: false,
          secretStore: secrets,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ayarlar'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ayarlar').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings-section-Menü & Fiyatlar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-product-0')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('settings-product-price')),
        '175,50',
      );
      await tester.tap(find.byKey(const ValueKey('settings-save-price')));
      await tester.pumpAndSettle();
      final saved = PosStore(databaseFile: file);
      expect(asMaps(saved.read().data['localMenu']).single['price'], 175.50);
      expect(
        orderTotalCents(mutableOrder(saved.read().data, order['id'] as int)!),
        10000,
      );
      saved.dispose();
      await tester.tap(
        find.byKey(const ValueKey('settings-section-Platform API')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('API Kodunu / Bilgilerini Gir'));
      await tester.pumpAndSettle();
      final apiKey =
          find
                  .byType(TextField)
                  .evaluate()
                  .where(
                    (e) =>
                        (e.widget as TextField).decoration?.labelText ==
                        'API Key / API Kodu',
                  )
                  .single
                  .widget
              as TextField;
      expect(apiKey.obscureText, isTrue);
      apiKey.controller!.text = 'TEST_SECRET_NOT_LIVE';
      await tester.tap(find.text('Güvenli Kaydet'));
      await tester.pumpAndSettle();
      expect(
        (await CredentialVault(secrets).load('Trendyol Go')).field('apiKey'),
        'TEST_SECRET_NOT_LIVE',
      );
      final checked = PosStore(databaseFile: file);
      expect(
        jsonEncode(checked.read().data),
        isNot(contains('TEST_SECRET_NOT_LIVE')),
      );
      checked.dispose();
      await tester.tap(
        find.byKey(const ValueKey('settings-section-Veri & Yedek')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tutarlı SQLite Yedeği Oluştur'));
      await tester.pumpAndSettle();
      final backup = '${folder.path}/backup.sqlite3';
      await tester.enterText(find.byType(TextField).last, backup);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final restored = PosStore(databaseFile: backup);
      expect(asMaps(restored.read().data['localMenu']).single['price'], 175.50);
      restored.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cash workspace opening, movement and counted close persist the variance',
    (tester) async {
      viewport(tester);
      final state = emptyPosState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, refresh) => CashWorkspace(
                state: state,
                edit: (change) {
                  refresh(() => change(state));
                  return true;
                },
                onOrder: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('work-tab-Günlük Kasa')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kasayı Aç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '100');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(activeCash(state)!['openingCents'], 10000);
      await tester.tap(find.text('Kasa Giriş'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), '50');
      await tester.enterText(find.byType(TextField).at(1), 'Bozuk para');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(expectedCash(state, activeCash(state)!), 15000);
      await tester.tap(find.text('Sayım ve Kapanış'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '149,50');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(activeCash(state), isNull);
      expect(
        asMaps(cashBook(state)['sessions']).single['differenceCents'],
        -50,
      );
      await tester.tap(find.byKey(const ValueKey('work-tab-Kasa Geçmişi')));
      await tester.pumpAndSettle();
      expect(find.text('-0,50 ₺'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
