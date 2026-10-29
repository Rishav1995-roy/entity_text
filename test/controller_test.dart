import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const asha = EntitySuggestion(id: 'u1', display: 'Asha Rao');

EntityTextEditingController make([String text = '']) =>
    EntityTextEditingController(text: text);

void type(EntityTextEditingController c, String insert) {
  final s = c.selection.isValid
      ? c.selection
      : TextSelection.collapsed(offset: c.text.length);
  final t = c.text.replaceRange(s.start, s.end, insert);
  c.value = TextEditingValue(
    text: t,
    selection: TextSelection.collapsed(offset: s.start + insert.length),
  );
}

void backspace(EntityTextEditingController c) {
  final o = c.selection.baseOffset;
  c.value = TextEditingValue(
    text: c.text.replaceRange(o - 1, o, ''),
    selection: TextSelection.collapsed(offset: o - 1),
  );
}

void main() {
  group('active query', () {
    test('detects @query and #query at the caret', () {
      final c = make();
      type(c, 'Hi @as');
      final q = c.activeQuery!;
      expect(q.trigger.char, '@');
      expect(q.query, 'as');
      expect(q.start, 3);
      type(c, ' and #fl');
      expect(c.activeQuery!.trigger.char, '#');
      expect(c.activeQuery!.query, 'fl');
    });

    test('not for emails, mid-word, spaces or non-collapsed selection', () {
      final c = make('mail a@b');
      c.selection = const TextSelection.collapsed(offset: 8);
      expect(c.activeQuery, isNull);
      c.value = const TextEditingValue(
          text: '@a b', selection: TextSelection.collapsed(offset: 4));
      expect(c.activeQuery, isNull);
      c.value = const TextEditingValue(
          text: '@ab',
          selection: TextSelection(baseOffset: 0, extentOffset: 3));
      expect(c.activeQuery, isNull);
    });

    test('allowSpaces trigger', () {
      final c = EntityTextEditingController(
        triggers: const [EntityTrigger('@', allowSpaces: true)],
      );
      type(c, 'Hey @Asha R');
      expect(c.activeQuery!.query, 'Asha R');
    });
  });

  group('structured mentions', () {
    test('applySuggestion stores id + display and moves the caret', () {
      final c = make();
      type(c, 'Hi @as');
      c.applySuggestion(c.activeQuery!, asha);
      expect(c.text, 'Hi @Asha Rao ');
      expect(c.mentions, [
        const Mention(id: 'u1', display: 'Asha Rao', start: 3),
      ]);
      expect(c.selection.baseOffset, c.text.length);
      expect(c.activeQuery, isNull);
      expect(c.markup, 'Hi @[Asha Rao](u1) ');
    });

    test('hashtag trigger inserts plain text, no mention', () {
      final c = make();
      type(c, '#fl');
      c.applySuggestion(
          c.activeQuery!, const EntitySuggestion(id: 't', display: 'flutter'));
      expect(c.text, '#flutter ');
      expect(c.mentions, isEmpty);
    });

    test('mention shifts when text is typed before it', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      c.value = TextEditingValue(
          text: 'XY${c.text}',
          selection: const TextSelection.collapsed(offset: 2));
      expect(c.mentions.single.start, 2);
      expect(c.text.substring(2, c.mentions.single.end), '@Asha Rao');
    });

    test('backspace removes the whole mention (flutter_mentions issue)', () {
      final c = make();
      type(c, 'Hi @a');
      c.applySuggestion(c.activeQuery!, asha);
      backspace(c); // removes the space
      expect(c.text, 'Hi @Asha Rao');
      expect(c.mentions, hasLength(1));
      backspace(c); // eats the mention as a unit
      expect(c.text, 'Hi ');
      expect(c.mentions, isEmpty);
      expect(c.selection.baseOffset, 3);
    });

    test('selection delete partly covering a mention removes it entirely', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      type(c, 'tail');
      // select "Rao tail" (inside mention to the end) and delete
      final from = c.text.indexOf('Rao');
      c.value = TextEditingValue(
        text: c.text.substring(0, from),
        selection: TextSelection.collapsed(offset: from),
      );
      expect(c.text, '');
      expect(c.mentions, isEmpty);
    });

    test('typing inside a mention turns it into plain text', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      c.value = TextEditingValue(
        text: c.text.replaceRange(3, 3, 'Z'),
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(c.mentions, isEmpty);
      expect(c.text, startsWith('@AsZha'));
    });

    test('typing right after a mention keeps it', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      type(c, 'ok');
      expect(c.mentions, hasLength(1));
      expect(c.markup, '@[Asha Rao](u1) ok');
    });

    test('two mentions, delete the first', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      type(c, '@b');
      c.applySuggestion(
          c.activeQuery!, const EntitySuggestion(id: 'u2', display: 'Bo'));
      expect(c.mentions.map((m) => m.id), ['u1', 'u2']);
      c.selection = const TextSelection.collapsed(offset: 9);
      backspace(c);
      expect(c.mentions.map((m) => m.id), ['u2']);
      expect(c.text.substring(c.mentions.single.start, c.mentions.single.end),
          '@Bo');
    });

    test('clearing the text clears mentions', () {
      final c = make();
      type(c, '@a');
      c.applySuggestion(c.activeQuery!, asha);
      c.clear();
      expect(c.mentions, isEmpty);
    });

    test('fromMarkup / setMarkup', () {
      final c = EntityTextEditingController.fromMarkup('Yo @[Asha Rao](u1)!');
      expect(c.text, 'Yo @Asha Rao!');
      expect(c.mentions.single.id, 'u1');
      c.setMarkup('@[Bo](u2) hi');
      expect(c.text, '@Bo hi');
      expect(c.markup, '@[Bo](u2) hi');
    });

    test('mentions that do not match the text are ignored', () {
      final c = EntityTextEditingController(
        text: 'hello',
        mentions: const [Mention(id: 'x', display: 'nope', start: 0)],
      );
      expect(c.mentions, isEmpty);
    });
  });

  group('live styling', () {
    testWidgets('hashtags, urls and mentions are styled while typing',
        (tester) async {
      final c = EntityTextEditingController(styles: {
        EntityType.hashtag: const TextStyle(color: Color(0xFF00AA00)),
      });
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));
      type(c, 'go #flutter now https://a.com');
      TextSpan span() => c.buildTextSpan(context: ctx, withComposing: false);
      final parts = span().children!.cast<TextSpan>();
      final tag = parts.firstWhere((s) => s.text == '#flutter');
      expect(tag.style!.color, const Color(0xFF00AA00));
      expect(
          parts.firstWhere((s) => s.text == 'https://a.com').style, isNotNull);
      expect(parts.map((s) => s.text).join(), c.text);
      // Typing continues: the new letters join the tag.
      type(c, ' #dar');
      expect(
          span().children!.cast<TextSpan>().map((s) => s.text).join(), c.text);
    });

    testWidgets('composing region keeps its underline', (tester) async {
      final c = make('abc');
      late BuildContext ctx;
      await tester.pumpWidget(Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }));
      c.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 1, end: 3),
      );
      final parts = c
          .buildTextSpan(context: ctx, withComposing: true)
          .children!
          .cast<TextSpan>();
      expect(parts.last.style!.decoration, TextDecoration.underline);
      expect(parts.map((s) => s.text).join(), 'abc');
    });
  });
}
