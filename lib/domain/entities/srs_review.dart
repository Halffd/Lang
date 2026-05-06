class SrsReview {
  final String id;
  final String userId;
  final String cardId;
  final int rating;
  final int? timeTakenMs;
  final DateTime reviewedAt;

  const SrsReview({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.rating,
    this.timeTakenMs,
    required this.reviewedAt,
  });

  factory SrsReview.fromMap(Map<String, dynamic> map) {
    return SrsReview(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      cardId: map['card_id'] as String,
      rating: map['rating'] as int,
      timeTakenMs: map['time_taken_ms'] as int?,
      reviewedAt: DateTime.parse(map['reviewed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'card_id': cardId,
      'rating': rating,
      'time_taken_ms': timeTakenMs,
      'reviewed_at': reviewedAt.toIso8601String(),
    };
  }
}

enum ReviewRating {
  again(0),
  hard(3),
  good(4),
  easy(5);

  final int value;
  const ReviewRating(this.value);
}