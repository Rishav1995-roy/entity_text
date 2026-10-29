import 'package:flutter/foundation.dart';

/// The kind of an [Entity] found in a text.
///
/// The built-in kinds are available as constants ([url], [email], [phone],
/// [mention], [hashtag]). Create your own with `EntityType('order')`; two
/// types are equal when their names are equal. It is an extension type over
/// [String], so it can be used as a key of a `const` map:
///
/// ```dart
/// const styles = {EntityType.hashtag: TextStyle(color: Colors.purple)};
/// ```
extension type const EntityType(String name) {
  /// A web address such as `https://example.com/a?b=1` or `www.example.com`.
  static const EntityType url = EntityType('url');

  /// An email address.
  static const EntityType email = EntityType('email');

  /// A phone number.
  static const EntityType phone = EntityType('phone');

  /// An `@mention`.
  static const EntityType mention = EntityType('mention');

  /// A `#hashtag`.
  static const EntityType hashtag = EntityType('hashtag');
}

/// A piece of a text that a matcher recognised.
///
/// [start] and [end] are UTF-16 code unit offsets into the original string,
/// so `text.substring(start, end) == entity.text` always holds. Nothing in the
/// source text is ever modified.
@immutable
class Entity {
  /// Creates an entity.
  const Entity({
    required this.type,
    required this.start,
    required this.end,
    required this.text,
    String? value,
    this.data,
  }) : value = value ?? text;

  /// What kind of entity this is.
  final EntityType type;

  /// Offset of the first code unit.
  final int start;

  /// Offset just after the last code unit.
  final int end;

  /// The matched source text, exactly as it appears in the string.
  final String text;

  /// A normalised value for the entity, for example `https://` added to a
  /// bare domain, `mailto:` added to an email, or the user id of a mention.
  final String value;

  /// Free-form payload, for example the `Mention` behind a structured mention.
  final Object? data;

  /// Number of UTF-16 code units covered.
  int get length => end - start;

  @override
  bool operator ==(Object other) =>
      other is Entity &&
      other.type == type &&
      other.start == start &&
      other.end == end &&
      other.text == text &&
      other.value == value;

  @override
  int get hashCode => Object.hash(type, start, end, text, value);

  @override
  String toString() => 'Entity(${type.name}, $start-$end, "$text")';
}
