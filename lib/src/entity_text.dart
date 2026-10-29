import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import 'entity.dart';
import 'markup.dart';
import 'matchers.dart';
import 'mention.dart';
import 'parser.dart';
import 'styles.dart';
import 'truncate.dart';

/// Signature of a callback that receives a tapped [Entity].
typedef EntityCallback = void Function(Entity entity);

/// Builds the span for one entity. [style] is the resolved style and
/// [recognizer] is the gesture recogniser wired to the tap and long-press
/// callbacks (null when neither callback is set).
typedef EntitySpanBuilder = InlineSpan Function(
  BuildContext context,
  Entity entity,
  TextStyle style,
  GestureRecognizer? recognizer,
);

/// Rich text that finds URLs, emails, phone numbers, mentions, hashtags and
/// custom entities, and makes them tappable.
///
/// * Works inside a `SelectionArea` / `SelectableRegion`, or set [selectable]
///   to make this widget selectable on its own. Tapping an entity and
///   selecting text do not interfere.
/// * [onTap] and [onLongPress] receive the [Entity].
/// * [collapsedMaxLines] / [collapsedMaxLength] add a "Read more" toggle that
///   never cuts through an entity or an emoji.
/// * Structured mentions can be supplied through [mentions] or
///   [EntityText.markup].
class EntityText extends StatefulWidget {
  /// Creates an entity text.
  const EntityText(
    this.text, {
    super.key,
    this.matchers,
    this.mentions = const [],
    this.style,
    this.entityStyles,
    this.styleBuilder,
    this.spanBuilder,
    this.onTap,
    this.onLongPress,
    this.selectable = false,
    this.onSelectionChanged,
    this.textAlign,
    this.textDirection,
    this.softWrap = true,
    this.strutStyle,
    this.locale,
    this.collapsedMaxLines,
    this.collapsedMaxLength,
    this.ellipsis = '…',
    this.readMoreLabel = 'Read more',
    this.readLessLabel = 'Read less',
    this.toggleStyle,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
  });

  /// Creates an entity text from [markup] written by [EntityMarkup.encode]
  /// (`@[Asha](u1)`); mentions become entities whose [Entity.value] is the id
  /// and whose [Entity.data] is the [Mention].
  factory EntityText.markup(
    String markup, {
    Key? key,
    String triggers = EntityMarkup.defaultTriggers,
    List<EntityMatcher>? matchers,
    TextStyle? style,
    Map<EntityType, TextStyle>? entityStyles,
    TextStyle? Function(Entity entity, TextStyle defaultStyle)? styleBuilder,
    EntitySpanBuilder? spanBuilder,
    EntityCallback? onTap,
    EntityCallback? onLongPress,
    bool selectable = false,
    TextAlign? textAlign,
    TextDirection? textDirection,
    int? collapsedMaxLines,
    int? collapsedMaxLength,
    String readMoreLabel = 'Read more',
    String? readLessLabel = 'Read less',
    TextStyle? toggleStyle,
  }) {
    final d = EntityMarkup.decode(markup, triggers: triggers);
    return EntityText(
      d.text,
      key: key,
      mentions: d.mentions,
      matchers: matchers,
      style: style,
      entityStyles: entityStyles,
      styleBuilder: styleBuilder,
      spanBuilder: spanBuilder,
      onTap: onTap,
      onLongPress: onLongPress,
      selectable: selectable,
      textAlign: textAlign,
      textDirection: textDirection,
      collapsedMaxLines: collapsedMaxLines,
      collapsedMaxLength: collapsedMaxLength,
      readMoreLabel: readMoreLabel,
      readLessLabel: readLessLabel,
      toggleStyle: toggleStyle,
    );
  }

  /// The text to display.
  final String text;

  /// Which matchers to use; defaults to [EntityParser.defaultMatchers].
  /// Pass a stable (for example `const` or cached) list: a new list instance
  /// triggers a re-parse.
  final List<EntityMatcher>? matchers;

  /// Structured mentions at known ranges of [text]. Mismatching ones are
  /// ignored.
  final List<Mention> mentions;

  /// Base style, merged over the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Styles per type, merged over the theme-derived defaults.
  final Map<EntityType, TextStyle>? entityStyles;

  /// Final say on an entity's style. Return `null` to keep [defaultStyle].
  final TextStyle? Function(Entity entity, TextStyle defaultStyle)?
      styleBuilder;

  /// Replaces the default `TextSpan` for entities, for example to return a
  /// `WidgetSpan` chip.
  final EntitySpanBuilder? spanBuilder;

  /// Called when an entity is tapped.
  final EntityCallback? onTap;

  /// Called when an entity is long-pressed.
  final EntityCallback? onLongPress;

  /// Makes this text selectable by itself. Not needed inside a
  /// `SelectionArea`.
  final bool selectable;

