import 'dart:convert';

/// Represents a Spaced Repetition System card
class SRSCard {
  final String id;
  final String word;
  final String reading;
  final String meaning;
  final DateTime createdAt;
  final DateTime nextReview;
  final int interval; // in days
  final double easeFactor; // E-Factor from SM2 algorithm
  final int repetition; // number of times reviewed
  final int languageLevel; // 1-5 difficulty level of the word
  final int priority; // 1-5 priority level (1=highest priority)
  final List<DateTime> reviewHistory; // history of review dates

  SRSCard({
    required this.id,
    required this.word,
    required this.reading,
    required this.meaning,
    required this.createdAt,
    required this.nextReview,
    required this.interval,
    required this.easeFactor,
    required this.repetition,
    required this.languageLevel,
    required this.priority,
    required this.reviewHistory,
  });

  /// Create a new card for a word
  factory SRSCard.newCard({
    required String id,
    required String word,
    required String reading,
    required String meaning,
    int languageLevel = 3,
    int priority = 3,
  }) {
    return SRSCard(
      id: id,
      word: word,
      reading: reading,
      meaning: meaning,
      createdAt: DateTime.now(),
      nextReview: DateTime.now(), // First review is today
      interval: 0, // First review is today
      easeFactor: 2.5, // Default ease factor
      repetition: 0, // Not reviewed yet
      languageLevel: languageLevel,
      priority: priority,
      reviewHistory: [],
    );
  }

  /// Calculate next review based on SM2 algorithm
  SRSCard calculateNextReview(int quality) {
    int newInterval = interval;
    double newEaseFactor = easeFactor;
    int newRepetition = repetition;
    
    // Quality: 0-5 (0=wrong, 1-2=hard, 3=good, 4-5=easy)
    if (quality < 3) {
      // Failed or hard
      newRepetition = 0;
      newInterval = 1; // Review tomorrow
    } else {
      // Correct
      if (repetition == 0) {
        newInterval = 1; // First review after 1 day
      } else if (repetition == 1) {
        newInterval = 6; // Second review after 6 days
      } else {
        newInterval = (interval * easeFactor).round();
      }
      
      newRepetition = repetition + 1;
    }
    
    // Adjust ease factor based on quality
    newEaseFactor = (easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))).clamp(1.3, 3.0);
    
    // Ensure minimum interval of 1 day
    newInterval = newInterval > 0 ? newInterval : 1;
    
    return SRSCard(
      id: id,
      word: word,
      reading: reading,
      meaning: meaning,
      createdAt: createdAt,
      nextReview: DateTime.now().add(Duration(days: newInterval)),
      interval: newInterval,
      easeFactor: newEaseFactor,
      repetition: newRepetition,
      languageLevel: languageLevel,
      priority: priority,
      reviewHistory: [...reviewHistory, DateTime.now()],
    );
  }

  /// Check if card is due for review
  bool get isDue => DateTime.now().isAfter(nextReview);

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'reading': reading,
      'meaning': meaning,
      'createdAt': createdAt.toIso8601String(),
      'nextReview': nextReview.toIso8601String(),
      'interval': interval,
      'easeFactor': easeFactor,
      'repetition': repetition,
      'languageLevel': languageLevel,
      'priority': priority,
      'reviewHistory': reviewHistory.map((date) => date.toIso8601String()).toList(),
    };
  }

  /// Create from JSON
  factory SRSCard.fromJson(Map<String, dynamic> json) {
    return SRSCard(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      meaning: json['meaning'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      nextReview: DateTime.parse(json['nextReview'] as String),
      interval: json['interval'] as int,
      easeFactor: (json['easeFactor'] as num).toDouble(),
      repetition: json['repetition'] as int,
      languageLevel: json['languageLevel'] as int,
      priority: json['priority'] as int,
      reviewHistory: (json['reviewHistory'] as List<dynamic>)
          .map((date) => DateTime.parse(date as String))
          .toList(),
    );
  }

  /// Copy with updated values
  SRSCard copyWith({
    String? id,
    String? word,
    String? reading,
    String? meaning,
    DateTime? createdAt,
    DateTime? nextReview,
    int? interval,
    double? easeFactor,
    int? repetition,
    int? languageLevel,
    int? priority,
    List<DateTime>? reviewHistory,
  }) {
    return SRSCard(
      id: id ?? this.id,
      word: word ?? this.word,
      reading: reading ?? this.reading,
      meaning: meaning ?? this.meaning,
      createdAt: createdAt ?? this.createdAt,
      nextReview: nextReview ?? this.nextReview,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      repetition: repetition ?? this.repetition,
      languageLevel: languageLevel ?? this.languageLevel,
      priority: priority ?? this.priority,
      reviewHistory: reviewHistory ?? this.reviewHistory,
    );
  }
}