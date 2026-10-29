import 'package:flutter/material.dart';

import 'entity.dart';
import 'markup.dart';
import 'matchers.dart';
import 'mention.dart';
import 'parser.dart';
import 'styles.dart';
import 'text_edit.dart';

/// A [TextEditingController] that styles entities while the user types and
/// keeps structured [Mention]s in sync with the text.
///
/// * Hashtags, URLs and whatever else [matchers] find are styled live.
/// * Typing a trigger such as `@` exposes [activeQuery]; an
///   `EntitySuggestions` widget (or your own UI) offers choices and calls
///   [applySuggestion], which stores the pick as a [Mention] with an id.
/// * Mentions move with the text, are deleted as a unit by backspace, and
///   dissolve into plain text when typed into.
/// * [markup] / [setMarkup] serialise text and mentions to `@[Name](id)`.
class EntityTextEditingController extends TextEditingController {
  /// Creates a controller.
  ///
  /// [mentions] must match [text] at their ranges; mismatching ones are
  /// ignored. [matchers] default to email, URL and hashtag detection. Style
  /// lookups use [styles], falling back to [EntityStyles.fallback].
  EntityTextEditingController({
    super.text,
    List<Mention> mentions = const [],
    List<EntityTrigger>? triggers,
    List<EntityMatcher>? matchers,
    Map<EntityType, TextStyle>? styles,
  })  : triggers = triggers ??
            const [EntityTrigger.mention(), EntityTrigger.hashtag()],
        styles = styles ?? const {},
        _parser = EntityParser(matchers ??
            [const EmailMatcher(), UrlMatcher(), HashtagMatcher()]) {
    _mentions = _validated(text, mentions);
  }

  /// Creates a controller from [markup] produced by [EntityMarkup.encode].
  factory EntityTextEditingController.fromMarkup(
    String markup, {
    List<EntityTrigger>? triggers,
    List<EntityMatcher>? matchers,
    Map<EntityType, TextStyle>? styles,
  }) {
    final d = EntityMarkup.decode(markup);
    return EntityTextEditingController(
      text: d.text,
      mentions: d.mentions,
      triggers: triggers,
      matchers: matchers,
      styles: styles,
    );
  }

  /// Characters that open suggestions.
  final List<EntityTrigger> triggers;

  /// Per-type styles, overriding the defaults. Assign a new map and call
  /// [notifyListeners] (or rebuild) to restyle.
  Map<EntityType, TextStyle> styles;

  final EntityParser _parser;
  late List<Mention> _mentions;
  bool _internal = false;

  /// The structured mentions currently in the text, sorted by position.
  List<Mention> get mentions => List.unmodifiable(_mentions);

  /// The text with mentions written as `@[Name](id)`.
  String get markup =>
      EntityMarkup.encode(text, _mentions, triggers: _triggerChars);

  String get _triggerChars => triggers.map((t) => t.char).join();

  /// Replaces text and mentions with those in [markup].
  void setMarkup(String markup) {
    final d = EntityMarkup.decode(markup, triggers: _triggerChars);
    _internal = true;
    try {
      value = TextEditingValue(
        text: d.text,
        selection: TextSelection.collapsed(offset: d.text.length),
      );
    } finally {
      _internal = false;
    }
    _mentions = _validated(d.text, d.mentions);
    notifyListeners();
  }

  /// Entities in the current text: structured mentions plus whatever the
  /// matchers detect outside them.
  List<Entity> get entities => _entitiesFor(text);

