import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';

import '../data.dart';

/// A composer: live styling, @mention + #hashtag suggestions, markup output.
class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key, this.controller});

  /// Lets tests and the demo drive the field.
  final EntityTextEditingController? controller;

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  late final EntityTextEditingController _controller =
      widget.controller ?? EntityTextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Write a post', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            'Type @ for people, # for tags. On desktop use the arrow keys, '
            'Enter or Tab, and Esc.',
            style: textTheme.bodySmall),
        const SizedBox(height: 12),
        EntitySuggestions(
          controller: _controller,
          suggestionsBuilder: searchSuggestions,
          builder: (context, node) => TextField(
            key: const ValueKey('composer-field'),
            controller: _controller,
            focusNode: node,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: "What's happening?",
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Stored as structured data', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        _Card(
          label: 'markup',
          child: SelectableText(
              _controller.markup.isEmpty ? '-' : _controller.markup),
        ),
        _Card(
          label: 'mentions',
          child: Text(_controller.mentions.isEmpty
              ? '-'
              : _controller.mentions
                  .map((m) => '${m.trigger}${m.display}  ->  id ${m.id}')
                  .join('\n')),
        ),
        const SizedBox(height: 8),
        Text('Rendered', style: textTheme.titleSmall),
        const SizedBox(height: 6),
        _Card(
          label: 'preview',
          child: EntityText.markup(
            _controller.markup,
            onTap: (e) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('${e.type.name}: ${e.value}')),
              ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
