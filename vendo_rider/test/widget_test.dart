import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vendo_rider/main.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const VendoRiderApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
