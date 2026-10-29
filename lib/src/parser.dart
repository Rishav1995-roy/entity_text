import 'entity.dart';
import 'matchers.dart';

/// Runs several [EntityMatcher]s over a text and resolves overlaps.
///
/// When two matches overlap, the one that starts first wins; on a tie the
/// longer one wins; on a further tie the matcher listed first wins. That is
/// why `https://x.com/@me#top` is a single URL and `a@b.com` is an email, not
/// a mention plus a domain.
class EntityParser {
  /// Creates a parser with [matchers] (defaults to [defaultMatchers]).
  EntityParser([List<EntityMatcher>? matchers])
      : matchers = matchers ?? defaultMatchers();

  /// The matchers, in priority order.
  final List<EntityMatcher> matchers;

  /// Email, URL, phone, mention and hashtag matchers with default settings.
  static List<EntityMatcher> defaultMatchers() => [
        const EmailMatcher(),
        UrlMatcher(),
        const PhoneMatcher(),
        MentionMatcher(),
        HashtagMatcher(),
      ];

  /// Returns all non-overlapping entities in [text], sorted by position.
  List<Entity> parse(String text) {
    if (text.isEmpty) return const [];
    final all = <(int, Entity)>[];
    for (var i = 0; i < matchers.length; i++) {
      for (final e in matchers[i].findAll(text)) {
        all.add((i, e));
      }
    }
    all.sort((a, b) {
      final c = a.$2.start.compareTo(b.$2.start);
      if (c != 0) return c;
      final l = b.$2.length.compareTo(a.$2.length);
      if (l != 0) return l;
      return a.$1.compareTo(b.$1);
    });
    final result = <Entity>[];
    var lastEnd = 0;
    for (final (_, e) in all) {
      if (e.start >= lastEnd) {
        result.add(e);
        lastEnd = e.end;
      }
    }
    return result;
  }
}
