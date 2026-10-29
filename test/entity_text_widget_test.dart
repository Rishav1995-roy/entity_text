import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {double width = 300}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

/// Global position of the middle of the first occurrence of [needle].
Offset centerOf(WidgetTester tester, String needle) {
  final render =
      tester.renderObject<RenderParagraph>(find.byType(RichText).first);
  final plain = render.text.toPlainText(includePlaceholders: false);
  final i = plain.indexOf(needle);
  expect(i, greaterThanOrEqualTo(0), reason: '$needle not found in $plain');
  final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + needle.length));
  return render.localToGlobal(boxes.first.toRect().center);
}

List<TextSpan> allSpans(InlineSpan root) {
  final out = <TextSpan>[];
  root.visitChildren((s) {
    if (s is TextSpan) out.add(s);
    return true;
  });
  return out;
}

void main() {
  const text = 'Hello @asha see https://example.com/x and #flutter ok';

  group('tappable', () {
    testWidgets('tap and long press report the right entity', (tester) async {
      final taps = <Entity>[];
      final longs = <Entity>[];
      await tester.pumpWidget(app(EntityText(
        text,
        onTap: taps.add,
        onLongPress: longs.add,
      )));
      await tester.tapAt(centerOf(tester, 'https://example.com/x'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.single.type, EntityType.url);
      expect(taps.single.value, 'https://example.com/x');
      await tester.tapAt(centerOf(tester, '#flutter'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.last.type, EntityType.hashtag);
      expect(longs, isEmpty);

      await tester.longPressAt(centerOf(tester, '@asha'));
      await tester.pump();
      expect(longs.single.type, EntityType.mention);
      expect(longs.single.value, 'asha');
      expect(taps.length, 2, reason: 'a long press must not also tap');

      await tester.tapAt(centerOf(tester, 'Hello'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.length, 2, reason: 'plain text is not tappable');
    });

    testWidgets('only onLongPress set works without onTap', (tester) async {
      final longs = <Entity>[];
      await tester.pumpWidget(app(EntityText(text, onLongPress: longs.add)));
      await tester.longPressAt(centerOf(tester, '#flutter'));
      await tester.pump();
      expect(longs.single.text, '#flutter');
    });

    testWidgets('custom entity types, styleBuilder and spanBuilder',
        (tester) async {
      const order = EntityType('order');
      final tapped = <Entity>[];
      await tester.pumpWidget(app(EntityText(
        'Track ORD-12345 please',
        matchers: [
          RegexEntityMatcher(order, RegExp(r'ORD-\d+'),
              valueBuilder: (m) => m[0]!.substring(4)),
        ],
        entityStyles: const {order: TextStyle(color: Color(0xFFFF0000))},
        onTap: tapped.add,
      )));
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      final span = allSpans(rich.text).firstWhere((s) => s.text == 'ORD-12345');
      expect(span.style!.color, const Color(0xFFFF0000));
      await tester.tapAt(centerOf(tester, 'ORD-12345'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped.single.value, '12345');

      await tester.pumpWidget(app(EntityText(
        'Hi @asha',
        spanBuilder: (context, e, style, rec) => TextSpan(
          text: '[${e.value}]',
          style: style,
          recognizer: rec,
        ),
      )));
      expect(find.textContaining('[asha]', findRichText: true), findsOneWidget);
    });

    testWidgets('structured mentions from markup carry the id', (tester) async {
      final tapped = <Entity>[];
      await tester.pumpWidget(app(EntityText.markup(
        'Thanks @[Asha Rao](u42) and www.example.com',
        onTap: tapped.add,
      )));
      await tester.tapAt(centerOf(tester, '@Asha Rao'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tapped.single.value, 'u42');
      expect((tapped.single.data! as Mention).display, 'Asha Rao');
    });

    testWidgets('re-parses when the text changes', (tester) async {
      await tester.pumpWidget(app(const EntityText('plain')));
      await tester.pumpWidget(app(const EntityText('now #tag')));
      final rich = tester.widget<RichText>(find.byType(RichText).first);
      expect(
          allSpans(rich.text).where((s) =>
              s.text != null &&
              s.recognizer == null &&
              s.style != null &&
              s.text == '#tag'),
          isNotEmpty);
    });
  });

  group('selectable AND tappable (flutter_linkify issue)', () {
    testWidgets(
        'inside SelectionArea the whole text selects and taps still work',
        (tester) async {
      final taps = <Entity>[];
      SelectedContent? content;
      await tester.pumpWidget(app(SelectionArea(
        onSelectionChanged: (c) => content = c,
        child: EntityText(text, onTap: taps.add),
      )));
      await tester.tapAt(centerOf(tester, '@asha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.single.text, '@asha');

      final state =
          tester.state<SelectableRegionState>(find.byType(SelectableRegion));
      state.selectAll(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(content?.plainText, text);

      // Long-pressing plain text selects a word without firing a tap.
      state.clearSelection();
      await tester.pump();
      await tester.longPressAt(centerOf(tester, 'Hello'));
      await tester.pump();
      expect(content?.plainText, 'Hello');
      expect(taps.length, 1);
    });

    testWidgets('selectable: true works on its own', (tester) async {
      final taps = <Entity>[];
      SelectedContent? content;
      await tester.pumpWidget(app(
        EntityText(text,
            selectable: true,
            onTap: taps.add,
            onSelectionChanged: (c) => content = c),
      ));
      expect(find.byType(SelectableRegion), findsOneWidget);
      await tester.tapAt(centerOf(tester, '#flutter'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.single.text, '#flutter');
      final state =
          tester.state<SelectableRegionState>(find.byType(SelectableRegion));
      state.selectAll(SelectionChangedCause.toolbar);
      await tester.pump();
      expect(content?.plainText, text);
    });

    testWidgets('long press on an entity wins over selection', (tester) async {
      final longs = <Entity>[];
      SelectedContent? content;
      await tester.pumpWidget(app(SelectionArea(
        onSelectionChanged: (c) => content = c,
        child: EntityText(text, onLongPress: longs.add),
      )));
      await tester.longPressAt(centerOf(tester, '#flutter'));
      await tester.pump();
      expect(longs.single.text, '#flutter');
      expect(content?.plainText ?? '', isEmpty);
    });

    testWidgets('recognizers are disposed with the widget', (tester) async {
      await tester.pumpWidget(app(EntityText(text, onTap: (_) {})));
      await tester.pumpWidget(app(const SizedBox()));
      // No exception from leaked recognizers == pass.
      expect(tester.takeException(), isNull);
    });
  });

  group('read more / less that never breaks entities', () {
    const long =
        'Great weekend with @asha and friends! Photos at https://photos.example.com/albums/2026/summer-trip and more tags #summer #fun #flutter #dart. Thanks everybody for coming, see you all next year at the same place!';

    String shown(WidgetTester tester) => tester
        .renderObject<RenderParagraph>(find.byType(RichText).first)
        .text
        .toPlainText();

    testWidgets('by lines: collapsed text ends at an entity boundary',
        (tester) async {
      await tester.pumpWidget(app(
        EntityText(long, collapsedMaxLines: 2, onTap: (_) {}),
        width: 260,
      ));
      final collapsed = shown(tester);
      expect(collapsed, endsWith('… Read more'));
      expect(collapsed.length, lessThan(long.length));
      final prefix =
          collapsed.substring(0, collapsed.length - '… Read more'.length);
      expect(long.startsWith(prefix), isTrue);
      for (final e in EntityParser().parse(long)) {
        final inside = e.start < prefix.length && prefix.length < e.end;
        expect(inside, isFalse, reason: 'cut inside ${e.text}');
      }
      final painter =
          tester.renderObject<RenderParagraph>(find.byType(RichText).first);
      expect(painter.size.height, lessThanOrEqualTo(2 * 20.0 * 1.3));
    });

    testWidgets('by lines: every width keeps entities whole', (tester) async {
      for (var w = 120.0; w < 400; w += 13) {
        await tester.pumpWidget(app(
          EntityText(long, collapsedMaxLines: 3, onTap: (_) {}),
          width: w,
        ));
        final s = shown(tester);
        if (!s.endsWith('… Read more')) continue;
        final prefix = s.substring(0, s.length - '… Read more'.length);
        for (final e in EntityParser().parse(long)) {
          final inside = e.start < prefix.length && prefix.length < e.end;
          expect(inside, isFalse, reason: 'width $w cut inside ${e.text}');
        }
      }
    });

    testWidgets('by length, and expand/collapse toggles', (tester) async {
      final states = <bool>[];
      await tester.pumpWidget(app(EntityText(
        long,
        collapsedMaxLength: 60,
        onExpandedChanged: states.add,
      )));
      expect(shown(tester), contains('Read more'));
      await tester.tapAt(centerOf(tester, 'Read more'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(states, [true]);
      expect(shown(tester), startsWith(long));
      expect(shown(tester), endsWith('Read less'));
      await tester.tapAt(centerOf(tester, 'Read less'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(states, [true, false]);
      expect(shown(tester), contains('Read more'));
    });

    testWidgets('short text is untouched; no toggle', (tester) async {
      await tester.pumpWidget(app(
        const EntityText('short #tag', collapsedMaxLines: 3),
      ));
      expect(shown(tester), 'short #tag');
    });

    testWidgets('entities in the visible part stay tappable', (tester) async {
      final taps = <Entity>[];
      await tester.pumpWidget(app(
        EntityText(long, collapsedMaxLines: 2, onTap: taps.add),
        width: 260,
      ));
      await tester.tapAt(centerOf(tester, '@asha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.single.text, '@asha');
    });
  });

  group('RTL', () {
    testWidgets('renders and taps in a right-to-left layout', (tester) async {
      final taps = <Entity>[];
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: EntityText('مرحبا #وسم https://example.com/ar شكرا',
                onTap: taps.add),
          ),
        ),
      ));
      await tester.tapAt(centerOf(tester, '#وسم'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps.single.text, '#وسم');
    });
  });
}