  /// Reports the selected text when [selectable] is true (for a surrounding
  /// `SelectionArea` use its own callback).
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  /// See [Text.textAlign].
  final TextAlign? textAlign;

  /// See [Text.textDirection].
  final TextDirection? textDirection;

  /// See [Text.softWrap].
  final bool softWrap;

  /// See [Text.strutStyle].
  final StrutStyle? strutStyle;

  /// See [Text.locale].
  final Locale? locale;

  /// Collapse to this many lines with a "Read more" toggle.
  final int? collapsedMaxLines;

  /// Collapse to about this many UTF-16 code units with a toggle.
  final int? collapsedMaxLength;

  /// Shown at the cut when collapsed.
  final String ellipsis;

  /// Label of the expand toggle.
  final String readMoreLabel;

  /// Label of the collapse toggle; `null` hides it.
  final String? readLessLabel;

  /// Style of the toggle labels; defaults to the mention style.
  final TextStyle? toggleStyle;

  /// Whether to start expanded.
  final bool initiallyExpanded;

  /// Called when the user toggles expansion.
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<EntityText> createState() => _EntityTextState();
}

class _EntityTextState extends State<EntityText> {
  EntityParser? _parser;
  List<Entity> _entities = const [];
  String? _parsedText;
  List<EntityMatcher>? _parsedMatchers;
  List<Mention>? _parsedMentions;
  late bool _expanded = widget.initiallyExpanded;
  final List<GestureRecognizer> _recognizers = [];
  ({
    double width,
    String text,
    int? lines,
    int? length,
    TextStyle? style,
    double scale
  })? _cutKey;
  int? _cut;

  bool get _collapsible =>
      widget.collapsedMaxLines != null || widget.collapsedMaxLength != null;

  void _parse() {
    if (_parsedText == widget.text &&
        identical(_parsedMatchers, widget.matchers) &&
        identical(_parsedMentions, widget.mentions)) {
      return;
    }
    if (!identical(_parsedMatchers, widget.matchers) || _parser == null) {
      _parser = EntityParser(widget.matchers);
    }
    final mentions = [
      for (final m in widget.mentions)
        if (m.end <= widget.text.length &&
            widget.text.substring(m.start, m.end) == m.text)
          m,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final result = <Entity>[for (final m in mentions) m.toEntity()];
    for (final e in _parser!.parse(widget.text)) {
      if (!mentions.any((m) => e.start < m.end && e.end > m.start)) {
        result.add(e);
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    _entities = result;
    _parsedText = widget.text;
    _parsedMatchers = widget.matchers;
    _parsedMentions = widget.mentions;
    _cutKey = null;
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  TextStyle _styleFor(
      BuildContext context, Entity e, Map<EntityType, TextStyle> defaults) {
    var s = defaults[e.type] ?? const TextStyle();
    final custom = widget.entityStyles?[e.type];
    if (custom != null) s = s.merge(custom);
    return widget.styleBuilder?.call(e, s) ?? s;
  }

  GestureRecognizer? _recognizerFor(Entity e, bool live) {
    if (!live || (widget.onTap == null && widget.onLongPress == null)) {
      return null;
    }
    // A recogniser that has no callback would still compete in the gesture
    // arena, so build exactly what is needed.
    GestureRecognizer r;
    if (widget.onLongPress != null && widget.onTap != null) {
      // Tap and long press are different recognisers; a span holds one.
      // Use a long-press recogniser plus a tap recogniser inside a
      // combined recogniser.
      r = _TapAndLongPressRecognizer(
        onTap: () => widget.onTap!(e),
        onLongPress: () => widget.onLongPress!(e),
      );
    } else if (widget.onTap != null) {
      r = TapGestureRecognizer()..onTap = () => widget.onTap!(e);
    } else {
      r = LongPressGestureRecognizer()
        ..onLongPress = () => widget.onLongPress!(e);
    }
    _recognizers.add(r);
    return r;
  }

  List<InlineSpan> _spans(
    BuildContext context,
    int end,
    Map<EntityType, TextStyle> defaults,
    bool live,
  ) {
    final text = widget.text;
    final spans = <InlineSpan>[];
    var pos = 0;
    for (final e in _entities) {
      if (e.end > end) break;
      if (e.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, e.start)));
      }
      final style = _styleFor(context, e, defaults);
      final rec = _recognizerFor(e, live);
      spans.add(widget.spanBuilder?.call(context, e, style, rec) ??
          TextSpan(text: e.text, style: style, recognizer: rec));
      pos = e.end;
    }
    if (pos < end) spans.add(TextSpan(text: text.substring(pos, end)));
    return spans;
  }

  void _toggle(bool expand) {
    setState(() => _expanded = expand);
    widget.onExpandedChanged?.call(expand);
  }

  @override
  void didUpdateWidget(EntityText old) {
    super.didUpdateWidget(old);
    if (old.collapsedMaxLines != widget.collapsedMaxLines ||
        old.collapsedMaxLength != widget.collapsedMaxLength) {
      _cutKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _parse();
    final theme = Theme.of(context);
    final defaults = EntityStyles.fromTheme(theme);
    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    const live = true;

    Widget buildText(List<InlineSpan> children) {
      final span = TextSpan(style: widget.style, children: children);
      if (widget.selectable) {
        return SelectionArea(
          onSelectionChanged: widget.onSelectionChanged,
          child: Text.rich(
            span,
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            softWrap: widget.softWrap,
            strutStyle: widget.strutStyle,
            locale: widget.locale,
          ),
        );
      }
      return Text.rich(
        span,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
        softWrap: widget.softWrap,
        strutStyle: widget.strutStyle,
        locale: widget.locale,
      );
    }

    if (!_collapsible) {
      _disposeRecognizers();
      return buildText(_spans(context, widget.text.length, defaults, live));
    }

    final toggleStyle = widget.toggleStyle ??
        (defaults[EntityType.mention] ?? const TextStyle());

    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      _disposeRecognizers();
      final collapsedCut =
          _computeCut(context, constraints.maxWidth, base, scale, defaults);
      final cut = _expanded ? null : collapsedCut;
      if (cut == null) {
        final children = _spans(context, widget.text.length, defaults, live);
        if (_expanded && widget.readLessLabel != null && collapsedCut != null) {
          children.add(const TextSpan(text: ' '));
          children.add(TextSpan(
            text: widget.readLessLabel,
            style: toggleStyle,
            recognizer: _toggleRecognizer(false),
          ));
        }
        return buildText(children);
      }
      final children = _spans(context, cut, defaults, live)
        ..add(TextSpan(text: widget.ellipsis))
        ..add(const TextSpan(text: ' '))
        ..add(TextSpan(
          text: widget.readMoreLabel,
          style: toggleStyle,
          recognizer: _toggleRecognizer(true),
        ));
      return buildText(children);
    });
  }

