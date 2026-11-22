/// Immutable snapshot of one live-OCR pass.
///
/// A pass is one capture + OCR cycle. [sourceText] is what the
/// recognizer read, [translation] the (possibly still pending) rendering
/// of it into the target language, and [confidence] the recognizer's own
/// score. [stable] marks the text that passed the stability gate, i.e.
/// the text that has been seen unchanged often enough to be worth
/// showing and translating.
class LiveOcrResult {
  /// Raw text as recognised in this pass.
  final String sourceText;

  /// Translation of [sourceText], or null while it is still pending or
  /// the translation call failed.
  final String? translation;

  /// Recognizer confidence in [0, 1], 0 when the backend reports none.
  final double confidence;

  /// True when this pass produced text that passed the stability gate.
  final bool stable;

  /// Number of consecutive passes that produced [sourceText].
  final int repeatCount;

  /// When this pass completed.
  final DateTime timestamp;

  const LiveOcrResult({
    required this.sourceText,
    this.translation,
    this.confidence = 0.0,
    this.stable = false,
    this.repeatCount = 0,
    required this.timestamp,
  });

  /// Whether there is anything worth displaying.
  bool get hasText => sourceText.trim().isNotEmpty;

  LiveOcrResult copyWith({
    String? sourceText,
    String? translation,
    double? confidence,
    bool? stable,
    int? repeatCount,
    DateTime? timestamp,
  }) => LiveOcrResult(
    sourceText: sourceText ?? this.sourceText,
    translation: translation ?? this.translation,
    confidence: confidence ?? this.confidence,
    stable: stable ?? this.stable,
    repeatCount: repeatCount ?? this.repeatCount,
    timestamp: timestamp ?? this.timestamp,
  );
}
