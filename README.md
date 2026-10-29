# entity_text

[![pub version](https://img.shields.io/pub/v/entity_text.svg)](https://pub.dev/packages/entity_text)
[![pub points](https://img.shields.io/pub/points/entity_text)](https://pub.dev/packages/entity_text/score)
[![likes](https://img.shields.io/pub/likes/entity_text)](https://pub.dev/packages/entity_text)
[![popularity](https://img.shields.io/pub/popularity/entity_text)](https://pub.dev/packages/entity_text/score)
[![CI](https://github.com/Rishav1995-roy/entity_text/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/Rishav1995-roy/entity_text/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platforms-android%20%7C%20ios%20%7C%20web%20%7C%20macos%20%7C%20windows%20%7C%20linux-informational)

One maintained package for text with links, `@mentions` and `#hashtags`: **detect** them correctly, **show** them tappable and selectable, **edit** them with live styling and a mention suggestion overlay, and **store** mentions as structured data (`id` + `display`). Pure Dart and Flutter, no native code, every platform.

![Demo](https://raw.githubusercontent.com/Rishav1995-roy/entity_text/main/doc/demo.gif)

<p>
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/entity_text/main/doc/screenshot_post.png" width="260" alt="A post with links, mentions and hashtags">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/entity_text/main/doc/screenshot_composer.png" width="260" alt="Composer with the mention suggestion overlay">
  <img src="https://raw.githubusercontent.com/Rishav1995-roy/entity_text/main/doc/screenshot_dark.png" width="260" alt="Dark theme">
</p>

> The GIF and screenshots are frame-by-frame renders of the example app in Flutter's test engine (bundled Roboto, scripted taps and key presses), not a screen recording of a device.

## Why this package

Showing and editing rich text in a post or chat usually means stitching together two or three packages that have not been updated for years. `entity_text` covers the whole path with one detection engine.

| | `flutter_linkify` | `flutter_mentions` | `detectable_text_field` | `fluttertagger` | `entity_text` |
|---|---|---|---|---|---|
| Last release (when written) | 2023-05 | 2021-05 | 2023-12 | 2026-03 | 0.0.1 |
| Displays tappable links | yes | no | no | no | yes |
| Mentions / hashtags in display text | no (needs an extra linkifier) | no | no | no | yes |
| Selectable **and** tappable | separate widget, limited | n/a | n/a | n/a | yes (`SelectionArea` or `selectable: true`) |
| Separate tap and long-press | no | n/a | n/a | n/a | yes |
| URL in parentheses / trailing punctuation | open issues ([#126](https://github.com/Cretezy/flutter_linkify/issues/126)) | n/a | n/a | n/a | yes, tested |
| Unicode / IDN, emoji and RTL neighbours | limited | n/a | n/a | n/a | yes, tested |
| "Read more" that does not cut a link | no | no | no | no | yes |
| Live styled input | no | yes | yes | yes | yes |
| Structured mention (id + display) | no | yes | no | yes | yes |
| Async suggestions + keyboard navigation (desktop/web) | no | partial | no | partial | yes |
| Markup round trip | no | no | no | no | `@[Name](id)` |
| One engine for display and input | no | no | no | no | yes |

The table reflects the packages' public pages and issue trackers at the time of writing (for example `flutter_linkify`'s "Is this project being maintained?" thread, [#139](https://github.com/Cretezy/flutter_linkify/issues/139), and the newline handling in [#76](https://github.com/Cretezy/flutter_linkify/issues/76)). `fluttertagger` is maintained and a good choice for input only; `entity_text` adds display, truncation and a shared detection engine. If a cell is out of date, please open an issue.

### Core problems this solves (and the tests that prove it)

| Problem | Where it comes from | Test |
|---|---|---|
| URLs are cut wrong: parentheses, trailing punctuation, IDN, emoji, RTL, newlines | `flutter_linkify` #126, #76 | `test/matchers_test.dart`, group "URL matcher" |
| Tappable text that is also selectable, with separate long press | `flutter_linkify` vs `SelectableLinkify` split | `test/entity_text_widget_test.dart`, group "selectable AND tappable" |
| Live-styled input where mentions are real data and survive typing and deleting | `flutter_mentions`, `detectable_text_field` | `test/controller_test.dart`, `test/suggestions_test.dart`, `test/markup_truncate_test.dart` |
| Truncation ("Read more") must not break a link, mention or emoji | all of them | `test/markup_truncate_test.dart` and the "read more / less" group in `test/entity_text_widget_test.dart` |

## Installation

```sh
flutter pub add entity_text
```

Requires Dart `^3.6.0` and Flutter `>=3.27.0`.

## Quick start

### Display

```dart
import 'package:entity_text/entity_text.dart';

EntityText(
  'Hi @asha, see https://example.com/docs (the new guide). #flutter',
  onTap: (entity) {
    switch (entity.type) {
      case EntityType.url:
        launchUrl(Uri.parse(entity.value)); // from url_launcher
      case EntityType.mention:
        openProfile(entity.value);
      default:
        print('${entity.type.name}: ${entity.value}');
    }
  },
  onLongPress: (entity) => showMenu(entity),
)
```

Selectable: wrap a screen or card in `SelectionArea`, or pass `selectable: true`. Tapping entities and selecting text work together.

```dart
SelectionArea(
  child: EntityText(post.text, onTap: openEntity),
)
```

Truncate without breaking entities:

```dart
EntityText(post.text, collapsedMaxLines: 4, onTap: openEntity) // "Read more" / "Read less"
```

### Edit

```dart
final controller = EntityTextEditingController();

EntitySuggestions(
  controller: controller,
  suggestionsBuilder: (query) => api.search(query.trigger.char, query.query), // async is fine
  builder: (context, focusNode) => TextField(
    controller: controller,
    focusNode: focusNode, // give the node to your field
    maxLines: null,
  ),
)

// Later
controller.text;      // 'Hi @Asha Rao, ...'
controller.mentions;  // [Mention(id: 'u1', display: 'Asha Rao', start: 3, trigger: '@')]
controller.markup;    // 'Hi @[Asha Rao](u1), ...'
```

Show stored markup again:

```dart
EntityText.markup(post.markup, onTap: (e) {
  if (e.type == EntityType.mention) openProfile(e.value); // e.value is the id
})
```

## Features

- **Detection** with pluggable matchers: URL, email, phone, mention, hashtag, `RegexEntityMatcher` for anything else (order ids, tickets, `$TICKERS`), and your own `EntityMatcher`.
- **URL grammar** that keeps `https://en.wikipedia.org/wiki/Dart_(language)` whole but drops the `)` of `(see https://example.com)`, ignores trailing `.,:;!?`, supports `https://münchen.de/straße`, stops at emoji, CJK punctuation and bidi marks, and optionally detects bare domains such as `example.com/a`.
- **Never alters your text.** Entities carry UTF-16 offsets into the original string; newlines and spacing are preserved.
- **`EntityText`**: selectable, separate tap and long press, per-type styles, `styleBuilder`, `spanBuilder` (return a `WidgetSpan` chip if you like), RTL, structured mentions, read more/less.
- **`EntityTextEditingController`**: a `TextEditingController` that styles entities live (including the IME composing underline), exposes `activeQuery`, and keeps `Mention`s consistent with the text: they shift when you type before them, a backspace removes the whole mention, typing inside one turns it back into plain text.
- **`EntitySuggestions`**: overlay for `@` and `#` triggers. Debounced async builder (stale responses are dropped, errors show nothing), arrow keys / Enter / Tab / Esc on desktop and web, placement above or below the field, custom item, empty and loading builders.
- **Markup**: `EntityMarkup.encode/decode` for `@[Name](id)`, escaping-safe for any text.

## API overview

### `EntityText`

| Parameter | Type | Description |
|---|---|---|
| `text` | `String` | The text to show. |
| `matchers` | `List<EntityMatcher>?` | Which entities to find (default: email, URL, phone, mention, hashtag). Keep the list stable between builds. |
| `mentions` | `List<Mention>` | Structured mentions at known ranges. |
| `style` | `TextStyle?` | Base style. |
| `entityStyles` | `Map<EntityType, TextStyle>?` | Per-type styles merged over theme-based defaults. |
| `styleBuilder` | `TextStyle? Function(Entity, TextStyle)?` | Final say per entity. |
| `spanBuilder` | `EntitySpanBuilder?` | Replace the span for an entity (pass the given `recognizer` through). |
| `onTap` / `onLongPress` | `void Function(Entity)?` | Entity gestures. |
| `selectable` / `onSelectionChanged` | `bool` / callback | Self-contained selection. Not needed inside `SelectionArea`. |
| `collapsedMaxLines` / `collapsedMaxLength` | `int?` | Enable "Read more". |
| `ellipsis`, `readMoreLabel`, `readLessLabel`, `toggleStyle` | | Toggle appearance (`readLessLabel: null` hides it). |
| `initiallyExpanded`, `onExpandedChanged` | | Expansion state. |
| `textAlign`, `textDirection`, `softWrap`, `strutStyle`, `locale` | | As in `Text`. |

`EntityText.markup(String markup, ...)` takes the same options and decodes `@[Name](id)` first.

### `EntityTextEditingController`

| Member | Description |
|---|---|
| `EntityTextEditingController({text, mentions, triggers, matchers, styles})` | Triggers default to `@` (structured) and `#` (plain). Matchers default to email, URL, hashtag. |
| `.fromMarkup(String)` / `setMarkup(String)` | Load text plus mentions. |
| `mentions` | Unmodifiable `List<Mention>`. |
| `markup` | Text with `@[Name](id)`. |
| `entities` | All entities (mentions plus detected). |
| `activeQuery` | `ActiveQuery?` for the trigger at the caret. |
| `applySuggestion(query, suggestion)` | Insert a mention (or plain text for non-structured triggers). |
| `styles` | Per-type style overrides. |

### `EntitySuggestions`

| Parameter | Description |
|---|---|
| `controller` | The `EntityTextEditingController`. |
| `suggestionsBuilder` | `FutureOr<List<EntitySuggestion>> Function(ActiveQuery)`. |
| `builder` | `(context, focusNode) => TextField(...)`. Pass the node to your field. |
| `itemBuilder`, `emptyBuilder`, `loadingBuilder` | Custom rows and states. |
| `debounce`, `maxHeight`, `placement`, `elevation`, `borderRadius` | Layout and timing. |
| `focusNode`, `onSelected` | Optional own node; selection callback. |

The list is anchored to the field (below or above), not to the caret.

### Matchers

| Class | Notes |
|---|---|
| `UrlMatcher({matchBareDomains, schemes, tlds, defaultScheme})` | Value always has a scheme. |
| `EmailMatcher()` | Value is `mailto:...`. |
| `PhoneMatcher({minDigits, maxDigits})` | Value is `tel:+...`. |
| `MentionMatcher()`, `HashtagMatcher()` | Any script; value is the name without the trigger. |
| `RegexEntityMatcher(type, pattern, {valueBuilder, validator, group})` | Build the `RegExp` with `unicode: true` for `\p{L}`. |
| `EntityParser(matchers)` | Resolves overlaps: earliest start wins, then longest, then matcher order. |

## Customization examples

```dart
// Custom entity type
const order = EntityType('order');
EntityText(
  'Where is ORD-48213?',
  matchers: [
    RegexEntityMatcher(order, RegExp(r'\bORD-\d{4,}\b'), valueBuilder: (m) => m[0]!.substring(4)),
  ],
  entityStyles: const {order: TextStyle(fontWeight: FontWeight.bold)},
  onTap: (e) => openOrder(e.value),
)

// Chips instead of plain spans
EntityText(
  text,
  spanBuilder: (context, e, style, recognizer) => TextSpan(
    text: e.text,
    recognizer: recognizer,
    style: style.copyWith(backgroundColor: Colors.blue.withValues(alpha: .12)),
  ),
)

// Several triggers, spaces allowed in names, hashtags as plain text
EntityTextEditingController(
  triggers: const [
    EntityTrigger('@', allowSpaces: true),
    EntityTrigger.hashtag(),
  ],
)
```

## Platform support

| Android | iOS | Web | macOS | Windows | Linux |
|---|---|---|---|---|---|
| Yes | Yes | Yes (WASM compatible) | Yes | Yes | Yes |

No native code and no dependencies beyond `characters`.

## Coming from other packages

**`flutter_linkify`**: replace `Linkify(text: t, onOpen: (l) => ...)` with `EntityText(t, onTap: (e) => ...)`; `e.value` is the URL with a scheme, `e.text` the text as typed. For `SelectableLinkify` use `selectable: true` or a `SelectionArea`. Mentions and hashtags come from the same call.

**`flutter_mentions` / `detectable_text_field`**: replace `FlutterMentions(...)` / `DetectableTextField(...)` with a normal `TextField` that uses an `EntityTextEditingController`, wrapped in `EntitySuggestions`. Read mentions from `controller.mentions` (id + display) instead of parsing the text yourself; store `controller.markup`.

## FAQ

**Does it open links for me?** No, to keep the package free of platform plugins. Call `url_launcher` from `onTap`.

**Why is my bare domain not detected?** `matchBareDomains` uses a short list of common TLDs. Pass `tlds:` to extend it or switch bare domains off.

**Can the suggestion list follow the caret?** Not in 0.0.1; it is anchored below or above the field.

**Do mentions work with IME composition (Gboard, CJK keyboards)?** Mention tracking is edit-based and works with composing text; mentions are created only through `applySuggestion`.

**Phone numbers show false positives.** Tune `PhoneMatcher(minDigits:, maxDigits:)` or leave it out of `matchers`.

## Contributing

Issues and pull requests are welcome at https://github.com/Rishav1995-roy/entity_text. Run `flutter analyze --fatal-infos` and `flutter test` before opening a PR. Regenerating the demo assets is described in `example/tool/make_gif.sh`.

## License

MIT, see [LICENSE](LICENSE).
