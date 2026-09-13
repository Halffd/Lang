import 'dart:convert';

/// How the popup dictionary is summoned.
enum PopupTrigger {
  none,
  hover, // mouse over
  click,
  doubleClick,
  rightClick,
  middleClick,
  shift, // modifier key held while hovering
  ctrl,
  alt,
  meta, // win/cmd
  tap, // single finger tap
  longPress, // press and hold (mobile)
  penTap,
  shake, // device shake (mobile)
}

extension PopupTriggerX on PopupTrigger {
  bool get needsModifier =>
      this == PopupTrigger.shift ||
      this == PopupTrigger.ctrl ||
      this == PopupTrigger.alt ||
      this == PopupTrigger.meta;

  String get label => switch (this) {
    PopupTrigger.none => 'none',
    PopupTrigger.hover => 'hover',
    PopupTrigger.click => 'click',
    PopupTrigger.doubleClick => 'double click',
    PopupTrigger.rightClick => 'right click',
    PopupTrigger.middleClick => 'middle click',
    PopupTrigger.shift => 'shift + hover',
    PopupTrigger.ctrl => 'ctrl + hover',
    PopupTrigger.alt => 'alt + hover',
    PopupTrigger.meta => 'meta + hover',
    PopupTrigger.tap => 'tap',
    PopupTrigger.longPress => 'long press',
    PopupTrigger.penTap => 'pen tap',
    PopupTrigger.shake => 'shake',
  };
}

/// Optional per-trigger extra modifier: the trigger fires only when
/// the extra key is also held.
enum PopupExtraModifier { none, shift, ctrl, alt, meta }

/// Where the popup is allowed to appear.
enum PopupScreenScope {
  all,
  analyze,
  reader,
  dictionary,
  writer,
  history,
  ai,
  srs,
  custom,
}

/// Full configuration for the popup dictionary.
class PopupDictionaryConfig {
  /// Primary summon trigger.
  PopupTrigger trigger;

  /// Additional modifier required alongside [trigger] (optional).
  PopupExtraModifier extraModifier;

  /// Hold delay in milliseconds before the popup opens
  /// (hover/longPress/shake).
  int delayMs;

  /// Maximum text length scanned at the pointer; longer runs are
  /// truncated from the cursor outwards (scan limit, yomichan style).
  int scanLength;

  /// Deep search: also try the term at offsets 1..[scanLength] from
  /// the cursor (longest-match-first).
  int scanDepth;

  /// Copy looked-up term to clipboard automatically.
  bool autoCopy;

  /// Send looked-up term to Anki (AnkiConnect) automatically.
  bool autoAnki;

  /// Which deck auto-anki adds to (empty = default deck).
  String ankiDeck;

  /// Only trigger when text matches this regex. Empty = everything.
  /// Useful to exclude non-Japanese/non-Chinese text or to require
  /// CJK scripts.
  String requireRegex;

  /// Exclude text matching this regex.
  String excludeRegex;

  /// Detect compounds (compound words spanning the cursor) via the
  /// tokenizer before dictionary lookup.
  bool detectCompounds;

  /// Detect conjugated forms and look up the dictionary form via
  /// deconjugation.
  bool detectConjugations;

  /// Screens where the popup may appear.
  Set<PopupScreenScope> allowedScreens;

  /// Alternative trigger used when the active profile condition
  /// matches (profile alternation). When null the primary trigger
  /// applies everywhere.
  PopupTrigger? altTrigger;
  String altCondition; // profile name this alternative applies to

  /// Only trigger when the learning language matches one of these
  /// codes. Empty = any.
  Set<String> languages;

  PopupDictionaryConfig({
    this.trigger = PopupTrigger.shift,
    this.extraModifier = PopupExtraModifier.none,
    this.delayMs = 300,
    this.scanLength = 16,
    this.scanDepth = 8,
    this.autoCopy = false,
    this.autoAnki = false,
    this.ankiDeck = '',
    this.requireRegex = '',
    this.excludeRegex = '',
    this.detectCompounds = true,
    this.detectConjugations = true,
    this.allowedScreens = const {PopupScreenScope.all},
    this.altTrigger,
    this.altCondition = '',
    this.languages = const {},
  });

