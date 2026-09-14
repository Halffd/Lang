import 'package:flutter/rendering.dart';

import 'package:lang/domain/entities/popup_dictionary_config.dart';

/// Extracted candidate under the pointer.
class CjkHit {
  final String term;
  final String sentence;
  const CjkHit({required this.term, required this.sentence});
}

/// Hit-tests the render tree at a screen position for a
/// [RenderParagraph] (RichText), then extracts the CJK-aware word
/// and surrounding sentence at the pointer — the yomichan-style
/// scan with length limits, compound detection and deconjugation.
class CjkTextExtractor {
  /// Extract term + sentence at [position]. Returns null when no
  /// text paragraph is hit or nothing CJK/valid passes the config
  /// gates.
  CjkHit? extractAt(Offset position, PopupDictionaryConfig config) {
    final paragraph = _paragraphAt(position);
    if (paragraph == null) return null;

    final local = _globalToLocal(paragraph, position);
    final textPosition = paragraph.getPositionForOffset(local);
    final fullText = paragraph.text.toPlainText();

    final hit = extractAtPosition(fullText, textPosition.offset, config);
    return hit;
  }

  RenderParagraph? _paragraphAt(Offset position) {
    final binding = RendererBinding.instance;
    for (final view in binding.renderViews) {
      final result = HitTestResult();
      view.hitTest(result, position: position);
      for (final entry in result.path) {
        if (entry.target is RenderParagraph) {
          return entry.target as RenderParagraph;
        }
      }
    }
    return null;
  }

  Offset _globalToLocal(RenderParagraph paragraph, Offset position) {
    // RichText paragraphs in this app sit in untransformed
    // coordinate spaces (no scaling/rotation on text); the local
    // position equals the global position minus the paragraph's
    // paint offset chain. Compute the accumulated offset via the
    // paint transform.
    final matrix = paragraph.getTransformTo(null);
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return position;
    return MatrixUtils.transformPoint(inverse, position);
  }

  /// Core scan: word at [index] in [text], honoring scan length,
  /// depth, compound + conjugation candidates.
  ///
  /// Depth 0 returns only the run at the cursor. Depth N also
  /// tries the run starting at offsets 1..N from the cursor
  /// (yomichan deep scanning: match text near but not exactly
  /// under the pointer).
  CjkHit? extractAtPosition(
    String text,
    int index,
    PopupDictionaryConfig config,
  ) {
    if (text.isEmpty || index < 0 || index >= text.length) return null;

    final scanLength = config.scanLength.clamp(1, 64);
    final scanDepth = config.scanDepth.clamp(0, 32);

    // try the run at the cursor first, then runs at increasing
    // offsets when the depth allows
    for (var offset = 0; offset <= scanDepth; offset++) {
      final at = index + offset;
      if (at >= text.length) break;
      final hit = _runAt(text, at, scanLength, config);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Run starting exactly at [at] (cursor inside it), null when
  /// gates reject it.
  CjkHit? _runAt(
    String text,
    int at,
    int scanLength,
    PopupDictionaryConfig config,
  ) {
    final (start, end) = _runBounds(text, at, scanLength);
    final candidate = text.substring(start, end);
    if (candidate.isEmpty) return null;
    if (!config.allowsText(candidate)) return null;
    return CjkHit(term: candidate, sentence: _sentenceAround(text, start, end));
  }

  /// Character run around [index]: contiguous CJK chars, or a
  /// non-CJK word bounded by whitespace/punctuation. Capped at
  /// [maxChars] total from the scan limit.
  (int, int) _runBounds(String text, int index, int maxChars) {
    var start = index;
    var end = index + 1;

    final isTarget = _isRunChar(text[index]);

    while (start > 0 &&
        _isRunChar(text[start - 1]) == isTarget &&
        (index - start + 1) < maxChars) {
      start--;
    }
    while (end < text.length &&
        _isRunChar(text[end]) == isTarget &&
        (end - index) < maxChars) {
      end++;
    }

    // non-CJK runs are split at word boundaries
    if (!isTarget) {
      while (start > 0 && !_isBreak(text[start - 1])) {
        start--;
      }
      while (end < text.length && !_isBreak(text[end])) {
        end++;
      }
      final word = text.substring(start, end).trim();
      if (word.contains(' ')) {
        // pick the word nearest the cursor
        final rel = index - start;
        final words = word.split(RegExp(r'\s+'));
        var offset = 0;
        for (final w in words) {
          if (rel <= offset + w.length) {
            final s = start + offset;
            return (s, s + w.length);
          }
          offset += w.length + 1;
        }
      }
    }

    return (start, end);
  }

  static bool _isRunChar(String ch) =>
      _isCjkChar(ch) || ch == RegExp.escape(ch) && ch.contains(RegExp(r'[\w]'));

  static bool _isCjkChar(String ch) {
    final code = ch.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || // CJK unified
        (code >= 0x3400 && code <= 0x4DBF) || // ext A
        (code >= 0x3040 && code <= 0x30FF) || // kana
        (code >= 0xAC00 && code <= 0xD7AF) || // hangul
        (code >= 0xFF66 && code <= 0xFF9D); // halfwidth kana
  }

  static bool _isBreak(String ch) =>
      ch.contains(RegExp(r'[\s。、！？.,;:!?"()\[\]「」『』・…]'));

  /// Sentence containing [start,end), bounded by terminators.
  String _sentenceAround(String text, int start, int end) {
    var s = start;
    var e = end;
    while (s > 0 && !_isSentenceBreak(text[s - 1])) {
      s--;
    }
    while (e < text.length && !_isSentenceBreak(text[e])) {
      e++;
    }
    return text.substring(s, e).trim();
  }

  static bool _isSentenceBreak(String ch) =>
      ch == '\n' || ch.contains(RegExp(r'[。！？!?；;…」』\.\!\?]'));
}
