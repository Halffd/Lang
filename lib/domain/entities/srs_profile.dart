class SrsProfile {
  final String id;
  final String name;
  final String? avatarEmoji;
  final int dailyGoal;
  final int todayReviews;
  final int streak;
  final DateTime? lastReviewDate;
  final Map<String, int> dailyStats;
  final List<String> enabledDecks;
  final bool autoStudy;
  final int maxCardsPerSession;

  const SrsProfile({
    required this.id,
    required this.name,
    this.avatarEmoji = '👤',
    this.dailyGoal = 20,
    this.todayReviews = 0,
    this.streak = 0,
    this.lastReviewDate,
    this.dailyStats = const {},
    this.enabledDecks = const [],
    this.autoStudy = false,
    this.maxCardsPerSession = 20,
  });

  factory SrsProfile.fromJson(Map<String, dynamic> json) {
    return SrsProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarEmoji: json['avatar_emoji'] as String? ?? '👤',
      dailyGoal: json['daily_goal'] as int? ?? 20,
      todayReviews: json['today_reviews'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      lastReviewDate: json['last_review_date'] != null
          ? DateTime.parse(json['last_review_date'] as String)
          : null,
      dailyStats: (json['daily_stats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      enabledDecks: (json['enabled_decks'] as List<dynamic>?)?.cast<String>() ?? [],
      autoStudy: json['auto_study'] as bool? ?? false,
      maxCardsPerSession: json['max_cards_per_session'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_emoji': avatarEmoji,
      'daily_goal': dailyGoal,
      'today_reviews': todayReviews,
      'streak': streak,
      'last_review_date': lastReviewDate?.toIso8601String(),
      'daily_stats': dailyStats,
      'enabled_decks': enabledDecks,
      'auto_study': autoStudy,
      'max_cards_per_session': maxCardsPerSession,
    };
  }

  SrsProfile copyWith({
    String? id,
    String? name,
    String? avatarEmoji,
    int? dailyGoal,
    int? todayReviews,
    int? streak,
    DateTime? lastReviewDate,
    Map<String, int>? dailyStats,
    List<String>? enabledDecks,
    bool? autoStudy,
    int? maxCardsPerSession,
  }) {
    return SrsProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      todayReviews: todayReviews ?? this.todayReviews,
      streak: streak ?? this.streak,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      dailyStats: dailyStats ?? this.dailyStats,
      enabledDecks: enabledDecks ?? this.enabledDecks,
      autoStudy: autoStudy ?? this.autoStudy,
      maxCardsPerSession: maxCardsPerSession ?? this.maxCardsPerSession,
    );
  }

  double get goalProgress => dailyGoal > 0 ? (todayReviews / dailyGoal).clamp(0.0, 1.0) : 0.0;

  bool get goalMet => todayReviews >= dailyGoal;
}