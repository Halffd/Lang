import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/app_state.dart';

class UiNavigationSection extends StatelessWidget {
  const UiNavigationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.uiAndNavigation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text(localizations.autoHideNavigation),
                  subtitle: Text(localizations.hideNavigationBottom),
                  value: appState.autoHideNavigation,
                  onChanged: (value) => appState.setAutoHideNavigation(value),
                ),
                SwitchListTile(
                  title: Text(localizations.autoPasteReader),
                  subtitle: Text(localizations.autoPasteReaderSubtitle),
                  value: appState.autoPasteReader,
                  onChanged: (value) => appState.setAutoPasteReader(value),
                ),
                SwitchListTile(
                  title: Text(localizations.autoSearchClipboard),
                  subtitle: Text(localizations.autoTranslateWords),
                  value: appState.autoSearchClipboard,
                  onChanged: (value) => appState.setAutoSearchClipboard(value),
                ),
                SwitchListTile(
                  title: Text(localizations.autoKanaConversion),
                  subtitle: Text(localizations.convertRomajiToKana),
                  value: appState.autoKanaConversion,
                  onChanged: (value) => appState.setAutoKanaConversion(value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.keyboardShortcuts, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Ctrl + 1: Search'),
                const Text('Ctrl + 2: Reader'),
                const Text('Ctrl + 3: Lists'),
                const Text('Ctrl + 4: Dictionaries'),
                const Text('Ctrl + 5: Translator'),
                const Text('Ctrl + 6: Settings'),
                const SizedBox(height: 8),
                Text(localizations.defaultScreen, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(localizations.defaultScreenSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'search', 'reader', 'lists', 'dictionaries', 'translator', 'settings', 'ai', 'srs'
                  ].map((screen) => FilterChip(
                    label: Text(screen.toUpperCase()),
                    selected: appState.defaultScreen == screen,
                    onSelected: (selected) => appState.setDefaultScreen(screen),
                    showCheckmark: false,
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}