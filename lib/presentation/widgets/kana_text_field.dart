import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lang/utils/japanese_utils.dart';

/// TextField that converts romaji to kana as the user types, when
/// [enabled] is true. Shifted/caps input produces katakana.
///
/// Conversion rules:
/// - only converts when the current text has no CJK already typed after
///   the last conversion point (keeps mixed input sane)
/// - conversion happens per keystroke: trailing romaji syllable is
///   converted to hiragana (or katakana when shift/caps held)
class KanaTextField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final Widget? suffixIcon;
  final TextStyle? style;
  final String? hint;

  const KanaTextField({
    super.key,
    required this.controller,
    required this.enabled,
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
    this.focusNode,
    this.autofocus = false,
    this.suffixIcon,
    this.style,
    this.hint,
  });

  @override
  State<KanaTextField> createState() => _KanaTextFieldState();
}

class _KanaTextFieldState extends State<KanaTextField> {
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
      // On blur, convert any leftover romaji tail
      _convertTail(finalize: true);
    }
  }

  /// Convert trailing romaji of the current text to kana.
  /// Uses shift state to pick katakana vs hiragana.
  void _convertTail({bool finalize = false}) {
    if (!widget.enabled) return;
    final text = widget.controller.text;
    if (text.isEmpty) return;

    // Find the tail: trailing ASCII letters (plus pending 'n')
    int start = text.length;
    while (start > 0) {
      final c = text[start - 1];
      if (_isRomajiChar(c)) {
        start--;
      } else {
        break;
      }
    }

    // Don't convert tails that start mid-word (e.g. cursor moved).
    // Only convert from the start of the last latin run.
    final tail = text.substring(start);
    if (tail.isEmpty) return;

    final converted = JapaneseUtils.romajiToKana(
      tail,
      katakana: _shiftHeld,
    );
    if (converted != tail) {
      final sel = widget.controller.selection;
      final offsetDelta = converted.length - tail.length;
      widget.controller.text = text.substring(0, start) + converted;
      final newOffset = (sel.baseOffset + offsetDelta).clamp(
        0,
        widget.controller.text.length,
      );
      widget.controller.selection = TextSelection.collapsed(
        offset: newOffset,
      );
    }
  }

  bool _isRomajiChar(String c) {
    return (c.codeUnitAt(0) >= 0x61 && c.codeUnitAt(0) <= 0x7A) ||
        (c.codeUnitAt(0) >= 0x41 && c.codeUnitAt(0) <= 0x5A) ||
        c == '-' ||
        c == '\'';
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _shiftHeld = true;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
          event.logicalKey == LogicalKeyboardKey.shiftRight) {
        // Convert leftover tail with katakana, then clear
        _convertTail();
        _shiftHeld = false;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _effectiveFocus,
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
          _convertTail();
          widget.onChanged?.call(text);
        },
      ),
    );
  }
}