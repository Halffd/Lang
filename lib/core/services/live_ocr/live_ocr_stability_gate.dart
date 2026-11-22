/// Decides when a stream of OCR readings has settled enough to be
/// shown and translated.
///
/// Screen OCR re-reads the same pixels every pass, so the text jitters:
/// a stray space appears, a character is misread once, the line breaks
/// differently. Translating every pass would burn an API call per
/// frame and flash a different translation each time.
///
/// The gate therefore compares each reading against the previous one
/// after [normalize] has removed cosmetic differences, and only reports
/// a reading as stable once it has been seen [requiredRepeats] times
/// in a row. A different reading resets the counter.
class LiveOcrStabilityGate {
  /// How many consecutive identical readings are needed to pass the
  /// gate. 1 means every reading is immediately stable.
  ///
  /// Lowering the threshold does not by itself make the current reading
  /// stable: the repeat count still has to reach the new threshold.
  int requiredRepeats;

  /// Normalizes a reading before comparison. Defaults to
  /// [normalizeOcrText].
  final String Function(String) normalize;

  /// The last normalized reading seen.
  String? _lastNormalized;

  /// How many consecutive passes produced [_lastNormalized].
  int _repeatCount = 0;

  LiveOcrStabilityGate({
    this.requiredRepeats = 2,
    this.normalize = normalizeOcrText,
  }) : assert(requiredRepeats >= 1, 'requiredRepeats must be at least 1');

  /// The current consecutive-repeat count.
  int get repeatCount => _repeatCount;

  /// Whether the last reading passed the gate.
  bool get isStable => _repeatCount >= requiredRepeats;

  /// Feeds one reading through the gate.
  ///
  /// Returns true when this reading is stable — that is, when the text
  /// has now been seen [requiredRepeats] times in a row. Empty readings
  /// reset the counter and never pass.
  bool add(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) {
      reset();
      return false;
    }
    if (normalized == _lastNormalized) {
      _repeatCount++;
    } else {
      _lastNormalized = normalized;
      _repeatCount = 1;
    }
    return isStable;
  }

  /// Clears the gate state.
  void reset() {
    _lastNormalized = null;
    _repeatCount = 0;
  }
}

/// Normalizes OCR text for stability comparison.
///
/// Collapses all whitespace runs to a single space and trims the ends.
/// Cosmetic differences that OCR engines produce between two reads of
/// the same pixels (line wrapping, double spaces, trailing newlines)
/// then compare equal, while a genuinely different reading still
/// differs.
String normalizeOcrText(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();
