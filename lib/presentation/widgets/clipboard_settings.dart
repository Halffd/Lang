import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/clipboard_monitor_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/utils/font_scale.dart';

/// Clipboard monitor settings: mode selector (history only /
/// auto search / off) plus auto-search gates (focus, regex).
class ClipboardSettings extends StatefulWidget {
  const ClipboardSettings({super.key});

  @override
  State<ClipboardSettings> createState() => _ClipboardSettingsState();
}

class _ClipboardSettingsState extends State<ClipboardSettings> {
  late final TextEditingController _regexController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _regexController = TextEditingController(
      text: appState.clipboardAutoSearchRegex,
    );
  }

  @override
  void dispose() {
    _regexController.dispose();
    super.dispose();
  }

  void _setMode(AppState appState, ClipboardAutoSearchMode value) {
    appState.setClipboardAutoSearchMode(value);
    // stop or start monitoring right away
    ClipboardMonitorService.instance.restartMonitoring(appState);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.clipboardMonitorMode,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        RadioListTile<ClipboardAutoSearchMode>(
          title: Text(l10n.clipboardModeHistoryOnly),
          subtitle: Text(l10n.clipboardModeHistoryOnlyDesc),
          value: ClipboardAutoSearchMode.historyOnly,
          groupValue: appState.clipboardAutoSearchMode,
          onChanged: (value) {
            if (value != null) _setMode(appState, value);
          },
        ),
        RadioListTile<ClipboardAutoSearchMode>(
          title: Text(l10n.clipboardModeAutoSearch),
          subtitle: Text(l10n.clipboardModeAutoSearchDesc),
          value: ClipboardAutoSearchMode.autoSearch,
          groupValue: appState.clipboardAutoSearchMode,
          onChanged: (value) {
            if (value != null) _setMode(appState, value);
          },
        ),
        if (appState.clipboardAutoSearchMode ==
            ClipboardAutoSearchMode.autoSearch) ...[
          SwitchListTile(
            title: Text(l10n.autoSearchOnlyWhenFocused),
            subtitle: Text(l10n.autoSearchOnlyWhenFocusedDesc),
            value: appState.clipboardAutoSearchFocusedOnly,
            onChanged: appState.setClipboardAutoSearchFocusedOnly,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.autoSearchRegex,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.autoSearchRegexDesc,
                  style: TextStyle(
                    fontSize: fs(context, 12),
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _regexController,
                  decoration: InputDecoration(
                    hintText: l10n.autoSearchRegexHint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: appState.setClipboardAutoSearchRegex,
                ),
              ],
            ),
          ),
        ],
        RadioListTile<ClipboardAutoSearchMode>(
          title: Text(l10n.clipboardModeOff),
          subtitle: Text(l10n.clipboardModeOffDesc),
          value: ClipboardAutoSearchMode.off,
          groupValue: appState.clipboardAutoSearchMode,
          onChanged: (value) {
            if (value != null) _setMode(appState, value);
          },
        ),
      ],
    );
  }
}
