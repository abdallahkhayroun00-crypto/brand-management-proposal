import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/main.dart';

void main() {
  testWidgets('Native Flutter manager loads without a panel chooser', (tester) async {
    await tester.pumpWidget(const NohutFalafelApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Genel Bakış'), findsWidgets);
    expect(find.text('Masalar'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
