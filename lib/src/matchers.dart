import 'entity.dart';

/// Finds entities of one [type] in a string.
///
/// Implement this to add your own detection logic, or use
/// [RegexEntityMatcher] for the common case.
abstract class EntityMatcher {
  /// Const constructor for subclasses.
  const EntityMatcher();

  /// The type of the entities this matcher produces.
  EntityType get type;

  /// Returns every entity in [text], in order of appearance and without
  /// overlaps between results of this matcher.
  Iterable<Entity> findAll(String text);
}

/// A matcher driven by a regular expression.
///
/// Build the [RegExp] with `unicode: true` if you use `\p{L}` style classes.
///
/// ```dart
/// RegexEntityMatcher(
///   const EntityType('order'),
///   RegExp(r'\bORD-\d{4,}\b'),
///   valueBuilder: (m) => m[0]!.substring(4),
/// )
/// ```
class RegexEntityMatcher extends EntityMatcher {
  /// Creates a matcher for [type] using [pattern].
  ///
  /// [valueBuilder] computes [Entity.value] (defaults to the matched text).
  /// [validator] can reject a match. [group] selects which capture group is
  /// the entity (0 is the whole match).
  RegexEntityMatcher(
    this.type,
    this.pattern, {
    this.valueBuilder,
    this.validator,
    this.group = 0,
  });

  @override
  final EntityType type;

  /// The pattern to search for.
  final RegExp pattern;

  /// Computes [Entity.value] for a match.
  final String Function(RegExpMatch match)? valueBuilder;

  /// Returns false to discard a match.
  final bool Function(RegExpMatch match)? validator;

  /// The capture group that forms the entity.
  final int group;

  @override
  Iterable<Entity> findAll(String text) sync* {
    for (final m in pattern.allMatches(text)) {
      final matched = m.group(group);
      if (matched == null || matched.isEmpty) continue;
      if (validator != null && !validator!(m)) continue;
      final start = group == 0 ? m.start : text.indexOf(matched, m.start);
      yield Entity(
        type: type,
        start: start,
        end: start + matched.length,
        text: matched,
        value: valueBuilder?.call(m),
      );
    }
  }
}

/// Matches `@name` mentions.
///
/// Names may contain letters of any script, digits, `_`, and `.`/`-` between
/// word characters. An `@` glued to a word (as in an email address) is not a
/// mention.
class MentionMatcher extends RegexEntityMatcher {
  /// Creates a mention matcher.
  MentionMatcher()
      : super(
          EntityType.mention,
          RegExp(
            r'(?<![\p{L}\p{N}\p{M}_@])@([\p{L}\p{N}_](?:[\p{L}\p{N}\p{M}_.\-]*[\p{L}\p{N}\p{M}_])?)',
            unicode: true,
          ),
          valueBuilder: _stripFirst,
        );
}

/// Matches `#hashtag`s in any script.
///
/// A tag must contain at least one letter, so `#1` or `#2024` are not tags,
/// and `&#39;` is not a tag.
class HashtagMatcher extends RegexEntityMatcher {
  /// Creates a hashtag matcher.
  HashtagMatcher()
      : super(
          EntityType.hashtag,
          RegExp(
            r'(?<![\p{L}\p{N}\p{M}_&#])#([\p{L}\p{N}\p{M}_]+)',
            unicode: true,
          ),
          valueBuilder: _stripFirst,
          validator: _hasLetter,
        );

  static bool _hasLetter(RegExpMatch m) =>
      RegExp(r'\p{L}', unicode: true).hasMatch(m.group(1)!);
}

String _stripFirst(RegExpMatch m) => m.group(1)!;

/// Matches email addresses, including internationalised ones.
///
/// The produced [Entity.value] has a `mailto:` prefix.
class EmailMatcher extends EntityMatcher {
  /// Creates an email matcher.
  const EmailMatcher();

  static final RegExp _re = RegExp(
    r'(?<![\p{L}\p{N}_%+\-.])[\p{L}\p{N}_%+\-][\p{L}\p{N}\p{M}_%+\-.]*@(?:[\p{L}\p{N}](?:[\p{L}\p{N}\p{M}\-]*[\p{L}\p{N}\p{M}])?\.)+\p{L}[\p{L}\p{M}]+(?![\p{L}\p{N}\-])',
    unicode: true,
  );

  @override
  EntityType get type => EntityType.email;

