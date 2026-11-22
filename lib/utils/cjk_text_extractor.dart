import 'package:flutter/rendering.dart';

import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/utils/popup_scan_blocker.dart';

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
  /// The character a `WidgetSpan` contributes to the plain text of the
  /// span tree that embeds it (U+FFFC, object replacement).
  static const String _placeholder = '￼';

  /// Extract term + sentence at [position]. Returns null when no
  /// text paragraph is hit or nothing CJK/valid passes the config
  /// gates.
  CjkHit? extractAt(Offset position, PopupDictionaryConfig config) {
    final target = _textTargetAt(position);
    if (target == null) return null;

    final box = target.box;
    final local = _globalToLocal(box, position);
    var offset = target.offsetAt(local);
    var fullText = target.text?.toPlainText() ?? '';
    if (fullText.isEmpty) return null;

    if (fullText.contains(_placeholder)) {
      // The paragraph mixes annotated words (held in inline widgets) and
      // plain text. The placeholder stands for an annotated word, so it
      // is dropped from the text and the offset is shifted with it. The
      // placeholder then acts as a word boundary, which is what the
      // plain part of the line needs.
      final dropped = _placeholderCount(fullText.substring(0, offset));
      fullText = fullText.replaceAll(_placeholder, '');
      offset = (offset - dropped).clamp(0, fullText.length);
    }

    final hit = extractAtPosition(fullText, offset, config);
    return hit;
  }

  /// The number of placeholders in [text].
  static int _placeholderCount(String text) {
    var count = 0;
    for (final unit in text.codeUnits) {
      if (unit == 0xFFFC) count++;
    }
    return count;
  }

  /// Whether [target] annotates a menu (a dropdown's open list, a
  /// popup menu, or a combo box).
  ///
  /// The app's own dropdowns show localized labels and engine names.
  /// Those are chrome, not study text, so the popup dictionary must
  /// not fire over them. Flutter's dropdown menu wraps its items in
  /// `Semantics(role: SemanticsRole.menu, scopesRoute: true)`, so the
  /// role is a reliable marker for "the pointer is over a menu".
  static bool _isMenuSemantics(Object target) {
    if (target is! RenderSemanticsAnnotations) return false;
    final role = target.properties.role;
    if (role == null) return false;
    return role == SemanticsRole.menu ||
        role == SemanticsRole.menuBar ||
        role == SemanticsRole.menuItem ||
        role == SemanticsRole.menuItemCheckbox ||
        role == SemanticsRole.menuItemRadio ||
        role == SemanticsRole.comboBox;
  }

  _TextTarget? _textTargetAt(Offset position) {
    final binding = RendererBinding.instance;
    for (final view in binding.renderViews) {
      final result = HitTestResult();
      view.hitTest(result, position: position);

      // The hit-test path runs from the most specific target to the
      // least, so the innermost paragraph comes first. An annotated
      // word is two paragraphs in one inline widget — the reading and
      // the word — and the pointer can be on either of them, so the
      // paragraphs are collected and the outermost one that owns the
      // annotated widget decides what the word is.
      final paragraphs = <RenderParagraph>[];
      RenderEditable? editable;
      var blocked = false;
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderParagraph) {
          paragraphs.add(target);
        } else if (target is RenderEditable) {
          editable ??= target;
        } else if (target is RenderPopupScanBlocker) {
          // the text under the pointer lives inside UI chrome marked
          // as not-scannable (localized labels, buttons, nav bars):
          // never pop the dictionary over the app's own widgets
          blocked = true;
        } else if (_isMenuSemantics(target)) {
          // the pointer is over an open dropdown/popup menu: its items
          // are the app's own labels, not study text
          blocked = true;
        }
      }
      if (blocked) return null;

      // the outermost paragraph comes last in the path
      for (final paragraph in paragraphs.reversed) {
        final annotated = _annotatedWordAt(paragraph, position);
        if (annotated != null) return annotated;
      }
      if (paragraphs.isNotEmpty) {
        final paragraph = paragraphs.first;
        return _TextTarget(
          box: paragraph,
          text: paragraph.text,
          offsetAt: (local) => paragraph.getPositionForOffset(local).offset,
        );
      }
      if (editable != null) {
        final field = editable;
        return _TextTarget(
          box: field,
          text: field.text,
          offsetAt: (local) => field.getPositionForPoint(local).offset,
        );
      }
    }
    return null;
  }

  /// The annotated word under [position], if the paragraph owns one.
  ///
  /// A paragraph built from `Text.rich` with `WidgetSpan` children (the
  /// reading annotations draw the kana above the kanji that way) keeps
  /// the annotated text inside the inline widgets, not in the span
  /// tree: the span tree only holds the object-replacement
  /// placeholder. So the annotated text has to be looked up in the
  /// inline children explicitly.
  ///
  /// An annotated word draws the reading above the word in one widget,
  /// so the widget holds two paragraphs: the reading and the word
  /// itself. The word is the one to look up, whichever of the two the
  /// pointer is on: pointing at the reading looks the word up too. The
  /// word is the lower of the two, so the paragraph whose box reaches
  /// lowest is the word.
  _TextTarget? _annotatedWordAt(RenderParagraph paragraph, Offset position) {
    final words = <RenderParagraph>[];
    paragraph.visitChildren((RenderObject child) {
      if (words.isNotEmpty) return;
      if (child is! RenderBox) return;
      if (!_containsGlobal(child, position)) return;
      final base = _baseParagraph(child);
      if (base != null) words.add(base);
    });
    if (words.isEmpty) return null;
    final base = words.first;
    return _TextTarget(
      box: base,
      text: base.text,
      // the pointer can sit on the reading above the word, which is
      // outside the word's own box; clamp it in so the offset lands
      // on the word
      offsetAt: (local) => base
          .getPositionForOffset(
            Offset(
              local.dx.clamp(0.0, base.size.width),
              local.dy.clamp(0.0, base.size.height),
            ),
          )
          .offset,
    );
  }

  /// The word paragraph of an annotated widget: the one whose box
  /// reaches lowest, which is the word under its reading.
  ///
  /// A widget that holds a single paragraph is that paragraph.
  RenderParagraph? _baseParagraph(RenderBox box) {
    RenderParagraph? lowest;
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        if (lowest == null || _globalBottom(node) > _globalBottom(lowest!)) {
          lowest = node;
        }
        return;
      }
      if (node is RenderBox) node.visitChildren(visit);
    }

    visit(box);
    return lowest;
  }

  /// The bottom edge of [box] in global coordinates.
  double _globalBottom(RenderBox box) {
    final matrix = box.getTransformTo(null);
    return matrix.getTranslation().y + box.size.height;
  }

  /// Whether [position] (global) falls inside [box].
  bool _containsGlobal(RenderBox box, Offset position) {
    final matrix = box.getTransformTo(null);
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return false;
    final local = MatrixUtils.transformPoint(inverse, position);
    return box.size.contains(local);
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
