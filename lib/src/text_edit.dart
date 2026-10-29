import 'package:flutter/services.dart';

/// The change between two versions of a text: the range `[start, oldEnd)` of
/// the old text was replaced by [insertedLength] new code units.
class TextEdit {
  /// Creates an edit.
  const TextEdit(this.start, this.oldEnd, this.insertedLength);

  /// First changed offset (same in the old and the new text).
  final int start;

  /// End of the replaced range in the old text.
  final int oldEnd;

  /// Length of the inserted text.
  final int insertedLength;

  /// Change in total length.
  int get delta => insertedLength - (oldEnd - start);

  /// Whether the edit only removes text.
  bool get isDeletion => insertedLength == 0 && oldEnd > start;

  /// Whether the edit only inserts text.
  bool get isInsertion => oldEnd == start && insertedLength > 0;

  /// Works out what changed between [old] and [value]. The caret in
  /// [value] disambiguates repeated characters (deleting one `a` of `aaa`).
  static TextEdit? compute(String old, TextEditingValue value) {
    final next = value.text;
    if (old == next) return null;
    final sel = value.selection;
    final delta = next.length - old.length;
    if (sel.isValid && sel.isCollapsed) {
      final c = sel.baseOffset;
      if (delta < 0 && c >= 0 && c + (-delta) <= old.length) {
        final k = -delta;
        if (old.substring(0, c) + old.substring(c + k) == next) {
          return TextEdit(c, c + k, 0);
        }
      } else if (delta > 0 && c - delta >= 0 && c <= next.length) {
        final s = c - delta;
        if (next.substring(0, s) + next.substring(c) ==
            old.substring(0, s) + old.substring(s)) {
          return TextEdit(s, s, delta);
        }
      }
    }
    var p = 0;
    final minLen = old.length < next.length ? old.length : next.length;
    while (p < minLen && old.codeUnitAt(p) == next.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p &&
        old.codeUnitAt(old.length - 1 - s) ==
            next.codeUnitAt(next.length - 1 - s)) {
      s++;
    }
    return TextEdit(p, old.length - s, next.length - p - s);
  }
}
