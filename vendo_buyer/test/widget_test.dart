import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendo_buyer/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const VendoBuyerApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
