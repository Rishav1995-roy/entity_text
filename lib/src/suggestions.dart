import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'mention.dart';

/// Loads suggestions for the text typed after a trigger. May be async; a
/// slow response that arrives after the query changed is discarded.
typedef EntitySuggestionsBuilder = FutureOr<List<EntitySuggestion>> Function(
  ActiveQuery query,
);

/// Builds one row of the suggestion list.
typedef EntitySuggestionItemBuilder = Widget Function(
  BuildContext context,
  EntitySuggestion suggestion,
  bool highlighted,
);

/// Where the suggestion list appears relative to the field.
enum EntitySuggestionsPlacement {
  /// Always below the field.
  below,

  /// Always above the field.
  above,

  /// Below unless there is not enough room, then above.
  auto,
}

/// Wraps a text field and shows a suggestion list while the user types after
/// a trigger such as `@`.
///
/// ```dart
/// EntitySuggestions(
///   controller: controller,
///   suggestionsBuilder: (q) => api.searchUsers(q.query),
///   builder: (context, focusNode) =>
///       TextField(controller: controller, focusNode: focusNode),
/// )
/// ```
///
/// On desktop and web the list is driven from the keyboard: arrow up/down
/// move, Enter or Tab choose, Escape closes. The key handler is installed on
/// the [FocusNode] given to [builder], so pass that node to your field.
class EntitySuggestions extends StatefulWidget {
  /// Creates the wrapper.
  const EntitySuggestions({
    super.key,
    required this.controller,
    required this.suggestionsBuilder,
    required this.builder,
    this.itemBuilder,
    this.focusNode,
    this.debounce = const Duration(milliseconds: 120),
    this.maxHeight = 240,
    this.placement = EntitySuggestionsPlacement.auto,
    this.emptyBuilder,
    this.loadingBuilder,
    this.onSelected,
    this.elevation = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  /// The controller whose [EntityTextEditingController.activeQuery] drives
  /// the list.
  final EntityTextEditingController controller;

  /// Provides suggestions for a query.
  final EntitySuggestionsBuilder suggestionsBuilder;

  /// Builds the field. Give the supplied [FocusNode] to it.
  final Widget Function(BuildContext context, FocusNode focusNode) builder;

  /// Custom row; defaults to a compact tile with an initial and the display
  /// name.
  final EntitySuggestionItemBuilder? itemBuilder;

  /// Optional node to use instead of an internally owned one.
  final FocusNode? focusNode;

  /// Wait after the last keystroke before calling [suggestionsBuilder].
  final Duration debounce;

  /// Maximum height of the list.
  final double maxHeight;

  /// Where to put the list.
  final EntitySuggestionsPlacement placement;

  /// Shown when a query yields no results; by default nothing is shown.
  final WidgetBuilder? emptyBuilder;

  /// Shown while loading; by default nothing is shown.
  final WidgetBuilder? loadingBuilder;

  /// Called after a suggestion was applied.
  final void Function(ActiveQuery query, EntitySuggestion suggestion)?
      onSelected;

  /// Elevation of the list surface.
  final double elevation;

  /// Corner radius of the list surface.
  final BorderRadius borderRadius;

  @override
  State<EntitySuggestions> createState() => _EntitySuggestionsState();
}

class _EntitySuggestionsState extends State<EntitySuggestions> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  final _targetKey = GlobalKey();
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  FocusOnKeyEventCallback? _previousKeyHandler;
  FocusNode? _hooked;

  ActiveQuery? _query;
  ActiveQuery? _dismissedFor;
  List<EntitySuggestion> _items = const [];
  bool _loading = false;
  int _highlight = 0;
  int _seq = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _hook();
  }

  void _hook() {
    final node = _node;
    if (identical(_hooked, node)) return;
    _unhook();
    _hooked = node;
    _previousKeyHandler = node.onKeyEvent;
    node.onKeyEvent = _onKey;
    node.addListener(_onChanged);
  }

  void _unhook() {
    final node = _hooked;
    if (node == null) return;
    node.removeListener(_onChanged);
    if (node.onKeyEvent == _onKey) node.onKeyEvent = _previousKeyHandler;
    _hooked = null;
  }