  List<Entity> _entitiesFor(String t) {
    final result = <Entity>[
      for (final m in _mentions) m.toEntity(),
    ];
    for (final e in _parser.parse(t)) {
      final clash = _mentions.any((m) => e.start < m.end && e.end > m.start);
      if (!clash) result.add(e);
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  /// The trigger query at the caret, or `null`.
  ///
  /// For `Hi @as|` this is `ActiveQuery(@as)`. It is `null` when the caret
  /// is not collapsed, is inside a [Mention], or the `@` is glued to a word.
  ActiveQuery? get activeQuery {
    final sel = selection;
    if (!sel.isValid || !sel.isCollapsed) return null;
    final c = sel.baseOffset;
    final t = text;
    if (c < 0 || c > t.length) return null;
    var j = c - 1;
    var sawSpace = false;
    while (j >= 0) {
      final ch = t[j];
      if (ch == '\n') return null;
      EntityTrigger? hit;
      for (final tr in triggers) {
        if (tr.char == ch) hit = tr;
      }
      if (hit != null) {
        final qLen = c - j - 1;
        if (qLen > hit.maxQueryLength) return null;
        if (sawSpace && !hit.allowSpaces) return null;
        final before = j == 0 ? ' ' : t[j - 1];
        if (!RegExp(r'[\s(\[{"' "'" r']').hasMatch(before)) return null;
        final query = t.substring(j + 1, c);
        if (query.startsWith(' ')) return null;
        if (_mentions.any((m) => j >= m.start && j < m.end)) return null;
        return ActiveQuery(trigger: hit, query: query, start: j, end: c);
      }
      if (ch == ' ' || ch == '\t') sawSpace = true;
      if (c - j > 60) return null;
      j--;
    }
    return null;
  }

  /// Inserts [suggestion] in place of [query].
  ///
  /// For a structured trigger the text becomes `@Display ` and a [Mention] is
  /// recorded; otherwise plain text `#display ` is inserted. A space is
  /// appended unless [addSpace] is false or one already follows.
  void applySuggestion(
    ActiveQuery query,
    EntitySuggestion suggestion, {
    bool addSpace = true,
  }) {
    final t = text;
    if (query.start < 0 || query.end > t.length) return;
    final inserted = '${query.trigger.char}${suggestion.display}';
    final needsSpace =
        addSpace && !(query.end < t.length && t[query.end] == ' ');
    final replacement = needsSpace ? '$inserted ' : inserted;
    final newText = t.replaceRange(query.start, query.end, replacement);
    final delta = replacement.length - (query.end - query.start);
    final next = <Mention>[];
    for (final m in _mentions) {
      if (m.end <= query.start) {
        next.add(m);
      } else if (m.start >= query.end) {
        next.add(m.copyWith(start: m.start + delta));
      }
    }
    if (query.trigger.structured) {
      next.add(Mention(
        id: suggestion.id,
        display: suggestion.display,
        start: query.start,
        trigger: query.trigger.char,
      ));
      next.sort((a, b) => a.start.compareTo(b.start));
    }
    _internal = true;
    try {
      value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: query.start + replacement.length,
        ),
      );
    } finally {
      _internal = false;
    }
    _mentions = next;
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    if (_internal || _mentions.isEmpty) {
      super.value = newValue;
      return;
    }
    final old = super.value.text;
    final edit = TextEdit.compute(old, newValue);
    if (edit == null) {
      super.value = newValue;
      return;
    }
    var start = edit.start;
    var oldEnd = edit.oldEnd;
    final kept = <Mention>[];
    var touched = <Mention>[];
    bool hits(Mention m) => edit.isInsertion
        ? m.start < start && start < m.end
        : m.start < oldEnd && m.end > start;

    if (edit.isDeletion) {
      // Grow the deleted range until it covers whole mentions.
      var changed = true;
      while (changed) {
        changed = false;
        for (final m in _mentions) {
          if (m.start < oldEnd &&
              m.end > start &&
              (m.start < start || m.end > oldEnd)) {
            start = m.start < start ? m.start : start;
            oldEnd = m.end > oldEnd ? m.end : oldEnd;
            changed = true;
          }
        }
      }
      touched =
          _mentions.where((m) => m.start < oldEnd && m.end > start).toList();
      for (final m in _mentions) {
        if (touched.contains(m)) continue;
        kept.add(m.start >= oldEnd
            ? m.copyWith(start: m.start - (oldEnd - start))
            : m);
      }
      final adjusted = old.replaceRange(start, oldEnd, '');
      _mentions = kept;
      super.value = TextEditingValue(
        text: adjusted,
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    for (final m in _mentions) {
      if (hits(m)) {
        touched.add(m);
      } else if (m.start >= oldEnd) {
        kept.add(m.copyWith(start: m.start + edit.delta));
      } else {
        kept.add(m);
      }
    }
    _mentions = kept;
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    final ranges = <(int, int, TextStyle)>[];
    for (final e in _entitiesFor(t)) {
      final s = styles[e.type] ?? EntityStyles.fallback[e.type];
      if (s != null) ranges.add((e.start, e.end, s));
    }
    final q = activeQuery;
    if (q != null && !ranges.any((r) => r.$1 <= q.start && q.start < r.$2)) {
      final s = styles[q.trigger.effectiveType] ??
          EntityStyles.fallback[q.trigger.effectiveType];
      if (s != null) ranges.add((q.start, q.end, s));
      ranges.sort((a, b) => a.$1.compareTo(b.$1));
    }
    final comp = value.composing;
    final hasComposing = withComposing && value.isComposingRangeValid;
    final cuts = <int>{0, t.length};
    for (final r in ranges) {
      cuts
        ..add(r.$1)
        ..add(r.$2);
    }
    if (hasComposing) {
      cuts
        ..add(comp.start)
        ..add(comp.end);
    }
    final sorted =
        (cuts.where((c) => c >= 0 && c <= t.length).toList()..sort());
    final children = <InlineSpan>[];
    final base = style ?? const TextStyle();
    for (var i = 0; i + 1 < sorted.length; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (a == b) continue;
      TextStyle? s;
      for (final r in ranges) {
        if (r.$1 <= a && b <= r.$2) s = r.$3;
      }
      if (hasComposing && comp.start <= a && b <= comp.end) {
        s = (s ?? const TextStyle()).merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(TextSpan(text: t.substring(a, b), style: s));
    }
    return TextSpan(style: base, children: children);
  }

  static List<Mention> _validated(String text, List<Mention> mentions) {
    final sorted = [...mentions]..sort((a, b) => a.start.compareTo(b.start));
    final out = <Mention>[];
    var last = 0;
    for (final m in sorted) {
      if (m.start < last || m.end > text.length) continue;
      if (text.substring(m.start, m.end) != m.text) continue;
      out.add(m);
      last = m.end;
    }
    return out;
  }
}
