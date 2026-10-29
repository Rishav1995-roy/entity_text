## 0.0.1

* Initial release.
* Detection engine: `UrlMatcher` (balanced parentheses, trailing punctuation, IDN/IRI, emoji, RTL and CJK neighbours, optional bare domains), `EmailMatcher`, `PhoneMatcher`, `MentionMatcher`, `HashtagMatcher`, `RegexEntityMatcher` for custom types, and `EntityParser` with deterministic overlap resolution.
* `EntityText` widget: tappable and long-pressable entities, selectable (works in `SelectionArea` or with `selectable: true`), per-type styles, `styleBuilder`, `spanBuilder`, structured mentions, RTL, and "Read more / Read less" by lines or length that never cuts through an entity or an emoji.
* `EntityTextEditingController`: live styling while typing, structured `Mention`s (id + display) that move with the text, delete as a unit and dissolve when edited, composing-region support.
* `EntitySuggestions`: async suggestion overlay for `@` and `#` triggers with debounce, stale-response protection, placement above/below, and keyboard navigation (arrows, Enter, Tab, Esc).
* `EntityMarkup`: lossless `@[Display](id)` round trip.
