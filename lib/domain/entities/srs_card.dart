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

enum CardType { newCard, learning, review, suspended }

class SRSCard {
  final String id;
  final String word;
  final String? reading;
  final String meaning;
  final String? imageBase64;
  final DateTime nextReview;
  final int priority;
  final int languageLevel;
  final DateTime? lastReviewDate;
  final int reviewCount;
  final double easeFactor;
  final String? deck;
  final List<String> tags;
  final String? notes;
  final CardType type;
  final String? audioBase64;
  final String? videoBase64;
  final String? audioUrl;
  final String? videoUrl;

  const SRSCard({
    required this.id,
    required this.word,
    this.reading,
    required this.meaning,
    this.imageBase64,
    required this.nextReview,
    this.priority = 3,
    this.languageLevel = 1,
    this.lastReviewDate,
    this.reviewCount = 0,
    this.easeFactor = 2.5,
    this.deck,
    this.tags = const [],
    this.notes,
    this.type = CardType.newCard,
    this.audioBase64,
    this.videoBase64,
    this.audioUrl,
    this.videoUrl,
  });

  SRSCard copyWith({
    String? id,
    String? word,
    String? reading,
    String? meaning,
    String? imageBase64,
    DateTime? nextReview,
    int? priority,
    int? languageLevel,
    DateTime? lastReviewDate,
    int? reviewCount,
    double? easeFactor,
    String? deck,
    List<String>? tags,
    String? notes,
    CardType? type,
    String? audioBase64,
    String? videoBase64,
    String? audioUrl,
    String? videoUrl,
  }) {
    return SRSCard(
      id: id ?? this.id,
      word: word ?? this.word,
      reading: reading ?? this.reading,
      meaning: meaning ?? this.meaning,
      imageBase64: imageBase64 ?? this.imageBase64,
      nextReview: nextReview ?? this.nextReview,
      priority: priority ?? this.priority,
      languageLevel: languageLevel ?? this.languageLevel,
      lastReviewDate: lastReviewDate ?? this.lastReviewDate,
      reviewCount: reviewCount ?? this.reviewCount,
      easeFactor: easeFactor ?? this.easeFactor,
      deck: deck ?? this.deck,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      audioBase64: audioBase64 ?? this.audioBase64,
      videoBase64: videoBase64 ?? this.videoBase64,
      audioUrl: audioUrl ?? this.audioUrl,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  factory SRSCard.fromJson(Map<String, dynamic> json) {
    return SRSCard(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String?,
      meaning: json['meaning'] as String,
      imageBase64: json['imageBase64'] as String?,
      nextReview: DateTime.parse(json['nextReview'] as String),
      priority: json['priority'] as int? ?? 3,
      languageLevel: json['languageLevel'] as int? ?? 1,
      lastReviewDate: json['lastReviewDate'] != null
          ? DateTime.parse(json['lastReviewDate'] as String)
          : null,
      reviewCount: json['reviewCount'] as int? ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      deck: json['deck'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      notes: json['notes'] as String?,
      type: CardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CardType.newCard,
      ),
      audioBase64: json['audioBase64'] as String?,
      videoBase64: json['videoBase64'] as String?,
      audioUrl: json['audioUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'reading': reading,
      'meaning': meaning,
      'imageBase64': imageBase64,
      'nextReview': nextReview.toIso8601String(),
      'priority': priority,
      'languageLevel': languageLevel,
      'lastReviewDate': lastReviewDate?.toIso8601String(),
      'reviewCount': reviewCount,
      'easeFactor': easeFactor,
      'deck': deck,
      'tags': tags,
      'notes': notes,
      'type': type.name,
      'audioBase64': audioBase64,
      'videoBase64': videoBase64,
      'audioUrl': audioUrl,
      'videoUrl': videoUrl,
    };
  }

  static SRSCard newCard({
    required String id,
    required String word,
    String? reading,
    required String meaning,
    String? imageBase64,
    String? deck,
    List<String> tags = const [],
    String? notes,
    String? audioBase64,
    String? videoBase64,
    String? audioUrl,
    String? videoUrl,
  }) {
    return SRSCard(
      id: id,
      word: word,
      reading: reading,
      meaning: meaning,
      imageBase64: imageBase64,
      nextReview: DateTime.now(),
      priority: 3,
      languageLevel: 1,
      deck: deck,
      tags: tags,
      notes: notes,
      type: CardType.newCard,
      audioBase64: audioBase64,
      videoBase64: videoBase64,
      audioUrl: audioUrl,
      videoUrl: videoUrl,
    );
  }

  int get interval => reviewCount == 0 ? 0 : (reviewCount * easeFactor).round();

  bool get hasImage => imageBase64 != null && imageBase64!.isNotEmpty;
  bool get hasAudio => (audioBase64 != null && audioBase64!.isNotEmpty) || (audioUrl != null && audioUrl!.isNotEmpty);
  bool get hasVideo => (videoBase64 != null && videoBase64!.isNotEmpty) || (videoUrl != null && videoUrl!.isNotEmpty);

  bool get isDue => DateTime.now().isAfter(nextReview) || DateTime.now().isAtSameMomentAs(nextReview);

  SRSCard calculateNextReview(int quality) {
    if (type == CardType.suspended) return this;

    const minEaseFactor = 1.3;
    double newEaseFactor = easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < minEaseFactor) newEaseFactor = minEaseFactor;

    int newInterval;
    int newRepetition = reviewCount + 1;
    CardType newType;

    if (quality < 3) {
      newRepetition = 0;
      newInterval = 0;
      newType = CardType.learning;
    } else {
      if (reviewCount == 0) {
        newInterval = 1;
        newType = CardType.learning;
      } else if (reviewCount == 1) {
        newInterval = 6;
        newType = CardType.review;
      } else {
        newInterval = (reviewCount * newEaseFactor).round();
        newType = CardType.review;
      }
    }

    final now = DateTime.now();
    final nextReviewDate = DateTime(now.year, now.month, now.day + newInterval);

    return copyWith(
      easeFactor: newEaseFactor,
      reviewCount: newRepetition,
      nextReview: nextReviewDate,
      lastReviewDate: now,
      type: newType,
    );
  }

  SRSCard suspend() => copyWith(type: CardType.suspended);
  SRSCard unsuspend() => copyWith(type: reviewCount == 0 ? CardType.newCard : reviewCount < 3 ? CardType.learning : CardType.review);
}