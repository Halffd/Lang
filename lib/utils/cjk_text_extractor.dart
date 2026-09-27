import 'package:flutter/rendering.dart';

import 'package:lang/domain/entities/popup_dictionary_config.dart';

/// Extracted candidate under the pointer.
class CjkHit {
  final String term;
  final String sentence;
  const CjkHit({required this.term, required this.sentence});
}

/// A text renderer found under the pointer, plus the renderer-specific
/// way to map a local point to a character offset.
class _TextTarget {
  final RenderBox box;
  final InlineSpan? text;
  final int Function(Offset local) offsetAt;

  const _TextTarget({
    required this.box,
    required this.text,
    required this.offsetAt,
  });
}

/// Hit-tests the render tree at a screen position for a text renderer,
/// then extracts the CJK-aware word and surrounding sentence at the
/// pointer — the yomichan-style scan with length limits, compound
/// detection and deconjugation.
///
/// Both [RenderParagraph] (plain `Text`/`RichText`) and [RenderEditable]
/// (`SelectableText`, and therefore the document reader's text mode) are
/// recognised. Only matching RenderParagraph meant selectable text was
/// invisible to the popup.
class CjkTextExtractor {
  /// Extract term + sentence at [position]. Returns null when no
  /// text paragraph is hit or nothing CJK/valid passes the config
  /// gates.
  CjkHit? extractAt(Offset position, PopupDictionaryConfig config) {
    final target = _textTargetAt(position);
    if (target == null) return null;

    final box = target.box;
    final local = _globalToLocal(box, position);
    final offset = target.offsetAt(local);
    final fullText = target.text?.toPlainText() ?? '';
    if (fullText.isEmpty) return null;

    final hit = extractAtPosition(fullText, offset, config);
    return hit;
  }

  _TextTarget? _textTargetAt(Offset position) {
    final binding = RendererBinding.instance;
    for (final view in binding.renderViews) {
      final result = HitTestResult();
      view.hitTest(result, position: position);
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderParagraph) {
          return _TextTarget(
            box: target,
            text: target.text,
            offsetAt: (local) => target.getPositionForOffset(local).offset,
          );
        }
        if (target is RenderEditable) {
          return _TextTarget(
            box: target,
            text: target.text,
            offsetAt: (local) => target.getPositionForPoint(local).offset,
          );
        }
      }
    }
    return null;
  }

  Offset _globalToLocal(RenderBox box, Offset position) {
    // text in this app sits in untransformed coordinate spaces (no
    // scaling/rotation); the local position equals the global position
    // minus the paint offset chain, computed via the paint transform.
    final matrix = box.getTransformTo(null);
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
