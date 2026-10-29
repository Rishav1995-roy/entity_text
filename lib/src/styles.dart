import 'package:flutter/material.dart';

import 'entity.dart';

/// Default [TextStyle]s for each built-in [EntityType].
///
/// Used by the input controller (which has no `BuildContext`). The display
/// widget derives its defaults from the current [Theme] instead.
class EntityStyles {
  EntityStyles._();

  /// Fixed, theme-independent defaults.
  static const Map<EntityType, TextStyle> fallback = {
    EntityType.url: TextStyle(
      color: Color(0xFF1A73E8),
      decoration: TextDecoration.underline,
    ),
    EntityType.email: TextStyle(
      color: Color(0xFF1A73E8),
      decoration: TextDecoration.underline,
    ),
    EntityType.phone: TextStyle(
      color: Color(0xFF1A73E8),
      decoration: TextDecoration.underline,
    ),
    EntityType.mention: TextStyle(
      color: Color(0xFF1A73E8),
      fontWeight: FontWeight.w600,
    ),
    EntityType.hashtag: TextStyle(color: Color(0xFF7B1FA2)),
  };

  /// Defaults derived from [theme]'s colour scheme.
  static Map<EntityType, TextStyle> fromTheme(ThemeData theme) {
    final primary = theme.colorScheme.primary;
    return {
      EntityType.url:
          TextStyle(color: primary, decoration: TextDecoration.underline),
      EntityType.email:
          TextStyle(color: primary, decoration: TextDecoration.underline),
      EntityType.phone:
          TextStyle(color: primary, decoration: TextDecoration.underline),
      EntityType.mention:
          TextStyle(color: primary, fontWeight: FontWeight.w600),
      EntityType.hashtag: TextStyle(color: theme.colorScheme.tertiary),
    };
  }
}
