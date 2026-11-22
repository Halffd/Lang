import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lang/presentation/widgets/app_context_menu.dart';

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
        // full action set in the right-click menu (the default hides
        // inapplicable actions, leaving a single button)
        contextMenuBuilder: AppContextMenu.editable,
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
      final newText = '${text.substring(0, pos)}\n${text.substring(pos)}';
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

/// A [SubmitTextField] that owns its controller.
///
/// A dialog that creates the controller itself has to dispose it after
/// the dialog is gone, but the dialog route animates out after its
/// future completes: disposing the controller at that point leaves the
/// still-mounted field using a disposed controller. Owning the
/// controller in the widget ties its lifetime to the widget's, so it
/// is disposed exactly when the field leaves the tree.
///
/// The current text is read through the state, so a confirm button
/// outside the field can hand it on.
class OwnedSubmitTextField extends StatefulWidget {
  final String initialText;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;
  final TextInputType? keyboardType;

  const OwnedSubmitTextField({
    super.key,
    this.initialText = '',
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
  OwnedSubmitTextFieldState createState() => OwnedSubmitTextFieldState();
}

class OwnedSubmitTextFieldState extends State<OwnedSubmitTextField> {
  late final TextEditingController _controller;

  /// The text currently in the field.
  String get text => _controller.text;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubmitTextField(
      controller: _controller,
      decoration: widget.decoration,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: widget.style,
      keyboardType: widget.keyboardType,
    );
  }
}

/// A plain [TextField] that owns its controller.
///
/// The same lifetime rule as [OwnedSubmitTextField]: a dialog that
/// disposes its controller when its future completes disposes it while
/// the field is still mounted and animating out.
class OwnedTextField extends StatefulWidget {
  final String initialText;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextStyle? style;
  final TextInputType? keyboardType;
  final bool useAppContextMenu;

  const OwnedTextField({
    super.key,
    this.initialText = '',
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines,
    this.minLines,
    this.focusNode,
    this.autofocus = false,
    this.style,
    this.keyboardType,
    this.useAppContextMenu = false,
  });

  @override
  OwnedTextFieldState createState() => OwnedTextFieldState();
}

class OwnedTextFieldState extends State<OwnedTextField> {
  late final TextEditingController _controller;

  /// The text currently in the field.
  String get text => _controller.text;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: widget.decoration,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      style: widget.style,
      keyboardType: widget.keyboardType,
      contextMenuBuilder: widget.useAppContextMenu
          ? AppContextMenu.editable
          : null,
    );
  }
}
