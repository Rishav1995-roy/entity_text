import 'dart:async';

import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const people = [
  EntitySuggestion(id: 'u1', display: 'Asha Rao', subtitle: 'Design'),
  EntitySuggestion(id: 'u2', display: 'Arjun Mehta'),
  EntitySuggestion(id: 'u3', display: 'Bo Chen'),
];

Future<List<EntitySuggestion>> search(ActiveQuery q) async {
  await Future<void>.delayed(const Duration(milliseconds: 30));
  return people
      .where((p) => p.display.toLowerCase().contains(q.query.toLowerCase()))
      .toList();
}

Future<EntityTextEditingController> pumpField(
  WidgetTester tester, {
  EntitySuggestionsBuilder? builder,
  void Function(ActiveQuery, EntitySuggestion)? onSelected,
}) async {
  final c = EntityTextEditingController();
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: EntitySuggestions(
          controller: c,
          suggestionsBuilder: builder ?? search,
          onSelected: onSelected,
          builder: (context, node) =>
              TextField(controller: c, focusNode: node, maxLines: null),
        ),
      ),
    ),
  ));
  await tester.tap(find.byType(TextField));
  await tester.pump();
  return c;
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  testWidgets('typing @ shows async suggestions; tapping one inserts a mention',
      (tester) async {
    ActiveQuery? chosenQuery;
    final c = await pumpField(tester, onSelected: (q, s) => chosenQuery = q);
    await tester.enterText(find.byType(TextField), 'Hi @a');
    await settle(tester);
    expect(find.text('Asha Rao'), findsOneWidget);
    expect(find.text('Arjun Mehta'), findsOneWidget);
    expect(find.text('Bo Chen'), findsNothing);
    expect(find.text('Design'), findsOneWidget);

    await tester.tap(find.text('Arjun Mehta'));
    await tester.pump();
    expect(c.text, 'Hi @Arjun Mehta ');
    expect(c.mentions.single.id, 'u2');
    expect(chosenQuery!.query, 'a');
    await settle(tester);
    expect(find.text('Asha Rao'), findsNothing, reason: 'overlay closes');
  });

  testWidgets('keyboard: arrows move, Enter selects, wraps around',
      (tester) async {
    final c = await pumpField(tester);
    await tester.enterText(find.byType(TextField), '@');
    await settle(tester);
    expect(find.text('Bo Chen'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.mentions.single.id, 'u3');
    expect(c.text, '@Bo Chen ');

    c.clear();
    await tester.enterText(find.byType(TextField), '@');
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // wraps to last
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(c.mentions.single.id, 'u3');
  });

  testWidgets('keyboard: Escape closes until the query changes',
      (tester) async {
    final c = await pumpField(tester);
    await tester.enterText(find.byType(TextField), '@a');
    await settle(tester);
    expect(find.text('Asha Rao'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Asha Rao'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(c.mentions, isEmpty, reason: 'enter no longer picks when closed');
  });

  testWidgets('arrow keys still move the caret when no list is open',
      (tester) async {
    final c = await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'plain');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(c.selection.baseOffset, 4);
  });

  testWidgets('a slow stale response does not overwrite a newer one',
      (tester) async {
    final slow = Completer<List<EntitySuggestion>>();
    final c = await pumpField(tester, builder: (q) {
      if (q.query == 'a') return slow.future;
      return [people[2]];
    });
    await tester.enterText(find.byType(TextField), '@a');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), '@b');
    await settle(tester);
    expect(find.text('Bo Chen'), findsOneWidget);
    slow.complete([people[0]]);
    await settle(tester);
    expect(find.text('Asha Rao'), findsNothing);
    expect(find.text('Bo Chen'), findsOneWidget);
    expect(c.activeQuery!.query, 'b');
  });

  testWidgets('an erroring builder shows nothing and does not crash',
      (tester) async {
    await pumpField(tester, builder: (q) => throw StateError('boom'));
    await tester.enterText(find.byType(TextField), '@a');
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('no list for an email-like @ or after losing focus',
      (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'a@b');
    await settle(tester);
    expect(find.byType(ListView), findsNothing);
    await tester.enterText(find.byType(TextField), '@a');
    await settle(tester);
    expect(find.byType(ListView), findsOneWidget);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('hashtag suggestions insert plain text', (tester) async {
    final c = await pumpField(tester, builder: (q) {
      return q.trigger.char == '#'
          ? [const EntitySuggestion(id: 't', display: 'flutter')]
          : const [];
    });
    await tester.enterText(find.byType(TextField), '#fl');
    await settle(tester);
    await tester.tap(find.text('flutter'));
    await tester.pump();
    expect(c.text, '#flutter ');
    expect(c.mentions, isEmpty);
  });
}
