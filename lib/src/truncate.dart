import 'package:characters/characters.dart';

import 'entity.dart';

/// Moves a proposed cut position so that it never splits an [Entity] or a
/// grapheme cluster (an emoji, a flag, a letter with combining marks).
///
/// [entities] must be sorted and non-overlapping, as returned by
/// `EntityParser.parse`. The result is `<= cut`, except when the text starts
/// with an entity that is itself longer than [cut]: then the whole entity is
/// kept (cut moves forward to its end) so that something readable remains.
/// Trailing whitespace before the cut is removed.
int snapCut(String text, List<Entity> entities, int cut) {
  if (cut >= text.length) return text.length;
  if (cut <= 0) return 0;
  var c = cut;
  for (final e in entities) {
    if (e.start < c && c < e.end) {
      c = e.start;
      if (c == 0) return e.end;
      break;
    }
    if (e.start >= c) break;
  }
  c = _graphemeBoundaryAtOrBefore(text, c);
  while (c > 0 && _isSpace(text.codeUnitAt(c - 1))) {
    c--;
  }
  return c;
}

bool _isSpace(int unit) =>
    unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x0D;

int _graphemeBoundaryAtOrBefore(String text, int offset) {
  if (offset <= 0) return 0;
  if (offset >= text.length) return text.length;
  // Look back a bounded window; grapheme clusters are short.
  final from = offset > 64 ? offset - 64 : 0;
  var windowStart = from;
  // Do not start inside a surrogate pair.
  if (windowStart > 0 &&
      text.codeUnitAt(windowStart) >= 0xDC00 &&
      text.codeUnitAt(windowStart) <= 0xDFFF) {
    windowStart--;
  }
  var pos = windowStart;
  for (final g in text.substring(windowStart).characters) {
    final next = pos + g.length;
    if (next > offset) return pos;
    pos = next;
    if (pos == offset) return offset;
  }
  return pos;
}

/// Returns the end offset of a collapsed preview of [text] that is at most
/// about [maxLength] UTF-16 code units long without splitting entities or
/// graphemes, or `null` when the whole text fits.
int? collapsedLengthCut(String text, List<Entity> entities, int maxLength) {
  if (text.length <= maxLength) return null;
  return snapCut(text, entities, maxLength);
}
