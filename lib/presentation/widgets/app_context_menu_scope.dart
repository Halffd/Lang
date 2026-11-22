import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/cjk_text_extractor.dart';

/// App-wide right-click menu for non-editable content.
///
/// Flutter only shows a context menu inside text fields and
/// selectable regions; right-clicking anywhere else (a word card, a
/// sentence, a plain label) does nothing. This scope listens for the
/// secondary pointer button, resolves the word under the cursor with
/// the same [CjkTextExtractor] the popup dictionary uses, and shows a
/// small menu with the actions that apply to that word.
///
/// Editable fields and selectable regions are left alone: Flutter
/// shows their own toolbar there, and this scope must not steal the
/// click.
class AppContextMenuScope extends StatefulWidget {
  final Widget child;

  /// Invoked when the user picks "Look up" for the word under the
  /// cursor. Defaults to the popup dictionary's lookup pipeline.
  final void Function(String term, String sentence)? onLookUp;

  /// Invoked when the user picks "Copy" for the word under the cursor.
  final void Function(String text)? onCopy;

  const AppContextMenuScope({
    super.key,
    required this.child,
    this.onLookUp,
    this.onCopy,
  });

  @override
  State<AppContextMenuScope> createState() => _AppContextMenuScopeState();
}

class _AppContextMenuScopeState extends State<AppContextMenuScope> {
  void _handlePointerDown(PointerDownEvent event) {
    // only the secondary (right) mouse button
    if (event.buttons & kSecondaryMouseButton == 0) return;

    // an editable field or a selectable region handles its own
    // right-click — leave the event to it
    if (_hitsSelectionTarget(event.position)) return;

    final hit = _extractAt(event.position);
    if (hit == null) return;

    // when the popup dictionary is explicitly armed for right-click it
    // owns the press; otherwise this menu does
    final trigger = PopupDictionaryController.instance.config.effectiveTrigger(
      PopupDictionaryController.instance.activeProfileName,
    );
    if (trigger == PopupTrigger.rightClick) return;

    _showMenu(event.position, hit);
  }

  /// Whether a text selection target (editable field or selectable
  /// region) sits under [position].
  bool _hitsSelectionTarget(Offset position) {
    for (final view in RendererBinding.instance.renderViews) {
      final result = HitTestResult();
      view.hitTest(result, position: position);
      for (final entry in result.path) {
        final target = entry.target;
        if (target is RenderEditable) return true;
        if (target is RenderParagraph && target.registrar != null) return true;
      }
    }
    return false;
  }

  /// The word under [position], using the popup dictionary's scanner
  /// so both agree on what "the word under the cursor" means.
  CjkHit? _extractAt(Offset position) {
    final controller = PopupDictionaryController.instance;
    final extractor = CjkTextExtractor();
    return extractor.extractAt(position, controller.config);
  }

  Future<void> _showMenu(Offset position, CjkHit hit) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final theme = Theme.of(context);
    final anchor = Rect.fromLTWH(position.dx, position.dy, 1, 1);
    final view = View.of(context);
    final screenSize = Size(
      view.physicalSize.width / view.devicePixelRatio,
      view.physicalSize.height / view.devicePixelRatio,
    );

    final lookUp = widget.onLookUp ??
        (String term, String sentence) =>
            PopupDictionaryController.instance.showLookupFor(term);
    final copy = widget.onCopy ??
        (String text) => Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    // the app always installs the localizations; fall back to plain
    // labels when the widget is used without them (tests)
    final lookUpLabel = l10n?.contextLookUp(hit.term) ?? 'Look up ${hit.term}';
    final copyLabel = l10n?.contextCopy(hit.term) ?? 'Copy ${hit.term}';
    final copySentenceLabel = l10n?.contextCopySentence ?? 'Copy sentence';

    await showMenu<String>(
      context: context,
      color: theme.colorScheme.surfaceContainerHighest,
      position: RelativeRect.fromRect(anchor, Offset.zero & screenSize),
      items: [
        PopupMenuItem<String>(
          value: 'lookup',
          child: Row(
            children: [
              const Icon(Icons.travel_explore, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  lookUpLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_rounded, size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  copyLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (hit.sentence.trim() != hit.term.trim())
          PopupMenuItem<String>(
            value: 'copy_sentence',
            child: Row(
              children: [
                const Icon(Icons.notes_rounded, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    copySentenceLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((selection) {
      switch (selection) {
        case 'lookup':
          lookUp(hit.term, hit.sentence);
        case 'copy':
          copy(hit.term);
        case 'copy_sentence':
          copy(hit.sentence);
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: widget.child,
    );
  }
}
