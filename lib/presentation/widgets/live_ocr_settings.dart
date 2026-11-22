import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/live_ocr/live_ocr_controller.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Settings for the live-OCR loop: whether it runs, how often it
/// captures, how many identical readings it needs before translating,
/// and what the overlay shows.
class LiveOcrSettings extends StatelessWidget {
  const LiveOcrSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;
    // The controller is absent in previews and tests that do not mount
    // the app shell; there is nothing to report then.
    //
    // The lookup must be for the non-nullable type: provider matches
    // the requested type exactly, so `watch<LiveOcrController?>()` does
    // not find a registered `LiveOcrController` and yields null — which
    // left the loop's state unread and its toggle inert.
    LiveOcrController? controller;
    try {
      controller = context.watch<LiveOcrController>();
    } catch (_) {
      controller = null;
    }
    final unsupported = controller?.isUnsupported ?? false;
    // every control is inert without screen capture
    final enabled = appState.liveOcrEnabled && !unsupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unsupported) ...[
          Text(
            l10n.liveOcrUnsupported,
            style: TextStyle(
              fontSize: fs(context, 12, 'ui'),
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 4),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.liveOcrEnable),
          subtitle: Text(l10n.liveOcrEnableSubtitle),
          value: appState.liveOcrEnabled,
          onChanged: unsupported
              ? null
              : (v) {
                  appState.setLiveOcrEnabled(v);
                  // start or stop the loop right away instead of
                  // waiting for the controller's debounce
                  controller?.applyEnabledSetting();
                },
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.liveOcrFullscreen),
          subtitle: Text(l10n.liveOcrFullscreenSubtitle),
          value: appState.liveOcrUseFullscreen,
          onChanged: enabled
              ? (v) => appState.setLiveOcrUseFullscreen(v)
              : null,
        ),
        const Divider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.liveOcrShowTranslation),
          subtitle: Text(l10n.liveOcrShowTranslationSubtitle),
          value: appState.liveOcrShowTranslation,
          onChanged: enabled
              ? (v) => appState.setLiveOcrShowTranslation(v)
              : null,
        ),
        const SizedBox(height: 8),
        _LabeledSlider(
          label: l10n.liveOcrCaptureInterval,
          valueLabel: '${appState.liveOcrIntervalSec}s',
          value: appState.liveOcrIntervalSec.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          enabled: enabled,
          onChanged: (v) => appState.setLiveOcrIntervalSec(v.round()),
        ),
        _LabeledSlider(
          label: l10n.liveOcrStableReads,
          valueLabel: '${appState.liveOcrRequiredRepeats}x',
          value: appState.liveOcrRequiredRepeats.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          enabled: enabled,
          onChanged: (v) => appState.setLiveOcrRequiredRepeats(v.round()),
        ),
      ],
    );
  }
}

/// A labelled slider with the current value shown next to the label.
class _LabeledSlider extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: fs(context, 13),
              color: enabled
                  ? null
                  : Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.38,
                    ),
            ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: fs(context, 13)),
          ),
        ),
      ],
    );
  }
}
