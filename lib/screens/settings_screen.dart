import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../models/translation_model.dart';
import '../l10n/app_localizations.dart';

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
                    value: appState.language,
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
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.darkMode),
                    subtitle: Text(AppLocalizations.of(context)!.useDarkTheme),
                    value: appState.darkMode,
                    onChanged: (value) {
                      appState.setDarkMode(value);
                    },
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
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoKanaConversion),
                    subtitle: Text(AppLocalizations.of(context)!.convertRomajiToKana),
                    value: appState.automaticKanaConversion,
                    onChanged: (value) {
                      appState.setAutomaticKanaConversion(value);
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
                          value: appState.currentAnkiDeck,
                          items: appState.ankiDecks.map((deck) {
                            return DropdownMenuItem(
                              value: deck,
                              child: Text(deck),
                            );
                          }).toList(),
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
                          value: appState.currentProfile,
                          items: appState.profiles.map((profile) {
                            return DropdownMenuItem(
                              value: profile,
                              child: Text(profile),
                            );
                          }).toList(),
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
