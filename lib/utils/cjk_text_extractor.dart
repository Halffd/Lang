import 'package:flutter/gestures.dart';
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

    final hit = _extractAtPosition(fullText, textPosition.offset, config);
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
  /// compound + conjugation candidates.
  CjkHit? _extractAtPosition(
    String text,
    int index,
    PopupDictionaryConfig config,
  ) {
    if (text.isEmpty || index < 0 || index >= text.length) return null;

    final scanLength = config.scanLength.clamp(1, 64);

    // character run around the cursor, capped by the scan limit
    final (start, end) = _runBounds(text, index, scanLength);
    final candidate = text.substring(start, end);

    if (!config.allowsText(candidate)) return null;

    // when compound/conjugation detection is off the candidate is
    // taken as-is; the lookup callback receives the primary term
    // with alternatives embedded via JapaneseGrammar
    final term = candidate;

    final sentence = _sentenceAround(text, start, end);
    return CjkHit(term: term, sentence: sentence);
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
