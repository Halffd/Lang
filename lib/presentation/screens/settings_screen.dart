import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/app_state.dart';
import '../../../domain/entities/translation_model.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String _getLanguageName(BuildContext context, String code) {
    final localizations = AppLocalizations.of(context)!;
    switch (code) {
      case 'ja':
        return localizations.japanese;
      case 'zh':
        return localizations.chinese;
      case 'ko':
        return localizations.korean;
      case 'en':
        return localizations.english;
      case 'fr':
        return localizations.french;
      case 'es':
        return localizations.spanish;
      case 'de':
        return localizations.german;
      case 'it':
        return localizations.italian;
      case 'pt':
        return localizations.portuguese;
      case 'ru':
        return localizations.russian;
      case 'ar':
        return localizations.arabic;
      case 'hi':
        return localizations.hindi;
      case 'af':
        return localizations.afrikaans;
      case 'bg':
        return localizations.bulgarian;
      case 'ca':
        return localizations.catalan;
      case 'hr':
        return localizations.croatian;
      case 'cs':
        return localizations.czech;
      case 'da':
        return localizations.danish;
      case 'nl':
        return localizations.dutch;
      case 'et':
        return localizations.estonian;
      case 'tl':
        return localizations.filipino;
      case 'fi':
        return localizations.finnish;
      case 'el':
        return localizations.greek;
      case 'iw':
        return localizations.hebrew;
      case 'hu':
        return localizations.hungarian;
      case 'id':
        return localizations.indonesian;
      case 'lv':
        return localizations.latvian;
      case 'lt':
        return localizations.lithuanian;
      case 'no':
        return localizations.norwegian;
      case 'pl':
        return localizations.polish;
      case 'ro':
        return localizations.romanian;
      case 'sr':
        return localizations.serbian;
      case 'sk':
        return localizations.slovak;
      case 'sl':
        return localizations.slovenian;
      case 'sv':
        return localizations.swedish;
      case 'th':
        return localizations.thai;
      case 'tr':
        return localizations.turkish;
      case 'uk':
        return localizations.ukrainian;
      case 'vi':
        return localizations.vietnamese;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // General settings section
          Text(
            AppLocalizations.of(context)!.generalSettings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Language selection
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.dictionaryLanguage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    value: () {
                      // Double-check that the value is valid at build time
                      final currentLang = appState.language;
                      if (LanguageOption.all.any((option) => option.code == currentLang)) {
                        return currentLang;
                      } else {
                        // If the value is invalid right now, return default
                        return 'ja';
                      }
                    }(),
                    items: [
                      for (final languageOption in LanguageOption.all)
                        DropdownMenuItem(
                          value: languageOption.code,
                          child: Text(_getLanguageName(context, languageOption.code)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        appState.setLanguage(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Theme settings
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.appearance,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Theme mode selection
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.themeMode),
                    subtitle: Text(AppLocalizations.of(context)!.themeModeSubtitle),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<ThemeMode>(
                      value: appState.themeMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(AppLocalizations.of(context)!.systemTheme),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(AppLocalizations.of(context)!.lightTheme),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(AppLocalizations.of(context)!.darkTheme),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          appState.setThemeMode(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),

          // Search settings section
          Text(
            AppLocalizations.of(context)!.uiAndNavigation,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                    title: Text(AppLocalizations.of(context)!.autoHideNavigation),
                    subtitle: Text(AppLocalizations.of(context)!.hideNavigationBottom),
                    value: appState.autoHideNavigation,
                    onChanged: (value) => appState.setAutoHideNavigation(value),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.defaultFlexMode),
                    subtitle: Text(AppLocalizations.of(context)!.useFlexibleGrid),
                    value: appState.defaultFlexMode,
                    onChanged: (value) => appState.setDefaultFlexMode(value),
                  ),
                  const Divider(),
                   ListTile(
                    title: Text(AppLocalizations.of(context)!.keyboardShortcuts),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context)!.ctrl1Search),
                        Text(AppLocalizations.of(context)!.ctrl2Reader),
                        Text(AppLocalizations.of(context)!.ctrl3Lists),
                        Text(AppLocalizations.of(context)!.ctrl4Dictionaries),
                        Text(AppLocalizations.of(context)!.ctrl5Translator),
                        Text(AppLocalizations.of(context)!.ctrl6Settings),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Auto-Kana conversion setting
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoKanaConversion),
                    subtitle: Text(AppLocalizations.of(context)!.convertRomajiToKana),
                    value: appState.autoConvertJapanese,
                    onChanged: (value) {
                      appState.setAutoConvertJapanese(value);
                    },
                  ),
                  const Divider(),
                  // Default screen selection
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.defaultScreen),
                    subtitle: Text(AppLocalizations.of(context)!.defaultScreenSubtitle),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<int>(
                      value: (appState.defaultScreenIndex >= 0 && appState.defaultScreenIndex <= 5)
                          ? appState.defaultScreenIndex
                          : 0, // fallback to 0 if current value is invalid
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(AppLocalizations.of(context)!.search),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(AppLocalizations.of(context)!.reader),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(AppLocalizations.of(context)!.wordLists),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(AppLocalizations.of(context)!.dictionaries),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text(AppLocalizations.of(context)!.translator),
                        ),
                        DropdownMenuItem(
                          value: 5,
                          child: Text(AppLocalizations.of(context)!.settings),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          appState.setDefaultScreenIndex(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Zoom level control
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.zoomLevel),
                    subtitle: Text(AppLocalizations.of(context)!.zoomLevelSubtitle),
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
                            divisions: 50, // Provides 0.05 increments between 0.5 and 3.0
                            label: '${appState.zoomLevel.toStringAsFixed(2)}x',
                            onChanged: (value) {
                              appState.setZoomLevel(value);
                            },
                          ),
                        ),
                        Text(
                          '${appState.zoomLevel.toStringAsFixed(2)}x',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Font size control
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.fontSize),
                    subtitle: Text(AppLocalizations.of(context)!.fontSizeSubtitle),
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
                            divisions: 24, // Provides 0.05 increments between 0.8 and 2.0
                            label: '${(appState.fontSizeMultiplier * 100).round()}%',
                            onChanged: (value) {
                              appState.setFontSizeMultiplier(value);
                            },
                          ),
                        ),
                        Text(
                          '${(appState.fontSizeMultiplier * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search settings section
          Text(
            AppLocalizations.of(context)!.searchSettings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Search options
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.searchOptions,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.clipboardMonitor),
                    subtitle: Text(AppLocalizations.of(context)!.autoSearchClipboard),
                    value: appState.clipboardMonitor,
                    onChanged: (value) {
                      appState.setClipboardMonitor(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Display options
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.displayOptions,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.showParticles),
                    subtitle: Text(AppLocalizations.of(context)!.highlightParticles),
                    value: appState.showParticles,
                    onChanged: (value) {
                      appState.setShowParticles(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.showKanji),
                    subtitle: Text(AppLocalizations.of(context)!.displayKanjiInfo),
                    value: appState.showKanji,
                    onChanged: (value) {
                      appState.setShowKanji(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.minFrequency),
                    subtitle: Text(AppLocalizations.of(context)!.filterByFrequency),
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
          ),

          const SizedBox(height: 16),

          // Advanced settings section
          Text(
            AppLocalizations.of(context)!.advancedSettings,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Anki Decks and Profiles settings
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.ankiProfiles,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Anki Deck Selection
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(AppLocalizations.of(context)!.currentAnkiDeck),
                      ),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: appState.ankiDecks.contains(appState.currentAnkiDeck)
                              ? appState.currentAnkiDeck
                              : (appState.ankiDecks.isNotEmpty ? appState.ankiDecks.first : 'Default'),
                          items: appState.ankiDecks.isNotEmpty
                              ? appState.ankiDecks.map((deck) {
                                  return DropdownMenuItem(
                                    value: deck,
                                    child: Text(deck),
                                  );
                                }).toList()
                              : [
                                  const DropdownMenuItem(
                                    value: 'Default',
                                    child: Text('Default'),
                                  )
                                ],
                          onChanged: (value) {
                            if (value != null) {
                              appState.setCurrentAnkiDeck(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Profile Selection
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(AppLocalizations.of(context)!.currentProfile),
                      ),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          value: appState.profiles.contains(appState.currentProfile)
                              ? appState.currentProfile
                              : (appState.profiles.isNotEmpty ? appState.profiles.first : 'Default'),
                          items: appState.profiles.isNotEmpty
                              ? appState.profiles.map((profile) {
                                  return DropdownMenuItem(
                                    value: profile,
                                    child: Text(profile),
                                  );
                                }).toList()
                              : [
                                  const DropdownMenuItem(
                                    value: 'Default',
                                    child: Text('Default'),
                                  )
                                ],
                          onChanged: (value) {
                            if (value != null) {
                              appState.setCurrentProfile(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Clipboard and Forvo settings
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.enhancedFeatures,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.clipboardAutoDetect),
                    subtitle: Text(AppLocalizations.of(context)!.autoDetectProcessText),
                    value: appState.clipboardAutoDetect,
                    onChanged: (value) {
                      appState.setClipboardAutoDetect(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.forvoAudio),
                    subtitle: Text(AppLocalizations.of(context)!.enableForvoPronunciations),
                    value: appState.forvoAudioEnabled,
                    onChanged: (value) {
                      appState.setForvoAudioEnabled(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoTranslation),
                    subtitle: Text(AppLocalizations.of(context)!.autoTranslateWords),
                    value: appState.autoTranslate,
                    onChanged: (value) {
                      appState.setAutoTranslate(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoPasteReader),
                    subtitle: Text(AppLocalizations.of(context)!.autoPasteReaderSubtitle),
                    value: appState.autoPasteReader,
                    onChanged: (value) {
                      appState.setAutoPasteReader(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // About section
          Text(
            AppLocalizations.of(context)!.about,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.appName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.version('1.0.0')),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.multilingualLearningTool,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // Open privacy policy
                    },
                    child: Text(AppLocalizations.of(context)!.privacyPolicy),
                  ),
                  TextButton(
                    onPressed: () {
                      // Open terms of service
                    },
                    child: Text(AppLocalizations.of(context)!.termsOfService),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
