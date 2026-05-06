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