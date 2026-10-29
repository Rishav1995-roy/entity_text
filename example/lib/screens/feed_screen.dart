import 'package:entity_text/entity_text.dart';
import 'package:flutter/material.dart';

import '../data.dart';

const orderType = EntityType('order');

final orderMatcher = RegexEntityMatcher(
  orderType,
  RegExp(r'\bORD-\d{4,}\b'),
  valueBuilder: (m) => m[0]!.substring(4),
);

/// The matchers used on the feed: defaults plus a custom order-id type.
final feedMatchers = <EntityMatcher>[
  ...EntityParser.defaultMatchers(),
  orderMatcher,
];

/// A list of posts with tappable, selectable entities and "Read more".
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _last = 'Tap a link, mention or hashtag. Long-press for the menu.';

  void _say(String s) => setState(() => _last = s);

  String _describe(Entity e, String verb) {
    final kind = e.type.name;
    return '$verb $kind: ${e.value}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: scheme.secondaryContainer,
          child: Container(
            key: const ValueKey('feedback'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: Text(_last,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ),
        Expanded(
          // One SelectionArea for the whole feed: drag to select across
          // posts, while entities stay tappable.
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final p in posts)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.author,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          EntityText.markup(
                            p.markup,
                            matchers: feedMatchers,
                            collapsedMaxLines: 4,
                            entityStyles: const {
                              orderType: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC2410C),
                              ),
                            },
                            onTap: (e) => _say(_describe(e, 'Tapped')),
                            onLongPress: (e) =>
                                _say(_describe(e, 'Long-pressed')),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
