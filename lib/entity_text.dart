/// Detect URLs, emails, phone numbers, @mentions, #hashtags and custom
/// entities; show them tappable and selectable; edit them with live styling
/// and a mention suggestion overlay.
library;

export 'src/controller.dart' show EntityTextEditingController;
export 'src/entity.dart' show Entity, EntityType;
export 'src/entity_text.dart'
    show EntityCallback, EntitySpanBuilder, EntityText;
export 'src/markup.dart' show EntityMarkup;
export 'src/matchers.dart'
    show
        EmailMatcher,
        EntityMatcher,
        HashtagMatcher,
        MentionMatcher,
        PhoneMatcher,
        RegexEntityMatcher,
        UrlMatcher;
export 'src/mention.dart'
    show ActiveQuery, EntitySuggestion, EntityTrigger, Mention;
export 'src/parser.dart' show EntityParser;
export 'src/styles.dart' show EntityStyles;
export 'src/suggestions.dart'
    show
        EntitySuggestions,
        EntitySuggestionItemBuilder,
        EntitySuggestionsBuilder,
        EntitySuggestionsPlacement;
export 'src/text_edit.dart' show TextEdit;
export 'src/truncate.dart' show collapsedLengthCut, snapCut;
