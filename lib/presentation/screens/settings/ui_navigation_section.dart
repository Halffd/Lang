import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/app_state.dart';

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
                const Divider(),
                SwitchListTile(
                  title: Text(localizations.defaultFlexMode),
                  subtitle: Text(localizations.useFlexibleGrid),
                  value: appState.defaultFlexMode,
                  onChanged: (value) => appState.setDefaultFlexMode(value),
                ),
                const Divider(),
                ListTile(
                  title: Text(localizations.keyboardShortcuts),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(localizations.ctrl1Search),
                      Text(localizations.ctrl2Reader),
                      Text(localizations.ctrl3Lists),
                      Text(localizations.ctrl4Dictionaries),
                      Text(localizations.ctrl5Translator),
                      Text(localizations.ctrl6Settings),
                    ],
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: Text(localizations.autoKanaConversion),
                  subtitle: Text(localizations.convertRomajiToKana),
                  value: appState.autoConvertJapanese,
                  onChanged: (value) => appState.setAutoConvertJapanese(value),
                ),
                const Divider(),
                ListTile(
                  title: Text(localizations.defaultScreen),
                  subtitle: Text(localizations.defaultScreenSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButtonFormField<int>(
                    value: (appState.defaultScreenIndex >= 0 && appState.defaultScreenIndex <= 5)
                        ? appState.defaultScreenIndex
                        : 0,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(value: 0, child: Text(localizations.search)),
                      DropdownMenuItem(value: 1, child: Text(localizations.reader)),
                      DropdownMenuItem(value: 2, child: Text(localizations.wordLists)),
                      DropdownMenuItem(value: 3, child: Text(localizations.dictionaries)),
                      DropdownMenuItem(value: 4, child: Text(localizations.translator)),
                      DropdownMenuItem(value: 5, child: Text(localizations.settings)),
                    ],
                    onChanged: (value) {
                      if (value != null) appState.setDefaultScreenIndex(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(localizations.zoomLevel),
                  subtitle: Text(localizations.zoomLevelSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: appState.zoomLevel,
                          min: 0.5,
                          max: 3.0,
                          divisions: 50,
                          label: '${appState.zoomLevel.toStringAsFixed(2)}x',
                          onChanged: (value) => appState.setZoomLevel(value),
                        ),
                      ),
                      Text('${appState.zoomLevel.toStringAsFixed(2)}x',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(localizations.fontSize),
                  subtitle: Text(localizations.fontSizeSubtitle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: appState.fontSizeMultiplier,
                          min: 0.8,
                          max: 2.0,
                          divisions: 24,
                          label: '${(appState.fontSizeMultiplier * 100).round()}%',
                          onChanged: (value) => appState.setFontSizeMultiplier(value),
                        ),
                      ),
                      Text('${(appState.fontSizeMultiplier * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
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