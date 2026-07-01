import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kabadiai_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test — just checks the app builds without crashing
    await tester.pumpWidget(const KabadiAIApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
