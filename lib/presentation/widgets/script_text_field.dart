import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lang/utils/japanese_utils.dart';
import 'package:lang/utils/script_converter.dart';

/// TextField that converts romanized latin input to the target
/// language's native script as the user types.
///
/// For Japanese: romaji -> hiragana; holding Shift (or caps) at
/// release converts the trailing syllable to katakana.
/// For other languages (ko, ru, he, ar, hi, th, zh): converts the
/// trailing romanized word to native script on word boundary
/// (space/punctuation) or on blur.
class ScriptTextField extends StatefulWidget {
  final TextEditingController controller;
  final String language;
  final bool enabled;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;

  const ScriptTextField({
    super.key,
    required this.controller,
    required this.language,
    required this.enabled,
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.style,
  });

  @override
  State<ScriptTextField> createState() => _ScriptTextFieldState();
}

class _ScriptTextFieldState extends State<ScriptTextField> {
  final FocusNode _internalFocus = FocusNode();
  bool _shiftHeld = false;

  FocusNode get _effectiveFocus => widget.focusNode ?? _internalFocus;

  @override
  void initState() {
    super.initState();
    _effectiveFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _effectiveFocus.removeListener(_onFocusChanged);
    _internalFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_effectiveFocus.hasFocus) {
      _convertAll();
    }
  }

  bool get _isJapanese => widget.language == 'ja';

  /// Convert the trailing romanized run to native script.
  /// For Japanese this is per-syllable; for others, whole words.
  void _convertTail() {
    if (!widget.enabled) return;
    final text = widget.controller.text;
    if (text.isEmpty) return;

    // find start of the trailing romanized run
    int start = text.length;
    while (start > 0) {
      final c = text[start - 1];
      if (_isRomajiChar(c) || c == '\'') {
        start--;
      } else {
        break;
      }
    }
    if (start == text.length) return; // nothing to convert

    final tail = text.substring(start);
    String converted;
    if (_isJapanese) {
      converted = JapaneseUtils.romajiToKana(tail, katakana: _shiftHeld);
    } else {
      converted = ScriptConverter.latinToScript(tail, widget.language);
    }
    if (converted == tail) return;

    _replaceRange(start, text.length, converted);
  }

  /// Convert every romanized word in the whole text (used on blur).
  void _convertAll() {
    if (!widget.enabled) return;
    final text = widget.controller.text;
    if (text.isEmpty) return;
    if (!ScriptConverter.supportsLatinToScript(widget.language)) return;

    // regex-replace each romanized word run
    final wordRun = RegExp("[a-zA-Z][a-zA-Z']*");
    final converted = text.replaceAllMapped(
      wordRun,
      (m) {
        final word = m.group(0)!;
        if (_isJapanese) {
          return JapaneseUtils.romajiToKana(word);
        }
        return ScriptConverter.latinToScript(word, widget.language);
      },
    );
    if (converted != text) {
      widget.controller.text = converted;
      widget.controller.selection = TextSelection.collapsed(
        offset: converted.length,
      );
    }
  }

  void _replaceRange(int start, int end, String replacement) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final newText =
        text.substring(0, start) + replacement + text.substring(end);
    final delta = replacement.length - (end - start);
    widget.controller.text = newText;
    final newOffset = (sel.baseOffset < 0
            ? newText.length
            : (sel.baseOffset + delta))
        .clamp(0, newText.length);
    widget.controller.selection = TextSelection.collapsed(offset: newOffset);
  }

  bool _isRomajiChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x41 && code <= 0x5A);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (!_isJapanese) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _shiftHeld = true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _convertTail();
        _shiftHeld = false;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // NOTE: the Focus wrapper uses its own internal node; the
    // TextField uses the user-provided (or internal) node. Key
    // events on the text field bubble up to the wrapper, where
    // onKeyEvent observes shift state. Passing the same node to
    // both would re-parent it under itself and crash.
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _handleKey,
      child: TextField(
        controller: widget.controller,
        decoration: widget.decoration,
        focusNode: _effectiveFocus,
        autofocus: widget.autofocus,
        maxLines: widget.maxLines,
        style: widget.style,
        onSubmitted: widget.onSubmitted,
        onChanged: (text) {
          if (_isJapanese) {
            _convertTail();
          } else {
            // non-Japanese: convert on word boundary (trailing space or
            // punctuation). Convert the run that just ended.
            _convertEndedWord(text);
          }
          widget.onChanged?.call(text);
        },
      ),
    );
  }

  /// For non-Japanese languages, when the user just typed a
  /// separator, convert the latin word that ended right before it.
  void _convertEndedWord(String text) {
    if (text.isEmpty) return;
    final last = text[text.length - 1];
    final separator = RegExp(r'[\s.,!?;:\-()「」『』。、]');
    if (!separator.hasMatch(last)) return;

    // find word before trailing separators
    int end = text.length - 1;
    while (end > 0 && separator.hasMatch(text[end - 1])) {
      end--;
    }
    int start = end;
    while (start > 0) {
      final c = text[start - 1];
      if (_isRomajiChar(c) || c == "'") {
        start--;
      } else {
        break;
      }
    }
    if (start >= end) return;
    final word = text.substring(start, end);
    final converted = ScriptConverter.latinToScript(word, widget.language);
    if (converted == word) return;
    _replaceRange(start, end, converted);
  }
}