  GestureRecognizer _toggleRecognizer(bool expand) {
    final r = TapGestureRecognizer()..onTap = () => _toggle(expand);
    _recognizers.add(r);
    return r;
  }

  int? _computeCut(
    BuildContext context,
    double width,
    TextStyle base,
    double scale,
    Map<EntityType, TextStyle> defaults,
  ) {
    final key = (
      width: width,
      text: widget.text,
      lines: widget.collapsedMaxLines,
      length: widget.collapsedMaxLength,
      style: base,
      scale: scale,
    );
    if (_cutKey == key) return _cut;
    int? cut;
    var limit = widget.text.length;
    final byLength = widget.collapsedMaxLength;
    if (byLength != null) {
      cut = collapsedLengthCut(widget.text, _entities, byLength);
      if (cut != null) limit = cut;
    }
    final lines = widget.collapsedMaxLines;
    if (lines != null) {
      final direction = widget.textDirection ?? Directionality.of(context);
      bool fits(int c, bool withSuffix) {
        final children = _spans(context, c, defaults, false);
        if (withSuffix) {
          children.add(
              TextSpan(text: '${widget.ellipsis} ${widget.readMoreLabel}'));
        }
        final painter = TextPainter(
          text: TextSpan(style: base, children: children),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: lines,
          strutStyle: widget.strutStyle,
          locale: widget.locale,
        )..layout(maxWidth: width);
        final ok = !painter.didExceedMaxLines;
        painter.dispose();
        return ok;
      }

      if (cut == null && fits(widget.text.length, false)) {
        cut = null;
      } else {
        var lo = 0;
        var hi = limit;
        while (lo < hi) {
          final mid = (lo + hi + 1) >> 1;
          final snapped = snapCut(widget.text, _entities, mid);
          if (fits(snapped, true)) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        cut = snapCut(widget.text, _entities, lo);
      }
    }
    _cutKey = key;
    _cut = cut;
    return cut;
  }
}

/// A single recogniser that reports both taps and long presses of a span.
///
/// A long press wins the gesture arena, so an enclosing selection area does
/// not start selecting when the user long-presses an entity.
class _TapAndLongPressRecognizer extends TapGestureRecognizer {
  _TapAndLongPressRecognizer({
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) : _onLongPress = onLongPress {
    this.onTap = () {
      if (!_fired) onTap();
    };
  }

  final VoidCallback _onLongPress;
  Timer? _timer;
  bool _fired = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _fired = false;
    _timer?.cancel();
    _timer = Timer(kLongPressTimeout, () {
      _fired = true;
      resolve(GestureDisposition.accepted);
      _onLongPress();
    });
    super.addAllowedPointer(event);
  }

  @override
  void handlePrimaryPointer(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _timer?.cancel();
    }
    super.handlePrimaryPointer(event);
  }

  @override
  void rejectGesture(int pointer) {
    _timer?.cancel();
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
