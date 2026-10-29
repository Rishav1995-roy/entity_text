import 'package:entity_text/entity_text.dart';

/// Synthetic people used by the suggestion lists (no real data).
const people = <EntitySuggestion>[
  EntitySuggestion(id: 'u_asha', display: 'Asha Rao', subtitle: 'Design lead'),
  EntitySuggestion(id: 'u_arjun', display: 'Arjun Mehta', subtitle: 'Engineer'),
  EntitySuggestion(id: 'u_bo', display: 'Bo Chen', subtitle: 'Product'),
  EntitySuggestion(id: 'u_lena', display: 'Lena Fischer', subtitle: 'QA'),
  EntitySuggestion(id: 'u_noor', display: 'Noor Hassan', subtitle: 'Support'),
  EntitySuggestion(id: 'u_sam', display: 'Sam Okafor', subtitle: 'Data'),
];

const tags = <String>['flutter', 'dart', 'opensource', 'design', 'weekend'];

/// Pretends to be a network search.
Future<List<EntitySuggestion>> searchSuggestions(ActiveQuery q) async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final needle = q.query.toLowerCase();
  if (q.trigger.char == '#') {
    return [
      for (final t in tags)
        if (t.contains(needle)) EntitySuggestion(id: 'tag_$t', display: t),
    ];
  }
  return [
    for (final p in people)
      if (p.display.toLowerCase().contains(needle)) p,
  ];
}

/// Posts shown on the feed screen (markup uses structured mentions).
const posts = <({String author, String markup})>[
  (
    author: 'Asha Rao',
    markup: 'Shipped the new release with @[Arjun Mehta](u_arjun)! Notes: https://example.com/releases/2.0 (see the changelog). '
        'Questions? hello@example.com or call +91 98765 43210. #flutter #opensource',
  ),
  (
    author: 'Bo Chen',
    markup: 'Weekend trip photos are up at www.example.com/albums/summer_(2026) Thanks @[Lena Fischer](u_lena) for organising! '
        'More tags: #weekend and order ORD-48213 is on its way. '
        'We also walked around the old town, tried every street snack we could find, and met a lot of friendly people. '
        'Would do it again tomorrow! See https://example.com/trip/2026/photos/day-1 for the first day.',
  ),
];