  /// Effective trigger for the current SRS/profile name.
  PopupTrigger effectiveTrigger(String? activeProfile) {
    if (altTrigger != null &&
        altCondition.isNotEmpty &&
        activeProfile != null &&
        activeProfile == altCondition) {
      return altTrigger!;
    }
    return trigger;
  }

  /// Whether a candidate text passes the regex gates.
  bool allowsText(String text) {
    if (requireRegex.isNotEmpty) {
      try {
        if (!RegExp(requireRegex).hasMatch(text)) return false;
      } catch (_) {
        // malformed regex: ignore gate
      }
    }
    if (excludeRegex.isNotEmpty) {
      try {
        if (RegExp(excludeRegex).hasMatch(text)) return false;
      } catch (_) {}
    }
    return true;
  }

  /// Whether the popup may open on this screen route name.
  bool allowsScreen(String routeName) {
    if (allowedScreens.contains(PopupScreenScope.all)) return true;
    for (final scope in allowedScreens) {
      if (routeName.contains(scope.name)) return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'trigger': trigger.name,
    'extraModifier': extraModifier.name,
    'delayMs': delayMs,
    'scanLength': scanLength,
    'scanDepth': scanDepth,
    'autoCopy': autoCopy,
    'autoAnki': autoAnki,
    'ankiDeck': ankiDeck,
    'requireRegex': requireRegex,
    'excludeRegex': excludeRegex,
    'detectCompounds': detectCompounds,
    'detectConjugations': detectConjugations,
    'allowedScreens': allowedScreens.map((s) => s.name).toList(),
    'altTrigger': altTrigger?.name,
    'altCondition': altCondition,
    'languages': languages.toList(),
  };

  static PopupDictionaryConfig fromJson(Map<String, dynamic> json) =>
      PopupDictionaryConfig(
        trigger: _enumByName(PopupTrigger.values, json['trigger']),
        extraModifier: _enumByName(
          PopupExtraModifier.values,
          json['extraModifier'],
        ),
        delayMs: (json['delayMs'] as num?)?.toInt() ?? 300,
        scanLength: (json['scanLength'] as num?)?.toInt() ?? 16,
        scanDepth: (json['scanDepth'] as num?)?.toInt() ?? 8,
        autoCopy: json['autoCopy'] as bool? ?? false,
        autoAnki: json['autoAnki'] as bool? ?? false,
        ankiDeck: json['ankiDeck'] as String? ?? '',
        requireRegex: json['requireRegex'] as String? ?? '',
        excludeRegex: json['excludeRegex'] as String? ?? '',
        detectCompounds: json['detectCompounds'] as bool? ?? true,
        detectConjugations: json['detectConjugations'] as bool? ?? true,
        allowedScreens:
            (json['allowedScreens'] as List?)
                ?.map((s) => _enumByName(PopupScreenScope.values, s))
                .toSet() ??
            {PopupScreenScope.all},
        altTrigger: json['altTrigger'] == null
            ? null
            : _enumByName(PopupTrigger.values, json['altTrigger']),
        altCondition: json['altCondition'] as String? ?? '',
        languages:
            (json['languages'] as List?)?.map((e) => e.toString()).toSet() ??
            {},
      );

  String serialize() => jsonEncode(toJson());

  static PopupDictionaryConfig deserialize(String? raw) {
    if (raw == null || raw.isEmpty) return PopupDictionaryConfig();
    try {
      return PopupDictionaryConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return PopupDictionaryConfig();
    }
  }

  static T _enumByName<T extends Enum>(List<T> values, dynamic name) {
    return values.firstWhere((v) => v.name == name, orElse: () => values.first);
  }
}
