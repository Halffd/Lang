import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/app_state.dart';

class SearchSettingsSection extends StatelessWidget {
  const SearchSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.searchSettings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.searchOptions, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(localizations.clipboardMonitor),
                  subtitle: Text(localizations.autoSearchClipboard),
                  value: appState.clipboardMonitor,
                  onChanged: (value) => appState.setClipboardMonitor(value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}