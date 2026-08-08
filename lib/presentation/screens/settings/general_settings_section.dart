import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../domain/entities/app_state.dart';
import '../../domain/entities/translation_model.dart';
import '../utils/screen_size.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({super.key});

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
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.generalSettings,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildLanguageCard(context, appState, localizations),
        _buildThemeCard(context, appState, localizations),
      ],
    );
  }

  Widget _buildLanguageCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.dictionaryLanguage, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              value: LanguageOption.all.any((option) => option.code == appState.language)
                  ? appState.language
                  : 'ja',
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
    );
  }

  Widget _buildThemeCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.appearance, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: Text(localizations.themeMode),
              subtitle: Text(localizations.themeModeSubtitle),
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
                  DropdownMenuItem(value: ThemeMode.system, child: Text(localizations.systemTheme)),
                  DropdownMenuItem(value: ThemeMode.light, child: Text(localizations.lightTheme)),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text(localizations.darkTheme)),
                ],
                onChanged: (value) {
                  if (value != null) appState.setThemeMode(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}