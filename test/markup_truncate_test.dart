import 'dart:math';

import 'package:entity_text/entity_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('markup round trip', () {
    test('encode and decode', () {
      const m = Mention(id: 'u1', display: 'Asha Rao', start: 3);
      final markup = EntityMarkup.encode('Hi @Asha Rao!', [m]);
      expect(markup, 'Hi @[Asha Rao](u1)!');
      final d = EntityMarkup.decode(markup);
      expect(d.text, 'Hi @Asha Rao!');
      expect(d.mentions, [m]);
    });

    test('special characters in display, id and plain text', () {
      const text = r'a \ b @[x](y) [z] @Na]me(1) #t';
      final mentions = [
        const Mention(id: r'i)d\', display: r'Na]me\', start: 20),
      ];
      // Build a text where the mention really sits at its range.
      final full = text.replaceRange(20, 20, '');
      final t = '${full.substring(0, 20)}@Na]me\\${full.substring(20)}';
      final enc = EntityMarkup.encode(t, mentions);
      final dec = EntityMarkup.decode(enc);
      expect(dec.text, t);
      expect(dec.mentions, mentions);
    });

    test('malformed markup stays literal', () {
      for (final s in ['@[x]', '@[x](', '@[](id)', '@[x](y', 'a@[b']) {
        final d = EntityMarkup.decode(s);
        expect(d.mentions, isEmpty, reason: s);
        expect(d.text, s);
      }
    });

    test('random texts round trip', () {
      final rnd = Random(7);
      const alphabet = r'ab @#[]()\ X1';
      for (var i = 0; i < 400; i++) {
        final plain = List.generate(
                rnd.nextInt(30), (_) => alphabet[rnd.nextInt(alphabet.length)])
            .join();
        final mentions = <Mention>[];
        final buf = StringBuffer();
        var pos = 0;
        var pieces = rnd.nextInt(3);
        var rest = plain;
        while (pieces-- > 0 && rest.isNotEmpty) {
          final cut = rnd.nextInt(rest.length);
          buf.write(rest.substring(0, cut));
          pos += cut;
          rest = rest.substring(cut);
          final display = List.generate(1 + rnd.nextInt(6),
              (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
          final trig = rnd.nextBool() ? '@' : '#';
          final m = Mention(
              id: 'id${rnd.nextInt(99)}${alphabet[rnd.nextInt(alphabet.length)]}',
              display: display,
              start: pos,
              trigger: trig);
          mentions.add(m);
          buf.write(m.text);
          pos += m.text.length;
        }
        buf.write(rest);
        final text = buf.toString();
        final back = EntityMarkup.decode(EntityMarkup.encode(text, mentions));
        expect(back.text, text, reason: 'text for $text');
        expect(back.mentions, mentions, reason: 'mentions for $text');
      }
    });
  });

  group('truncation never breaks entities', () {
    const text = 'Read https://example.com/very/long/path now #tag';
    final entities = EntityParser().parse(text);

    test('cut inside a URL moves to the URL start', () {
      expect(snapCut(text, entities, 20), 4); // trims the space before URL
    });
    test('cut inside a hashtag moves before it', () {
      final cut = snapCut(text, entities, text.length - 2);
      expect(text.substring(0, cut), endsWith('now'));
    });
    test('cut right after an entity is kept', () {
      final end = entities.first.end;
      expect(snapCut(text, entities, end), end);
    });
    test('a leading entity longer than the limit is kept whole', () {
      const t = 'https://example.com/very/long/path and more';
      final e = EntityParser().parse(t);
      expect(snapCut(t, e, 10), 'https://example.com/very/long/path'.length);
    });
    test('never splits an emoji or a surrogate pair', () {
      const t = 'ab 👨‍👩‍👧‍👦 cd';
      for (var i = 1; i < t.length; i++) {
        final c = snapCut(t, const [], i);
        final prefix = t.substring(0, c);
        // A split would leave a lone surrogate or a dangling joiner.
        expect(prefix.codeUnits.where((u) => u >= 0xD800 && u <= 0xDBFF).length,
            prefix.codeUnits.where((u) => u >= 0xDC00 && u <= 0xDFFF).length);
        expect(prefix.endsWith('‍'), isFalse);
      }
    });
    test('collapsedLengthCut returns null when the text fits', () {
      expect(collapsedLengthCut('short', const [], 10), isNull);
      expect(collapsedLengthCut(text, entities, 20), isNotNull);
    });
  });
}
