import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/app_state.dart';

class DisplayOptionsSection extends StatelessWidget {
  const DisplayOptionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.displayOptions, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(localizations.showParticles),
                  subtitle: Text(localizations.highlightParticles),
                  value: appState.showParticles,
                  onChanged: (value) => appState.setShowParticles(value),
                ),
                SwitchListTile(
                  title: Text(localizations.displayKanjiInfo),
                  subtitle: Text(localizations.japaneseKanjiOriginAndUsage),
                  value: appState.displayKanjiInfo,
                  onChanged: (value) => appState.setDisplayKanjiInfo(value),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}