  @override
  void didUpdateWidget(EntitySuggestions old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    _hook();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_onChanged);
    _unhook();
    _ownNode?.dispose();
    super.dispose();
  }

  bool get _visible =>
      _query != null &&
      _query != _dismissedFor &&
      (_items.isNotEmpty ||
          (_loading && widget.loadingBuilder != null) ||
          (!_loading && widget.emptyBuilder != null));

  void _onChanged() {
    final q = _node.hasFocus ? widget.controller.activeQuery : null;
    if (q == _query) return;
    final previous = _query;
    _query = q;
    if (q == null) {
      _timer?.cancel();
      _seq++;
      _items = const [];
      _loading = false;
      _dismissedFor = null;
      _sync();
      return;
    }
    if (previous == null || previous.start != q.start) _dismissedFor = null;
    _timer?.cancel();
    final seq = ++_seq;
    _loading = true;
    _timer = Timer(widget.debounce, () => _load(q, seq));
    _sync();
  }

  Future<void> _load(ActiveQuery q, int seq) async {
    List<EntitySuggestion> result;
    try {
      result = await widget.suggestionsBuilder(q);
    } catch (_) {
      result = const [];
    }
    if (!mounted || seq != _seq) return;
    _items = result;
    _loading = false;
    _highlight = 0;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final show = _visible;
    void apply() {
      if (!mounted) return;
      if (show && !_portal.isShowing) _portal.show();
      if (!show && _portal.isShowing) _portal.hide();
      setState(() {});
    }

    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_visible || _items.isEmpty) {
      return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
    }
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1) % _items.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
          () => _highlight = (_highlight - 1 + _items.length) % _items.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.tab) {
      _select(_items[_highlight]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() => _dismissedFor = _query);
      _sync();
      return KeyEventResult.handled;
    }
    return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  void _select(EntitySuggestion s) {
    final q = _query;
    if (q == null) return;
    widget.controller.applySuggestion(q, s);
    widget.onSelected?.call(q, s);
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _targetKey,
          child: widget.builder(context, _node),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final box = _targetKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box != null && box.hasSize ? box.size.width : 280.0;
    var above = widget.placement == EntitySuggestionsPlacement.above;
    if (widget.placement == EntitySuggestionsPlacement.auto &&
        box != null &&
        box.hasSize) {
      final media = MediaQuery.of(context);
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      final room = media.size.height - media.viewInsets.bottom - bottom;
      above = room < widget.maxHeight && bottom > widget.maxHeight;
    }
    final Widget content;
    if (_items.isEmpty) {
      content = (_loading ? widget.loadingBuilder : widget.emptyBuilder)
              ?.call(context) ??
          const SizedBox.shrink();
    } else {
      content = ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          final highlighted = i == _highlight;
          return _EnsureVisible(
            highlighted: highlighted,
            child: InkWell(
              onTap: () => _select(item),
              child: (widget.itemBuilder ?? _defaultItem)(
                  context, item, highlighted),
            ),
          );
        },
      );
    }
    return TextFieldTapRegion(
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: above ? Alignment.topLeft : Alignment.bottomLeft,
        followerAnchor: above ? Alignment.bottomLeft : Alignment.topLeft,
        offset: Offset(0, above ? -4 : 4),
        child: Align(
          alignment: above ? Alignment.bottomLeft : Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: Material(
              elevation: widget.elevation,
              shape: RoundedRectangleBorder(
                borderRadius: widget.borderRadius,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _defaultItem(
    BuildContext context,
    EntitySuggestion s,
    bool highlighted,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: highlighted ? scheme.primary.withValues(alpha: 0.12) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              s.display.isEmpty ? '?' : s.display.characters.first,
              style: TextStyle(fontSize: 13, color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.display, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (s.subtitle != null)
                  Text(
                    s.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnsureVisible extends StatefulWidget {
  const _EnsureVisible({required this.highlighted, required this.child});

  final bool highlighted;
  final Widget child;

  @override
  State<_EnsureVisible> createState() => _EnsureVisibleState();
}

class _EnsureVisibleState extends State<_EnsureVisible> {
  @override
  void didUpdateWidget(_EnsureVisible old) {
    super.didUpdateWidget(old);
    if (widget.highlighted && !old.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
