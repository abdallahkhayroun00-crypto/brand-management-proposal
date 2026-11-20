import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/product_customization.dart';
import 'package:nohut_falafel_desktop/receipt_preview.dart';
import 'package:nohut_falafel_desktop/service_metrics.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';

import 'updates16_test.dart' show fixture, row;

void main() {
  testWidgets(
    'cashier ingredient toggles, detailed note and manual discount save together',
    (t) async {
      Json? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () async {
                  result = await customizeLineDialog(ctx, {
                    ...row(),
                    'name': 'Falafel Dürüm',
                  }, description: 'Falafel, humus, domates, marul');
                },
                child: const Text('Düzenle'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Düzenle'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilterChip, 'Domates'));
      await t.enterText(
        find.byKey(const ValueKey('customization-note')),
        'Domates çıkar, sarma yerine sembusek',
      );
      final adjustment = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText?.startsWith('Her adet için fark') == true,
      );
      await t.enterText(adjustment, '-10');
      await t.tap(find.text('Kaydet'));
      await t.pumpAndSettle();
      expect(result?['removed'], contains('Domates'));
      expect(result?['adjustmentCents'], -1000);
      expect(result?['price'], 130);
      expect(result?['qty'], 2);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'centered receipt preview and staff overview render actual modifiers and counts',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = fixture(), line = row();
      applyLineCustomization(line, 1000, 'Ek sembusek', ['Domates']);
      final o = newLocalOrder(
        state: s,
        source: 'Masa',
        table: 1,
        productLines: [line],
        cashier: 'Bassil',
      );
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  StaffMetrics(state: s, day: o['numberDay'] as String),
                  ReceiptPreview(
                    order: o,
                    settings: const {
                      'paperWidthMm': 56,
                      'printableWidthMm': 48,
                      'receiptLogoMm': 18,
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Personel'), findsOneWidget);
      expect(find.text('Bassil'), findsOneWidget);
      final table = t.widget<Table>(find.byType(Table));
      expect(table.children, hasLength(2));
      expect((table.children.last.children[1] as Padding).child,
          isA<Text>().having((text) => text.data, 'order count', '1'));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              RegExp(
                'HESAP ÖZETİ.*Not: Ek sembusek',
                dotAll: true,
              ).hasMatch(w.properties.label ?? ''),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
}
