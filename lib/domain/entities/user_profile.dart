/// User profile surfaced across screens: name, languages, learning goals,
/// stats (XP, streak, level). Persisted via PrefService + optionally synced
/// to Supabase table `user_profiles`.
class UserProfile {
  final String displayName;
  final String nativeLanguage; // e.g. 'en'
  final String currentTargetLanguage; // e.g. 'ja'
  final List<String> languages; // languages user is learning
  final int xp;
  final int gems;
  final int streak;
  final int dailyGoal; // XP target per day
  final int cardsMastered; // srs cards with easeFactor >= 2.5
  final DateTime? updatedAt;

  const UserProfile({
    this.displayName = ' ',
    this.nativeLanguage = 'en',
    this.currentTargetLanguage = 'ja',
    this.languages = const ['ja'],
    this.xp = 0,
    this.gems = 0,
    this.streak = 0,
    this.dailyGoal = 50,
    this.cardsMastered = 0,
    this.updatedAt,
  });

  /// Duolingo-style level from XP: level^2 * 50 = xp threshold-ish.
  int get level => _levelForXp(xp);
  int get xpInLevel => xp - _xpFloor(level);
  int get xpToLevelUp => _xpFloor(level + 1) - xp;

  static int _levelForXp(int xp) {
    var level = 1;
    while (xp >= _xpFloor(level + 1)) {
      level++;
    }
    return level;
  }

  /// quadratic curve: lvl 1→50xp, 2→150, 3→300, 4→500, 5→750, ...
  static int _xpFloor(int level) =>
      (level - 1) * (level - 2) * 25 + 50 * (level - 1);

  /// Language stack display (API7 compliant CEFR view; naive mapping).
  String get languageTag =>
      '${currentTargetLanguage.toUpperCase()} ⇄ '
      '${nativeLanguage.toUpperCase()}';

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'native_language': nativeLanguage,
    'target_language': currentTargetLanguage,
    'languages': languages,
    'xp': xp,
    'gems': gems,
    'streak': streak,
    'daily_goal': dailyGoal,
    'cards_mastered': cardsMastered,
    'updated_at': DateTime.now().toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    displayName: j['display_name']?.toString() ?? ' ',
    nativeLanguage: j['native_language']?.toString() ?? 'en',
    currentTargetLanguage: j['target_language']?.toString() ?? 'ja',
    languages:
        (j['languages'] as List?)?.map((e) => e.toString()).toList() ??
        const ['ja'],
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    gems: (j['gems'] as num?)?.toInt() ?? 0,
    streak: (j['streak'] as num?)?.toInt() ?? 0,
    dailyGoal: (j['daily_goal'] as num?)?.toInt() ?? 50,
    cardsMastered: (j['cards_mastered'] as num?)?.toInt() ?? 0,
    updatedAt: j['updated_at'] != null
        ? DateTime.tryParse(j['updated_at'].toString())
        : null,
  );

  UserProfile copyWith({
    String? displayName,
    String? nativeLanguage,
    String? currentTargetLanguage,
    List<String>? languages,
    int? xp,
    int? gems,
    int? streak,
    int? dailyGoal,
    int? cardsMastered,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentTargetLanguage:
          currentTargetLanguage ?? this.currentTargetLanguage,
      languages: languages ?? this.languages,
      xp: xp ?? this.xp,
      gems: gems ?? this.gems,
      streak: streak ?? this.streak,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      cardsMastered: cardsMastered ?? this.cardsMastered,
      updatedAt: DateTime.now(),
    );
  }
}
