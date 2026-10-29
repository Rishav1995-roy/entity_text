import 'package:flutter/foundation.dart';

import 'entity.dart';

/// A structured mention stored inside a text: the user chose it from a
/// suggestion list, so it has an [id] and is more than characters.
///
/// The text shows `trigger + display` (for example `@Asha Rao`) at
/// [start]. Offsets are UTF-16 code units.
@immutable
class Mention {
  /// Creates a mention.
  const Mention({
    required this.id,
    required this.display,
    required this.start,
    this.trigger = '@',
  });

  /// Application id (user id, tag id, ...). Not shown to the user.
  final String id;

  /// Name shown after the trigger character, without it.
  final String display;

  /// Offset in the text of the trigger character.
  final int start;

  /// The character that introduced the mention, `@` by default.
  final String trigger;

  /// The exact text that represents the mention: `trigger + display`.
  String get text => '$trigger$display';

  /// Offset just after the mention text.
  int get end => start + text.length;

  /// [EntityType.hashtag] for `#`, otherwise [EntityType.mention].
  EntityType get type =>
      trigger == '#' ? EntityType.hashtag : EntityType.mention;

  /// Returns a copy with some fields replaced.
  Mention copyWith(
          {String? id, String? display, int? start, String? trigger}) =>
      Mention(
        id: id ?? this.id,
        display: display ?? this.display,
        start: start ?? this.start,
        trigger: trigger ?? this.trigger,
      );

  /// This mention as an [Entity] (value is the [id], data is `this`).
  Entity toEntity() => Entity(
        type: type,
        start: start,
        end: end,
        text: text,
        value: id,
        data: this,
      );

  @override
  bool operator ==(Object other) =>
      other is Mention &&
      other.id == id &&
      other.display == display &&
      other.start == start &&
      other.trigger == trigger;

  @override
  int get hashCode => Object.hash(id, display, start, trigger);

  @override
  String toString() => 'Mention($trigger$display#$id @ $start)';
}

/// Describes a character that opens suggestions in an input, such as `@`.
@immutable
class EntityTrigger {
  /// Creates a trigger.
  const EntityTrigger(
    this.char, {
    this.type,
    this.structured = true,
    this.maxQueryLength = 30,
    this.allowSpaces = false,
  });

  /// The `@` trigger producing structured mentions.
  const EntityTrigger.mention() : this('@', type: EntityType.mention);

  /// The `#` trigger producing plain hashtags (not structured).
  const EntityTrigger.hashtag()
      : this('#', type: EntityType.hashtag, structured: false);

  /// The trigger character.
  final String char;

  /// The entity type used to style the active query and the result.
  /// Defaults to [EntityType.hashtag] for `#`, otherwise [EntityType.mention].
  final EntityType? type;

  /// When true a chosen suggestion is stored as a [Mention] (id + display).
  /// When false the suggestion is inserted as ordinary text.
  final bool structured;

  /// Longest query (characters after the trigger) that still opens the list.
  final int maxQueryLength;

  /// Whether the query may contain spaces (for `@Asha Ra`).
  final bool allowSpaces;

  /// The effective entity type.
  EntityType get effectiveType =>
      type ?? (char == '#' ? EntityType.hashtag : EntityType.mention);
}

/// What the user is currently typing after a trigger, e.g. `@as`.
@immutable
class ActiveQuery {
  /// Creates a query.
  const ActiveQuery({
    required this.trigger,
    required this.query,
    required this.start,
    required this.end,
  });

  /// The trigger that opened the query.
  final EntityTrigger trigger;

  /// Text after the trigger up to the caret (may be empty).
  final String query;

  /// Offset of the trigger character.
  final int start;

  /// Offset of the caret (end of the query).
  final int end;

  @override
  bool operator ==(Object other) =>
      other is ActiveQuery &&
      other.trigger.char == trigger.char &&
      other.query == query &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(trigger.char, query, start, end);

  @override
  String toString() => 'ActiveQuery(${trigger.char}$query @ $start)';
}

/// One row offered in the suggestion list.
@immutable
class EntitySuggestion {
  /// Creates a suggestion.
  const EntitySuggestion({
    required this.id,
    required this.display,
    this.subtitle,
    this.data,
  });

  /// Stored in the resulting [Mention.id].
  final String id;

  /// Inserted after the trigger and stored in [Mention.display].
  final String display;

  /// Optional second line in the default item builder.
  final String? subtitle;

  /// Anything else your item builder needs (avatar url, ...).
  final Object? data;
}
