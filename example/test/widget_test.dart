import 'package:flutter/material.dart';
import 'package:entity_text_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('example app builds and switches tabs', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.textContaining('Tap a link'), findsOneWidget);
    await tester.tap(find.text('Composer'));
    await tester.pump();
    expect(find.text('Write a post'), findsOneWidget);
    await tester.tap(find.text('Playground'));
    await tester.pump();
    expect(find.byType(FilterChip), findsWidgets);
  });
}