  @override
  Iterable<Entity> findAll(String text) sync* {
    for (final m in _re.allMatches(text)) {
      final s = m[0]!;
      if (s.contains('..')) continue;
      final local = s.substring(0, s.indexOf('@'));
      if (local.endsWith('.')) continue;
      yield Entity(
        type: type,
        start: m.start,
        end: m.end,
        text: s,
        value: 'mailto:$s',
      );
    }
  }
}

/// Matches phone numbers written with spaces, hyphens or parentheses.
///
/// A number needs between [minDigits] and [maxDigits] digits. ISO dates and
/// numbers directly after `#`, `@` or `/` are ignored. The produced
/// [Entity.value] is `tel:` followed by the digits (keeping a leading `+`).
class PhoneMatcher extends EntityMatcher {
  /// Creates a phone matcher.
  const PhoneMatcher({this.minDigits = 7, this.maxDigits = 15});

  /// Fewest digits for a match.
  final int minDigits;

  /// Most digits for a match.
  final int maxDigits;

  static final RegExp _re = RegExp(
    r'(?<![\p{L}\p{N}_+\-./#@])(?:\+|00)?(?:\(\d{1,4}\)[ \-]?)?\d+(?:[ \-]?\(?\d+\)?)*(?![\p{L}\p{N}_])',
    unicode: true,
  );

  static final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  EntityType get type => EntityType.phone;

  @override
  Iterable<Entity> findAll(String text) sync* {
    for (final m in _re.allMatches(text)) {
      var s = m[0]!;
      var end = m.end;
      // Drop trailing separators/brackets that are not part of the number.
      while (s.isNotEmpty && !RegExp(r'[\d)]$').hasMatch(s)) {
        s = s.substring(0, s.length - 1);
        end--;
      }
      if (s.endsWith(')') && !s.contains('(')) {
        s = s.substring(0, s.length - 1);
        end--;
      }
      final digits = s.replaceAll(RegExp(r'\D'), '');
      if (digits.length < minDigits || digits.length > maxDigits) continue;
      if (_isoDate.hasMatch(s)) continue;
      final plus = s.startsWith('+') ? '+' : '';
      yield Entity(
        type: type,
        start: m.start,
        end: end,
        text: s,
        value: 'tel:$plus${s.startsWith('00') ? digits.substring(2) : digits}',
      );
    }
  }
}

/// Matches web addresses.
///
/// Compared with a plain regular expression this matcher
///
/// * keeps balanced parentheses that belong to the URL
///   (`https://en.wikipedia.org/wiki/Dart_(language)`) but drops the closing
///   one of `(see https://example.com)`;
/// * drops trailing sentence punctuation (`.,:;!?'"*`);
/// * accepts Unicode (IDN/IRI) hosts and paths (`https://münchen.de/straße`);
/// * stops at emoji, CJK punctuation, bidi control marks and any whitespace,
///   so it never swallows text glued to the URL;
/// * optionally recognises bare domains (`example.com/a`) when the top-level
///   domain is in [tlds].
///
/// The produced [Entity.value] always has a scheme (`https://` is added to
/// `www.` and bare domains).
class UrlMatcher extends EntityMatcher {
  /// Creates a URL matcher.
  UrlMatcher({
    this.matchBareDomains = true,
    Set<String> schemes = const {'http', 'https', 'ftp'},
    Set<String>? tlds,
    this.defaultScheme = 'https',
  })  : schemes = schemes.map((s) => s.toLowerCase()).toSet(),
        tlds = (tlds ?? defaultTlds).map((s) => s.toLowerCase()).toSet() {
    final schemeAlt = this.schemes.map(RegExp.escape).join('|');
    final tldAlt = this.tlds.map(RegExp.escape).join('|');
    const strictBefore = r'(?<![\p{L}\p{N}_@.\-/])';
    final bare = matchBareDomains && this.tlds.isNotEmpty
        ? '|$strictBefore(?<bare>(?:[\\p{L}\\p{N}](?:[\\p{L}\\p{N}\\p{M}\\-]*[\\p{L}\\p{N}\\p{M}])?\\.)+(?:$tldAlt)(?![\\p{L}\\p{N}\\p{M}\\-]))'
        : '|(?<bare>(?!))';
    const asciiBefore = r'(?<![A-Za-z0-9_@.\-/])';
    _re = RegExp(
      '(?:(?<![A-Za-z0-9_])(?<scheme>$schemeAlt)://|$asciiBefore(?<www>www\\.)$bare)',
      unicode: true,
      caseSensitive: false,
    );
  }

  /// Match `example.com/path` without a scheme or `www.`.
  final bool matchBareDomains;

  /// Accepted schemes (lower case, without `://`).
  final Set<String> schemes;

