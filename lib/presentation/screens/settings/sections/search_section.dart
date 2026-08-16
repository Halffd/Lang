import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/app_state.dart';

class SearchSettingsSection extends StatelessWidget {
  const SearchSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.searchSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildCard(context, appState, localizations),
      ],
    );
  }

  Widget _buildCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
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
              value: appState.autoSearchClipboard,
              onChanged: (value) => appState.setAutoSearchClipboard(value),
            ),
            SwitchListTile(
              title: Text(localizations.clipboardAutoDetect),
              subtitle: Text(localizations.autoDetectProcessText),
              value: appState.clipboardAutoDetect,
              onChanged: (value) => appState.setClipboardAutoDetect(value),
            ),
            SwitchListTile(
              title: Text(localizations.highlightParticles),
              subtitle: Text(localizations.showParticles),
              value: appState.highlightParticles,
              onChanged: (value) => appState.setHighlightParticles(value),
            ),
          ],
        ),
      ),
    );
  }
}