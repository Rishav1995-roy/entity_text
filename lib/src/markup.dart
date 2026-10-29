import 'mention.dart';

/// Converts text plus structured [Mention]s to and from a plain string.
///
/// The format is `@[Display](id)`: the trigger character, the display name in
/// square brackets and the id in parentheses. `\` escapes `\`, `[`, `]`, `(`
/// and `)` where needed, so any text round-trips:
/// `decode(encode(text, mentions))` returns the same text and mentions.
///
/// ```dart
/// EntityMarkup.encode('Hi @Asha!', [Mention(id: 'u1', display: 'Asha', start: 3)]);
/// // Hi @[Asha](u1)!
/// ```
class EntityMarkup {
  EntityMarkup._();

  /// The default trigger characters recognised when decoding.
  static const String defaultTriggers = '@#';

  /// Serialises [text] and [mentions] (sorted, non-overlapping, each matching
  /// the text at its range) into markup.
  static String encode(
    String text,
    List<Mention> mentions, {
    String triggers = defaultTriggers,
  }) {
    final sorted = [...mentions]..sort((a, b) => a.start.compareTo(b.start));
    final out = StringBuffer();
    var pos = 0;
    for (final m in sorted) {
      if (m.start < pos || m.end > text.length) continue;
      _writePlain(out, text.substring(pos, m.start), triggers);
      out
        ..write(m.trigger)
        ..write('[')
        ..write(_escape(m.display, ']'))
        ..write('](')
        ..write(_escape(m.id, ')'))
        ..write(')');
      pos = m.end;
    }
    _writePlain(out, text.substring(pos), triggers);
    return out.toString();
  }

  static void _writePlain(StringBuffer out, String s, String triggers) {
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == r'\') {
        out.write(r'\\');
      } else if (c == '[' && i > 0 && triggers.contains(s[i - 1])) {
        out.write(r'\[');
      } else {
        out.write(c);
      }
    }
  }

  static String _escape(String s, String closer) =>
      s.replaceAll(r'\', r'\\').replaceAll(closer, '\\$closer');

  /// Parses [markup] into plain text and the mentions it contained.
  ///
  /// Malformed mention syntax is kept as literal text.
  static ({String text, List<Mention> mentions}) decode(
    String markup, {
    String triggers = defaultTriggers,
  }) {
    final out = StringBuffer();
    final mentions = <Mention>[];
    var i = 0;
    while (i < markup.length) {
      final c = markup[i];
      if (c == r'\' && i + 1 < markup.length && r'\['.contains(markup[i + 1])) {
        out.write(markup[i + 1]);
        i += 2;
        continue;
      }
      if (triggers.contains(c) &&
          i + 1 < markup.length &&
          markup[i + 1] == '[') {
        final parsed = _parseMention(markup, i, c);
        if (parsed != null) {
          mentions.add(Mention(
            id: parsed.id,
            display: parsed.display,
            start: out.length,
            trigger: c,
          ));
          out
            ..write(c)
            ..write(parsed.display);
          i = parsed.next;
          continue;
        }
      }
      out.write(c);
      i++;
    }
    return (text: out.toString(), mentions: mentions);
  }

  static ({String display, String id, int next})? _parseMention(
      String s, int at, String trigger) {
    final display = StringBuffer();
    var i = at + 2;
    var closed = false;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length) {
        display.write(s[i + 1]);
        i += 2;
      } else if (c == ']') {
        closed = true;
        i++;
        break;
      } else {
        display.write(c);
        i++;
      }
    }
    if (!closed || i >= s.length || s[i] != '(') return null;
    i++;
    final id = StringBuffer();
    closed = false;
    while (i < s.length) {
      final c = s[i];
      if (c == r'\' && i + 1 < s.length) {
        id.write(s[i + 1]);
        i += 2;
      } else if (c == ')') {
        closed = true;
        i++;
        break;
      } else {
        id.write(c);
        i++;
      }
    }
    if (!closed || display.isEmpty) return null;
    return (display: display.toString(), id: id.toString(), next: i);
  }
}