  /// Top-level domains accepted for bare domains.
  final Set<String> tlds;

  /// Scheme added to [Entity.value] when the text has none.
  final String defaultScheme;

  late final RegExp _re;

  /// A conservative list of common top-level domains used for bare domains.
  static const Set<String> defaultTlds = {
    'com',
    'org',
    'net',
    'edu',
    'gov',
    'io',
    'dev',
    'app',
    'co',
    'in',
    'uk',
    'de',
    'fr',
    'jp',
    'cn',
    'ru',
    'br',
    'au',
    'ca',
    'us',
    'eu',
    'info',
    'biz',
    'me',
    'ai',
    'tv',
    'xyz',
    'online',
    'site',
    'store',
    'tech',
    'cloud',
    'page',
    'blog',
    'news',
    'shop',
    'live',
    'ly',
    'nl',
    'ch',
    'pl',
  };

  static final RegExp _hostChars = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final RegExp _wordChar = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);

  // Printable ASCII except whitespace and <>"`\^| ; plus letters, digits and
  // marks of every script (IRIs). Emoji, CJK punctuation and bidi controls
  // are deliberately not included.
  static bool _isUrlChar(int rune, String ch) {
    if (rune < 0x80) {
      if (rune <= 0x20 || rune == 0x7F) return false;
      return !'<>"`\\^|'.contains(ch);
    }
    return _wordChar.hasMatch(ch);
  }

  @override
  EntityType get type => EntityType.url;

  @override
  Iterable<Entity> findAll(String text) sync* {
    var pos = 0;
    while (pos < text.length) {
      final m = _re.allMatches(text, pos).firstOrNull;
      if (m == null) return;
      final isBare = m.namedGroup('bare') != null;
      var end = m.end;
      var scanFrom = m.end;
      if (isBare) {
        final c = end < text.length ? text[end] : '';
        final port = c == ':' &&
            end + 1 < text.length &&
            RegExp(r'\d').hasMatch(text[end + 1]);
        if (!(c == '/' || c == '?' || c == '#' || port)) {
          scanFrom = -1;
        }
      }
      if (scanFrom >= 0) {
        end = _scan(text, scanFrom);
      }
      end = _trim(text, m.start, end);
      if (end > m.start && _valid(text, m, end, isBare)) {
        final s = text.substring(m.start, end);
        yield Entity(
          type: type,
          start: m.start,
          end: end,
          text: s,
          value: m.namedGroup('scheme') != null ? s : '$defaultScheme://$s',
        );
        pos = end;
      } else {
        pos = m.end;
      }
    }
  }

  int _scan(String text, int from) {
    var i = from;
    while (i < text.length) {
      final rune = text.runeAt(i);
      final len = rune > 0xFFFF ? 2 : 1;
      if (!_isUrlChar(rune, String.fromCharCode(rune))) break;
      i += len;
    }
    return i;
  }

  int _trim(String text, int start, int end) {
    var e = end;
    while (e > start) {
      final ch = text[e - 1];
      if ('.,:;!?\'"*'.contains(ch)) {
        e--;
        continue;
      }
      final open = switch (ch) {
        ')' => '(',
        ']' => '[',
        '}' => '{',
        _ => null,
      };
      if (open != null) {
        final seg = text.substring(start, e);
        final opens = open.allMatches(seg).length;
        final closes = ch.allMatches(seg).length;
        if (closes > opens) {
          e--;
          continue;
        }
      }
      break;
    }
    return e;
  }

  bool _valid(String text, RegExpMatch m, int end, bool isBare) {
    final s = text.substring(m.start, end);
    if (isBare) return end >= m.end;
    var rest = s;
    if (m.namedGroup('scheme') != null) {
      rest = s.substring(s.indexOf('://') + 3);
    } else {
      rest = s.substring(4); // after "www."
    }
    var hostEnd = rest.indexOf(RegExp(r'[/?#]'));
    if (hostEnd < 0) hostEnd = rest.length;
    var host = rest.substring(0, hostEnd);
    final at = host.lastIndexOf('@');
    if (at >= 0) host = host.substring(at + 1);
    final colon = host.lastIndexOf(':');
    if (colon >= 0 && !host.startsWith('[')) host = host.substring(0, colon);
    return host.isNotEmpty && _hostChars.hasMatch(host[0]);
  }
}

extension on String {
  int runeAt(int i) {
    final c = codeUnitAt(i);
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < length) {
      final d = codeUnitAt(i + 1);
      if (d >= 0xDC00 && d <= 0xDFFF) {
        return 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00);
      }
    }
    return c;
  }
}
