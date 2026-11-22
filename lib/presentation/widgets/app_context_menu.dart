import 'package:flutter/material.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/l10n/app_localizations.dart';

/// Context-menu builders used across the app.
///
/// Flutter's default toolbar only renders the buttons whose callbacks
/// are non-null, so a right-click in an empty text field leaves a
/// single "Paste" button. This builder replaces the default with a
/// menu that always lists the full action set — inapplicable actions
/// are disabled, not hidden — and adds the app-specific look-up
/// action for the selected text.
///
/// Note that Flutter only honours `contextMenuBuilder` when the
/// widget's `selectionControls` mixes in `TextSelectionHandleControls`.
/// Every platform's default controls do, so the app must not override
/// `selectionControls` on the fields that use this builder.
class AppContextMenu {
  const AppContextMenu._();

  /// Toolbar for an editable field (also used by `SelectableText`,
  /// which drives its menu through the same `EditableTextState`).
  ///
  /// Always offers Cut / Copy / Paste / Select all plus "Look up" for
  /// the current selection. Read-only fields drop Cut and Paste
  /// instead of showing them greyed out.
  static Widget editable(BuildContext context, EditableTextState state) {
    final readOnly = state.widget.readOnly;
    final selection = _selectedText(state);
    final items = <ContextMenuButtonItem>[
      if (!readOnly)
        ContextMenuButtonItem(
          onPressed: state.cutEnabled
              ? () => state.cutSelection(SelectionChangedCause.toolbar)
              : null,
          kind: ContextMenuButtonKind.cut,
        ),
      ContextMenuButtonItem(
        onPressed: state.copyEnabled
            ? () => state.copySelection(SelectionChangedCause.toolbar)
            : null,
        kind: ContextMenuButtonKind.copy,
      ),
      if (!readOnly)
        ContextMenuButtonItem(
          onPressed: state.pasteEnabled
              ? () => state.pasteText(SelectionChangedCause.toolbar)
              : null,
          kind: ContextMenuButtonKind.paste,
        ),
      ContextMenuButtonItem(
        onPressed: state.selectAllEnabled
            ? () => state.selectAll(SelectionChangedCause.toolbar)
            : null,
        kind: ContextMenuButtonKind.selectAll,
      ),
      ContextMenuButtonItem(
        onPressed: selection.isEmpty
            ? null
            : () => PopupDictionaryController.instance.showLookupFor(selection),
        kind: ContextMenuButtonKind.custom,
        label: AppLocalizations.of(context)?.contextLookUpSelection ?? 'Look up',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: items,
      anchors: state.contextMenuAnchors,
    );
  }

  /// The text currently selected in [state], or an empty string.
  static String _selectedText(EditableTextState state) {
    final selection = state.textEditingValue.selection;
    if (!selection.isValid || selection.isCollapsed) return '';
    return state.textEditingValue.text.substring(selection.start, selection.end);
  }
}
