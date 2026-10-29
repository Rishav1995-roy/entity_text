import 'package:entity_text/entity_text.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> urls(String s, [UrlMatcher? m]) =>
    (m ?? UrlMatcher()).findAll(s).map((e) => e.text).toList();

void main() {
  group('URL matcher: flutter_linkify / linkify open issues', () {
    test('trailing sentence punctuation is not part of the URL', () {
      expect(urls('See https://example.com.'), ['https://example.com']);
      expect(urls('Is it https://example.com/a?b=1, really?'),
          ['https://example.com/a?b=1']);
      expect(urls('Wow https://example.com/x!!!'), ['https://example.com/x']);
      expect(urls('"https://example.com/x"'), ['https://example.com/x']);
      expect(urls('https://example.com/x?'), ['https://example.com/x']);
    });

    test('URL in parentheses drops only the unbalanced closing one (#126)', () {
      expect(
          urls('(see https://example.com/page)'), ['https://example.com/page']);
      expect(urls('(see https://example.com/page).'),
          ['https://example.com/page']);
      expect(urls('[docs](https://example.com/docs)'),
          ['https://example.com/docs']);
      expect(urls('https://en.wikipedia.org/wiki/Dart_(language)'),
          ['https://en.wikipedia.org/wiki/Dart_(language)']);
      expect(urls('(https://en.wikipedia.org/wiki/Dart_(language))'),
          ['https://en.wikipedia.org/wiki/Dart_(language)']);
    });

    test('unicode hosts and paths (IDN / IRI)', () {
      expect(urls('Go https://münchen.de/straße now'),
          ['https://münchen.de/straße']);
      expect(urls('https://例え.jp/パス'), ['https://例え.jp/パス']);
      expect(urls('www.bücher.de'), ['www.bücher.de']);
      expect(
          urls('https://xn--mnchen-3ya.de/a'), ['https://xn--mnchen-3ya.de/a']);
    });

    test('emoji next to a URL are not swallowed', () {
      expect(
          urls('🎉https://example.com/party🎉'), ['https://example.com/party']);
      expect(
          urls('Link 👉 https://example.com/x 👈'), ['https://example.com/x']);
    });

    test('RTL text and bidi marks around a URL', () {
      expect(
          urls('زر https://example.com/ar، شكرا'), ['https://example.com/ar']);
      expect(
          urls('\u202Bhttps://example.com/a\u202C'), ['https://example.com/a']);
      expect(urls('https://example.com/الع'), ['https://example.com/الع']);
    });

    test('CJK punctuation ends a URL', () {
      expect(urls('网址https://example.com/a。下一句'), ['https://example.com/a']);
    });

    test('newlines are never swallowed or altered (#76)', () {
      const text = 'a https://x.com/a\nhttps://y.com/b\n\nend';
      final found = UrlMatcher().findAll(text).toList();
      expect(found.map((e) => e.text), ['https://x.com/a', 'https://y.com/b']);
      for (final e in found) {
        expect(text.substring(e.start, e.end), e.text);
      }
    });

    test('bare domains, www, ports, query and fragments', () {
      expect(urls('visit example.com/path now'), ['example.com/path']);
      expect(urls('visit example.com.'), ['example.com']);
      expect(urls('localhost:3000 http://localhost:3000/x'),
          ['http://localhost:3000/x']);
      expect(urls('example.com:8080/a'), ['example.com:8080/a']);
      expect(urls('www.example.com/a#frag'), ['www.example.com/a#frag']);
      expect(urls('http://user:pw@example.com/a'),
          ['http://user:pw@example.com/a']);
    });

    test('false positives', () {
      expect(urls('Use file.txt and e.g. Node.js or index.html'), isEmpty);
      expect(urls('mail me at a@example.com'), isEmpty);
      expect(urls('3.14159 is pi, v1.2.3'), isEmpty);
      expect(urls('https://'), isEmpty);
      expect(urls('xhttps://example.com'), isEmpty);
    });

    test('bare domains can be turned off, and TLDs customised', () {
      expect(urls('example.com', UrlMatcher(matchBareDomains: false)), isEmpty);
      expect(urls('x.com https://x.com', UrlMatcher(matchBareDomains: false)),
          ['https://x.com']);
      expect(urls('my.corp', UrlMatcher(tlds: {'corp'})), ['my.corp']);
    });

    test('value gets a scheme; schemes configurable', () {
      final e = UrlMatcher().findAll('www.example.com').single;
      expect(e.value, 'https://www.example.com');
      final f = UrlMatcher().findAll('example.com/a').single;
      expect(f.value, 'https://example.com/a');
      expect(urls('myapp://open/x', UrlMatcher(schemes: {'myapp'})),
          ['myapp://open/x']);
    });

    test('offsets always index the original text', () {
      const text = '🎉 a (https://example.com/x_(y)). b';
      final e = UrlMatcher().findAll(text).single;
      expect(text.substring(e.start, e.end), e.text);
      expect(e.text, 'https://example.com/x_(y)');
    });
  });

  group('email / phone / mention / hashtag', () {
    test('emails', () {
      List<String> em(String s) =>
          const EmailMatcher().findAll(s).map((e) => e.text).toList();
      expect(em('Mail first.last+tag@sub.example.co.uk.'),
          ['first.last+tag@sub.example.co.uk']);
      expect(em('a@b'), isEmpty);
      expect(em('x@münchen.de'), ['x@münchen.de']);
      expect(em('(a@b.com)'), ['a@b.com']);
      expect(const EmailMatcher().findAll('a@b.com').single.value,
          'mailto:a@b.com');
    });

    test('phones', () {
      List<String> ph(String s) =>
          const PhoneMatcher().findAll(s).map((e) => e.text).toList();
      expect(ph('Call +91 98765 43210 now'), ['+91 98765 43210']);
      expect(ph('Call (555) 123-4567.'), ['(555) 123-4567']);
      expect(ph('2024-05-17'), isEmpty);
      expect(ph('order 12345'), isEmpty);
      expect(ph('#12345678'), isEmpty);
      expect(const PhoneMatcher().findAll('+91 98765 43210').single.value,
          'tel:+919876543210');
    });

    test('mentions', () {
      List<String> mn(String s) =>
          MentionMatcher().findAll(s).map((e) => e.text).toList();
      expect(mn('hi @asha_r, @b.c-d! mail a@b.com'), ['@asha_r', '@b.c-d']);
      expect(mn('@名前 と @Ünal'), ['@名前', '@Ünal']);
      expect(mn('@@x'), isEmpty);
    });

    test('hashtags', () {
      List<String> ht(String s) =>
          HashtagMatcher().findAll(s).map((e) => e.text).toList();
      expect(ht('#flutter, #dart_3 #123 &#39; #हिंदी🎉#emoji'),
          ['#flutter', '#dart_3', '#हिंदी', '#emoji']);
      expect(ht('##x'), isEmpty);
    });

    test('RegexEntityMatcher for custom types', () {
      final m = RegexEntityMatcher(
        const EntityType('order'),
        RegExp(r'\bORD-(\d{4,})\b'),
        valueBuilder: (m) => m[1]!,
      );
      final e = m.findAll('see ORD-12345, ORD-1').single;
      expect(e.type, const EntityType('order'));
      expect(e.value, '12345');
      expect(e.text, 'ORD-12345');
    });
  });

  group('EntityParser overlaps', () {
    final parser = EntityParser();
    test('URL swallows mention/hashtag inside it', () {
      final r = parser.parse('x https://medium.com/@me/post#top y');
      expect(r.map((e) => e.type), [EntityType.url]);
    });
    test('email beats mention and domain', () {
      final r = parser.parse('a@example.com');
      expect(r.map((e) => e.type), [EntityType.email]);
    });
    test('mixed text', () {
      const text = 'Hi @asha #fun https://x.com/a, +91 98765 43210 a@b.com';
      final r = parser.parse(text);
      expect(r.map((e) => e.type), [
        EntityType.mention,
        EntityType.hashtag,
        EntityType.url,
        EntityType.phone,
        EntityType.email,
      ]);
      for (final e in r) {
        expect(text.substring(e.start, e.end), e.text);
      }
    });
    test('empty and plain text', () {
      expect(parser.parse(''), isEmpty);
      expect(parser.parse('nothing here'), isEmpty);
    });
    test('long text stays fast', () {
      final text =
          List.filled(4000, 'word https://example.com/a #tag @u').join(' ');
      final sw = Stopwatch()..start();
      final r = parser.parse(text);
      expect(r.length, 4000 * 3);
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });
  });
}
