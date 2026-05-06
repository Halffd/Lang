import 'package:uuid/uuid.dart';
import '../../domain/entities/srs_card.dart';
import '../../domain/entities/srs_review.dart';

class SrsService {
  static const double _minEaseFactor = 1.3;
  static const _uuid = Uuid();

  static String generateId() => _uuid.v4();

  SrsCard createCard({
    required String userId,
    String? deckId,
    String? wordId,
    required String front,
    required String back,
    String? reading,
  }) {
    final now = DateTime.now();
    return SrsCard(
      id: generateId(),
      userId: userId,
      deckId: deckId,
      wordId: wordId,
      front: front,
      back: back,
      reading: reading,
      easeFactor: 2.5,
      interval: 0,
      repetitions: 0,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  SrsCard processReview(SrsCard card, ReviewRating rating, {double intervalModifier = 1.0}) {
    final quality = rating.value;
    final now = DateTime.now();
    double newEaseFactor = card.easeFactor;
    int newInterval = card.interval;
    int newRepetitions = card.repetitions;

    if (quality < 3) {
      newRepetitions = 0;
      newInterval = 0;
    } else {
      newRepetitions = card.repetitions + 1;
      
      if (newRepetitions == 1) {
        newInterval = 1;
      } else if (newRepetitions == 2) {
        newInterval = 6;
      } else {
        newInterval = (card.interval * card.easeFactor * intervalModifier).round();
      }

      final efDelta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02);
      newEaseFactor = (card.easeFactor + efDelta).clamp(_minEaseFactor, 5.0);
    }

    final newDueDate = now.add(Duration(days: newInterval));

    return card.copyWith(
      easeFactor: newEaseFactor,
      interval: newInterval,
      repetitions: newRepetitions,
      dueDate: newDueDate,
      updatedAt: now,
      lastReviewedAt: now,
    );
  }

  SrsReview createReviewLog({
    required String userId,
    required String cardId,
    required int rating,
    int? timeTakenMs,
  }) {
    return SrsReview(
      id: generateId(),
      userId: userId,
      cardId: cardId,
      rating: rating,
      timeTakenMs: timeTakenMs,
      reviewedAt: DateTime.now(),
    );
  }

  List<SrsCard> getDueCards(List<SrsCard> cards) {
    final now = DateTime.now();
    return cards.where((card) => card.dueDate.isBefore(now) || card.dueDate.isAtSameMomentAs(now)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  Map<String, int> getSrsStats(List<SrsCard> cards) {
    final now = DateTime.now();
    int due = 0;
    int newCards = 0;
    int learning = 0;
    int mature = 0;

    for (final card in cards) {
      if (card.dueDate.isBefore(now) || card.dueDate.isAtSameMomentAs(now)) {
        due++;
      }
      if (card.repetitions == 0) {
        newCards++;
      } else if (card.interval < 21) {
        learning++;
      } else {
        mature++;
      }
    }

    return {
      'due': due,
      'new': newCards,
      'learning': learning,
      'mature': mature,
      'total': cards.length,
    };
  }
}