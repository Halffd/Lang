import 'package:flutter/material.dart';

import 'package:lang/l10n/app_localizations.dart';

/// Floating overlay showing the live-OCR text and its translation.
///
/// Draggable, so the user can move it out of the way of whatever they
/// are reading. Double-tapping it dismisses it until the next stable
/// reading arrives.
class LiveOcrOverlay extends StatefulWidget {
  /// The recognized source text.
  final String sourceText;

  /// The translation, or null while it is pending or unavailable.
  final String? translation;

  /// An error message shown instead of the text, or null.
  ///
  /// The loop reports capture and OCR failures here: without it a
  /// failing capture would look like the app is simply doing nothing.
  final String? error;

  /// Whether to show the translation line.
  final bool showTranslation;

  /// Called when the user dismisses the overlay.
  final VoidCallback? onDismiss;

  /// Font size of the source text.
  final double fontSize;

  const LiveOcrOverlay({
    super.key,
    required this.sourceText,
    this.translation,
    this.error,
    this.showTranslation = true,
    this.onDismiss,
    this.fontSize = 16,
  });

  @override
  State<LiveOcrOverlay> createState() => _LiveOcrOverlayState();
}

class _LiveOcrOverlayState extends State<LiveOcrOverlay> {
  Offset _offset = const Offset(16, 16);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translation = widget.translation;
    final error = widget.error;
    final showTranslation =
        widget.showTranslation &&
        translation != null &&
        translation.trim().isNotEmpty &&
        translation.trim() != widget.sourceText.trim();

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) =>
            setState(() => _offset += Offset(d.delta.dx, d.delta.dy)),
        onDoubleTap: () => widget.onDismiss?.call(),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? theme.colorScheme.error.withValues(alpha: 0.5)
                  : theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (error != null)
                Text(
                  '${AppLocalizations.of(context)?.liveOcrErrorPrefix ?? 'Live OCR'}: $error',
                  style: TextStyle(
                    fontSize: widget.fontSize * 0.85,
                    height: 1.4,
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else ...[
                Text(
                  widget.sourceText,
                  style: TextStyle(
                    fontSize: widget.fontSize,
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showTranslation) ...[
                  const SizedBox(height: 6),
                  Text(
                    translation,
                    style: TextStyle(
                      fontSize: widget.fontSize * 0.9,
                      height: 1.4,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
