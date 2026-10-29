import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';

/// Edge cases, toggles for matchers, and a theming panel.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  final _text = TextEditingController(
    text: 'Docs (https://en.wikipedia.org/wiki/Dart_(language)) and '
        'https://example.com/a?b=1, then https://münchen.de/straße. '
        '\u{1F389}https://example.com/party\u{1F389} '
        'Mail me@example.com or +1 (555) 123-4567. @asha #flutter\n'
        'Bare domain: example.com/path',
  );
  final _enabled = {...EntityParser.defaultMatchers().map((m) => m.type)};
  bool _bare = true;
  bool _underline = true;
  bool _chips = false;
  double _hue = 220;

  List<EntityMatcher> get _matchers => [
        const EmailMatcher(),
        UrlMatcher(matchBareDomains: _bare),
        const PhoneMatcher(),
        MentionMatcher(),
        HashtagMatcher(),
      ].where((m) => _enabled.contains(m.type)).toList();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = HSLColor.fromAHSL(1, _hue, 0.7, 0.45).toColor();
    final styles = <EntityType, TextStyle>{
      for (final t in [EntityType.url, EntityType.email, EntityType.phone])
        t: TextStyle(
          color: color,
          decoration:
              _underline ? TextDecoration.underline : TextDecoration.none,
        ),
      EntityType.mention: TextStyle(color: color, fontWeight: FontWeight.bold),
      EntityType.hashtag: TextStyle(color: color, fontStyle: FontStyle.italic),
    };
    final entities = EntityParser(_matchers).parse(_text.text);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Try your own text',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final t in [
              EntityType.url,
              EntityType.email,
              EntityType.phone,
              EntityType.mention,
              EntityType.hashtag,
            ])
              FilterChip(
                label: Text(t.name),
                selected: _enabled.contains(t),
                onSelected: (v) =>
                    setState(() => v ? _enabled.add(t) : _enabled.remove(t)),
              ),
            FilterChip(
              label: const Text('bare domains'),
              selected: _bare,
              onSelected: (v) => setState(() => _bare = v),
            ),
            FilterChip(
              label: const Text('underline'),
              selected: _underline,
              onSelected: (v) => setState(() => _underline = v),
            ),
            FilterChip(
              label: const Text('chips (spanBuilder)'),
              selected: _chips,
              onSelected: (v) => setState(() => _chips = v),
            ),
          ],
        ),
        Row(
          children: [
            const Text('Hue'),
            Expanded(
              child: Slider(
                min: 0,
                max: 360,
                value: _hue,
                onChanged: (v) => setState(() => _hue = v),
              ),
            ),
          ],
        ),
        const Divider(),
        SelectionArea(
          child: EntityText(
            _text.text,
            matchers: _matchers,
            entityStyles: styles,
            spanBuilder: _chips
                ? (context, e, style, rec) => TextSpan(
                      text: e.text,
                      recognizer: rec,
                      style: style.copyWith(
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    )
                : null,
            onTap: (e) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text('${e.type.name}: ${e.value}')),
              ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${entities.length} entities',
            style: Theme.of(context).textTheme.titleSmall),
        for (final e in entities)
          Text('${e.type.name.padRight(8)} ${e.value}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      ],
    );
  }
}
