class SrsCard {
  final String id;
  final String userId;
  final String? deckId;
  final String? wordId;
  final String front;
  final String back;
  final String? reading;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastReviewedAt;

  const SrsCard({
    required this.id,
    required this.userId,
    this.deckId,
    this.wordId,
    required this.front,
    required this.back,
    this.reading,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.lastReviewedAt,
  });

  factory SrsCard.fromMap(Map<String, dynamic> map) {
    return SrsCard(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      deckId: map['deck_id'] as String?,
      wordId: map['word_id'] as String?,
      front: map['front'] as String,
      back: map['back'] as String,
      reading: map['reading'] as String?,
      easeFactor: (map['ease_factor'] as num?)?.toDouble() ?? 2.5,
      interval: map['interval'] as int? ?? 0,
      repetitions: map['repetitions'] as int? ?? 0,
      dueDate: DateTime.parse(map['due_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'deck_id': deckId,
      'word_id': wordId,
      'front': front,
      'back': back,
      'reading': reading,
      'ease_factor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'due_date': dueDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  bool get isDue => DateTime.now().isAfter(dueDate) || DateTime.now().isAtSameMomentAs(dueDate);

  SrsCard copyWith({
    String? id,
    String? userId,
    String? deckId,
    String? wordId,
    String? front,
    String? back,
    String? reading,
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastReviewedAt,
  }) {
    return SrsCard(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deckId: deckId ?? this.deckId,
      wordId: wordId ?? this.wordId,
      front: front ?? this.front,
      back: back ?? this.back,
      reading: reading ?? this.reading,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }
}

class SRSCard {
  final String id;
  final String word;
  final String? reading;
  final String meaning;
  final DateTime nextReview;
  final int priority;
  final int languageLevel;
  final DateTime? lastReviewDate;
  final int reviewCount;
  final double easeFactor;

  const SRSCard({
    required this.id,
    required this.word,
    this.reading,
    required this.meaning,
    required this.nextReview,
    this.priority = 3,
    this.languageLevel = 1,
    this.lastReviewDate,
    this.reviewCount = 0,
    this.easeFactor = 2.5,
  });

  factory SRSCard.fromJson(Map<String, dynamic> json) {
    return SRSCard(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String?,
      meaning: json['meaning'] as String,
      nextReview: DateTime.parse(json['nextReview'] as String),
      priority: json['priority'] as int? ?? 3,
      languageLevel: json['languageLevel'] as int? ?? 1,
      lastReviewDate: json['lastReviewDate'] != null
          ? DateTime.parse(json['lastReviewDate'] as String)
          : null,
      reviewCount: json['reviewCount'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'reading': reading,
      'meaning': meaning,
      'nextReview': nextReview.toIso8601String(),
      'priority': priority,
      'languageLevel': languageLevel,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'reviewCount': reviewCount,
      'easeFactor': easeFactor,
    };
  }

  SRSCard copyWith({
    String? id,
    String? word,
    String? reading,
    String? meaning,
    DateTime? nextReview,
    int? priority,
    int? languageLevel,
    DateTime? lastReviewDate,
    int? reviewCount,
    double? easeFactor,
  }) {
    return SRSCard(
      id: id ?? this.id,
      word: word ?? this.word,
      reading: reading ?? this.reading,
      meaning: meaning ?? this.meaning,
      nextReview: nextReview ?? this.nextReview,
      priority: priority ?? this.priority,
      languageLevel: languageLevel ?? this.languageLevel,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      reviewCount: reviewCount ?? this.reviewCount,
      easeFactor: easeFactor ?? this.easeFactor,
    );
  }

  static SRSCard newCard({
    required String id,
    required String word,
    String? reading,
    required String meaning,
  }) {
    return SRSCard(
      id: id,
      word: word,
      reading: reading,
      meaning: meaning,
      nextReview: DateTime.now(),
      priority: 3,
      languageLevel: 1,
    );
  }
}