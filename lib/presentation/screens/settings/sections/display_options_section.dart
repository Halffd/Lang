import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/app_state.dart';

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
                  onChanged: (value) {
                    appState.setShowParticles(value);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(localizations.showKanji),
                  subtitle: Text(localizations.displayKanjiInfo),
                  value: appState.showKanji,
                  onChanged: (value) {
                    appState.setShowKanji(value);
                  },
                ),
                const Divider(),
                ListTile(
                  title: Text(localizations.minFrequency),
                  subtitle: Text(localizations.filterByFrequency),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      controller: TextEditingController(text: appState.minFrequency.toString()),
                      onChanged: (value) {
                        final intValue = int.tryParse(value);
                        if (intValue != null) {
                          appState.setMinFrequency(intValue);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}