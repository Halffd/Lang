import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TextField where Enter confirms and Ctrl+Enter inserts a newline —
/// the same contract [ScriptTextField] uses for the analyze input.
///
/// Plain multiline TextFields insert a newline on Enter and never fire
/// [onSubmitted], so keyboard users have no way to confirm. This widget
/// flips that: Enter submits, Ctrl+Enter (or Cmd+Enter) breaks the line.
class SubmitTextField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;
  final TextInputType? keyboardType;

  const SubmitTextField({
    super.key,
    required this.controller,
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines,
    this.minLines,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) => _handleKey(event),
      child: TextField(
        controller: controller,
        decoration: decoration,
        focusNode: focusNode,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: minLines,
        style: style,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
      ),
    );
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final ctrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (ctrl) {
      // Ctrl+Enter: newline at the caret
      final sel = controller.selection;
      final text = controller.text;
      final pos = sel.baseOffset < 0 ? text.length : sel.baseOffset;
      final newText = text.substring(0, pos) + '\n' + text.substring(pos);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + 1),
      );
      onChanged?.call(newText);
      return KeyEventResult.handled;
    }
    // plain Enter: confirm
    onSubmitted?.call(controller.text);
    return KeyEventResult.handled;
  }
}
