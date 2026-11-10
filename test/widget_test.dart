import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thrive/screens/about_screen.dart';

void main() {
  testWidgets('About screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );
    expect(find.text('About THRIVE'), findsOneWidget);
    expect(find.text('THRIVE'), findsOneWidget);
  });
}
