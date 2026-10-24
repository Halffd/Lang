/// Pure SM-2 scheduling math.
///
/// Extracted from the app's SRS card entity so the state machine is
/// reusable and independently testable. Storage (persisting cards) and
/// review UI stay host-side.
class SrsScheduler {
  SrsScheduler._();

  static const double initialEaseFactor = 2.5;
  static const double minEaseFactor = 1.3;

  /// SM-2 transition for one answered review.
  ///
  /// [quality] is the 0–5 grade; below 3 resets the repetition. Returns
  /// the updated state; the host turns [intervalDays] into a concrete
  /// next-review date.
  static ScheduleResult schedule({
    required double easeFactor,
    required int reviewCount,
    required int quality,
    bool suspended = false,
  }) {
    if (suspended) {
      return ScheduleResult(
        easeFactor: easeFactor,
        reviewCount: reviewCount,
        intervalDays: 0,
        newCard: false,
      );
    }

    var newEaseFactor =
        easeFactor + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (newEaseFactor < minEaseFactor) newEaseFactor = minEaseFactor;

    var newRepetition = reviewCount + 1;
    int newInterval;
    var isLearning = false;

    if (quality < 3) {
      newRepetition = 0;
      newInterval = 0;
      isLearning = true;
    } else if (reviewCount == 0) {
      newInterval = 1;
      isLearning = true;
    } else if (reviewCount == 1) {
      newInterval = 6;
    } else {
      newInterval = (reviewCount * newEaseFactor).round();
    }

    return ScheduleResult(
      easeFactor: newEaseFactor,
      reviewCount: newRepetition,
      intervalDays: newInterval,
      newCard: isLearning,
    );
  }
}

class ScheduleResult {
  final double easeFactor;
  final int reviewCount;
  final int intervalDays;

  /// True when the card is (back) in the learning state — hosts map this
  /// to their own card-type enum.
  final bool newCard;

  const ScheduleResult({
    required this.easeFactor,
    required this.reviewCount,
    required this.intervalDays,
    required this.newCard,
  });
}
