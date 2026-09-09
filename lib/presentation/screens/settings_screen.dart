import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/core/services/clipboard_monitor_service.dart';
import 'package:lang/data/services/anki_connect_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/dictionary_list_screen.dart';
import 'package:lang/presentation/screens/yomitan_settings_screen.dart';
import 'package:lang/presentation/screens/import_screen.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:lang/utils/font_scale.dart';

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
        padding: ScreenSize.adaptivePadding(context),
        children: [
          // General settings section
          Text(
            AppLocalizations.of(context)!.generalSettings,
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    initialValue: () {
                      // Double-check that the value is valid at build time
                      final currentLang = appState.language;
                      if (LanguageOption.all.any(
                        (option) => option.code == currentLang,
                      )) {
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
                          child: Text(
                            _getLanguageName(context, languageOption.code),
                          ),
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
                    subtitle: Text(
                      AppLocalizations.of(context)!.themeModeSubtitle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<ThemeMode>(
                      initialValue: appState.themeMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(
                            AppLocalizations.of(context)!.systemTheme,
                          ),
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
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
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
                    title: Text(
                      AppLocalizations.of(context)!.autoHideNavigation,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.hideNavigationBottom,
                    ),
                    value: appState.autoHideNavigation,
                    onChanged: (value) => appState.setAutoHideNavigation(value),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.defaultFlexMode),
                    subtitle: Text(
                      AppLocalizations.of(context)!.useFlexibleGrid,
                    ),
                    value: appState.defaultFlexMode,
                    onChanged: (value) => appState.setDefaultFlexMode(value),
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(
                      AppLocalizations.of(context)!.keyboardShortcuts,
                    ),
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
                    title: Text(
                      AppLocalizations.of(context)!.autoKanaConversion,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.convertRomajiToKana,
                    ),
                    value: appState.autoConvertJapanese,
                    onChanged: (value) {
                      appState.setAutoConvertJapanese(value);
                    },
                  ),
                  const Divider(),
                  // Default screen selection
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.defaultScreen),
                    subtitle: Text(
                      AppLocalizations.of(context)!.defaultScreenSubtitle,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<int>(
                      initialValue:
                          (appState.defaultScreenIndex >= 0 &&
                              appState.defaultScreenIndex <= 5)
                          ? appState.defaultScreenIndex
                          : 0, // fallback to 0 if current value is invalid
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                          child: Text(
                            AppLocalizations.of(context)!.dictionaries,
                          ),
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
                    subtitle: Text(
                      AppLocalizations.of(context)!.zoomLevelSubtitle,
                    ),
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
                            divisions:
                                50, // Provides 0.05 increments between 0.5 and 3.0
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
                    subtitle: Text(
                      AppLocalizations.of(context)!.fontSizeSubtitle,
                    ),
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
                            divisions:
                                24, // Provides 0.05 increments between 0.8 and 2.0
                            label:
                                '${(appState.fontSizeMultiplier * 100).round()}%',
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
                  const Divider(),
                  // Per-section font size multipliers
                  Text(
                    AppLocalizations.of(context)!.fontGroupSizes,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupHeaders,
                    group: 'headers',
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupSentences,
                    group: 'sentences',
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupTranslations,
                    group: 'translations',
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupWords,
                    group: 'words',
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupKanji,
                    group: 'kanji',
                  ),
                  _FontGroupSlider(
                    label: AppLocalizations.of(context)!.fontGroupUi,
                    group: 'ui',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search settings section
          Text(
            AppLocalizations.of(context)!.searchSettings,
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
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
                  const _ClipboardSettings(),
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
                    subtitle: Text(
                      AppLocalizations.of(context)!.highlightParticles,
                    ),
                    value: appState.showParticles,
                    onChanged: (value) {
                      appState.setShowParticles(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.showKanji),
                    subtitle: Text(
                      AppLocalizations.of(context)!.displayKanjiInfo,
                    ),
                    value: appState.showKanji,
                    onChanged: (value) {
                      appState.setShowKanji(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: Text(AppLocalizations.of(context)!.minFrequency),
                    subtitle: Text(
                      AppLocalizations.of(context)!.filterByFrequency,
                    ),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        controller: TextEditingController(
                          text: appState.minFrequency.toString(),
                        ),
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
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
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
                  ScreenSize.isCompact(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.currentAnkiDeck),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              initialValue:
                                  appState.ankiDecks.contains(
                                    appState.currentAnkiDeck,
                                  )
                                  ? appState.currentAnkiDeck
                                  : (appState.ankiDecks.isNotEmpty
                                        ? appState.ankiDecks.first
                                        : 'Default'),
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
                                      ),
                                    ],
                              onChanged: (value) {
                                if (value != null) {
                                  appState.setCurrentAnkiDeck(value);
                                }
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                AppLocalizations.of(context)!.currentAnkiDeck,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                initialValue:
                                    appState.ankiDecks.contains(
                                      appState.currentAnkiDeck,
                                    )
                                    ? appState.currentAnkiDeck
                                    : (appState.ankiDecks.isNotEmpty
                                          ? appState.ankiDecks.first
                                          : 'Default'),
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
                                        ),
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
                  ScreenSize.isCompact(context)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)!.currentProfile),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              initialValue:
                                  appState.profiles.contains(
                                    appState.currentProfile,
                                  )
                                  ? appState.currentProfile
                                  : (appState.profiles.isNotEmpty
                                        ? appState.profiles.first
                                        : 'Default'),
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
                                      ),
                                    ],
                              onChanged: (value) {
                                if (value != null) {
                                  appState.setCurrentProfile(value);
                                }
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                AppLocalizations.of(context)!.currentProfile,
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                initialValue:
                                    appState.profiles.contains(
                                      appState.currentProfile,
                                    )
                                    ? appState.currentProfile
                                    : (appState.profiles.isNotEmpty
                                          ? appState.profiles.first
                                          : 'Default'),
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
                                        ),
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

          // AnkiConnect settings
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'AnkiConnect',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Switch(
                        value: appState.ankiConnectEnabled,
                        onChanged: (v) => appState.setAnkiConnectEnabled(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (appState.ankiConnectEnabled) ...[
                    // Connection URL
                    Text('API URL', style: TextStyle(fontSize: fs(context, 13))),
                    const SizedBox(height: 4),
                    TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'http://127.0.0.1:8765',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      controller: TextEditingController(
                        text: appState.ankiConnectUrl,
                      ),
                      onChanged: (v) => appState.setAnkiConnectUrl(v),
                    ),
                    const SizedBox(height: 12),
                    // Test connection button + status
                    ElevatedButton.icon(
                      onPressed: () async {
                        final service = AnkiConnectService(
                          appState.ankiConnectUrl,
                        );
                        final ok = await service.testConnection();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'AnkiConnect connected'
                                    : 'Connection failed',
                              ),
                              backgroundColor: ok ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.wifi_find, size: 18),
                      label: const Text('Test Connection'),
                    ),
                    const SizedBox(height: 12),
                    // Deck selection
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                              labelText: 'Deck',
                            ),
                            initialValue:
                                appState.ankiDecks.contains(
                                  appState.currentAnkiDeck,
                                )
                                ? appState.currentAnkiDeck
                                : (appState.ankiDecks.isNotEmpty
                                      ? appState.ankiDecks.first
                                      : 'Default'),
                            items: appState.ankiDecks
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) appState.setCurrentAnkiDeck(v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Fetch decks from AnkiConnect',
                          onPressed: () async {
                            final service = AnkiConnectService(
                              appState.ankiConnectUrl,
                            );
                            try {
                              final decks = await service.getDeckNames();
                              appState.setAnkiDecks(decks);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Found ${decks.length} decks',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Note model selection
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Basic',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                              labelText: 'Note Type',
                            ),
                            controller: TextEditingController(
                              text: appState.ankiConnectModel,
                            ),
                            onChanged: (v) => appState.setAnkiConnectModel(v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Fetch note types from AnkiConnect',
                          onPressed: () async {
                            final service = AnkiConnectService(
                              appState.ankiConnectUrl,
                            );
                            try {
                              final models = await service.getModelNames();
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => SimpleDialog(
                                    title: const Text('Select Note Type'),
                                    children: models
                                        .map(
                                          (m) => SimpleDialogOption(
                                            onPressed: () {
                                              appState.setAnkiConnectModel(m);
                                              Navigator.pop(ctx);
                                            },
                                            child: Text(m),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Sync on save toggle
                    SwitchListTile(
                      title: Text(
                        'Auto-sync to Anki',
                        style: TextStyle(fontSize: fs(context, 14)),
                      ),
                      subtitle: Text(
                        'Send to Anki when saving a word',
                        style: TextStyle(fontSize: fs(context, 12)),
                      ),
                      value: appState.ankiSyncOnSave,
                      onChanged: (v) => appState.setAnkiSyncOnSave(v),
                      dense: true,
                    ),
                  ],
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
                    title: Text(
                      AppLocalizations.of(context)!.clipboardAutoDetect,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.autoDetectProcessText,
                    ),
                    value: appState.clipboardAutoDetect,
                    onChanged: (value) {
                      appState.setClipboardAutoDetect(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.forvoAudio),
                    subtitle: Text(
                      AppLocalizations.of(context)!.enableForvoPronunciations,
                    ),
                    value: appState.forvoAudioEnabled,
                    onChanged: (value) {
                      appState.setForvoAudioEnabled(value);
                    },
                  ),
                  if (appState.forvoAudioEnabled) ...[
                    const SizedBox(height: 8),
                    ScreenSize.isCompact(context)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Forvo API Key'),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter your Forvo API key',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                obscureText: true,
                                controller: TextEditingController(
                                  text: appState.forvoApiKey,
                                ),
                                onChanged: (value) {
                                  appState.setForvoApiKey(value);
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Expanded(
                                flex: 3,
                                child: Text('Forvo API Key'),
                              ),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Enter your Forvo API key',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  obscureText: true,
                                  controller: TextEditingController(
                                    text: appState.forvoApiKey,
                                  ),
                                  onChanged: (value) {
                                    appState.setForvoApiKey(value);
                                  },
                                ),
                              ),
                            ],
                          ),
                  ],
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoTranslation),
                    subtitle: Text(
                      AppLocalizations.of(context)!.autoTranslateWords,
                    ),
                    value: appState.autoTranslate,
                    onChanged: (value) {
                      appState.setAutoTranslate(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(AppLocalizations.of(context)!.autoPasteReader),
                    subtitle: Text(
                      AppLocalizations.of(context)!.autoPasteReaderSubtitle,
                    ),
                    value: appState.autoPasteReader,
                    onChanged: (value) {
                      appState.setAutoPasteReader(value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Inline Definitions'),
                    subtitle: const Text(
                      'Show definition text below each word',
                    ),
                    value: appState.showInlineDefinitions,
                    onChanged: (value) {
                      appState.setShowInlineDefinitions(value);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Hover Definitions'),
                    subtitle: const Text(
                      'Show definition popup on hover / long-press',
                    ),
                    value: appState.showHoverDefinitions,
                    onChanged: (value) {
                      appState.setShowHoverDefinitions(value);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Translation Provider'),
                    subtitle: const Text(
                      'Choose engine for sentence/word translation',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButtonFormField<TranslationProvider>(
                      initialValue: appState.translationProvider,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: TranslationProvider.googleCloud,
                          child: Text('Google Cloud (free, online)'),
                        ),
                        DropdownMenuItem(
                          value: TranslationProvider.mlKit,
                          child: Text('ML Kit (offline, on-device)'),
                        ),
                        DropdownMenuItem(
                          value: TranslationProvider.gemini,
                          child: Text('Gemini AI (requires API key)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          appState.setTranslationProvider(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Dictionaries section
          Text(
            AppLocalizations.of(context)!.dictionaries,
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Yomitan Settings'),
                  subtitle: const Text(
                    'Profiles, scanning, popup, audio, anki export settings',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const YomitanSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.library_books),
                  title: const Text('Manage Dictionaries'),
                  subtitle: const Text(
                    'Enable/disable, reorder, set priority per dictionary',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DictionaryListScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('Import Dictionary'),
                  subtitle: const Text('Import Yomichan .zip dictionaries'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImportScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About section
          Text(
            AppLocalizations.of(context)!.about,
            style: TextStyle(fontSize: fs(context, 18, 'headers'), fontWeight: FontWeight.bold),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fs(context, 16, 'headers'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.version('1.0.0')),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.multilingualLearningTool,
                    style: TextStyle(fontSize: fs(context, 14)),
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

/// Clipboard monitor settings: mode selector (history only /
/// auto search / off) plus auto-search gates (focus, regex).
class _ClipboardSettings extends StatefulWidget {
  const _ClipboardSettings();

  @override
  State<_ClipboardSettings> createState() => _ClipboardSettingsState();
}

class _ClipboardSettingsState extends State<_ClipboardSettings> {
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
                  style: TextStyle(fontSize: fs(context, 12), color: Colors.white54),
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

/// One slider row for a per-section font multiplier.
class _FontGroupSlider extends StatelessWidget {
  final String label;
  final String group;

  const _FontGroupSlider({required this.label, required this.group});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final value = switch (group) {
      'headers' => appState.fontSettings.headers,
      'sentences' => appState.fontSettings.sentences,
      'translations' => appState.fontSettings.translations,
      'words' => appState.fontSettings.words,
      'kanji' => appState.fontSettings.kanji,
      _ => appState.fontSettings.ui,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: 0.5,
              max: 3.0,
              divisions: 25, // 0.1 increments
              label: 'x$value',
              onChanged: (v) => appState.setFontGroup(group, v),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              'x${value.toStringAsFixed(1)}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
