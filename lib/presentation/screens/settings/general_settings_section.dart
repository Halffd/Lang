import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/presentation/utils/screen_size.dart';

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
      case 'th':
        return localizations.thai;
      case 'vi':
        return localizations.vietnamese;
      case 'id':
        return localizations.indonesian;
      case 'ms':
        return localizations.malay;
      case 'tl':
        return localizations.filipino;
      case 'tr':
        return localizations.turkish;
      case 'pl':
        return localizations.polish;
      case 'nl':
        return localizations.dutch;
      case 'sv':
        return localizations.swedish;
      case 'da':
        return localizations.danish;
      case 'no':
        return localizations.norwegian;
      case 'fi':
        return localizations.finnish;
      case 'cs':
        return localizations.czech;
      case 'hu':
        return localizations.hungarian;
      case 'ro':
        return localizations.romanian;
      case 'bg':
        return localizations.bulgarian;
      case 'hr':
        return localizations.croatian;
      case 'sk':
        return localizations.slovak;
      case 'sl':
        return localizations.slovenian;
      case 'et':
        return localizations.estonian;
      case 'lv':
        return localizations.latvian;
      case 'lt':
        return localizations.lithuanian;
      case 'uk':
        return localizations.ukrainian;
      case 'be':
        return localizations.belarusian;
      case 'sr':
        return localizations.serbian;
      case 'mk':
        return localizations.macedonian;
      case 'sq':
        return localizations.albanian;
      case 'mt':
        return localizations.maltese;
      case 'ga':
        return localizations.irish;
      case 'cy':
        return localizations.welsh;
      case 'eu':
        return localizations.basque;
      case 'ca':
        return localizations.catalan;
      case 'gl':
        return localizations.galician;
      case 'is':
        return localizations.icelandic;
      case 'fo':
        return localizations.faroese;
      case 'kl':
        return localizations.greenlandic;
      case 'af':
        return localizations.afrikaans;
      case 'sw':
        return localizations.swahili;
      case 'zu':
        return localizations.zulu;
      case 'xh':
        return localizations.xhosa;
      case 'st':
        return localizations.sotho;
      case 'tn':
        return localizations.tswana;
      case 'ss':
        return localizations.swati;
      case 've':
        return localizations.venda;
      case 'ts':
        return localizations.tsonga;
      case 'ny':
        return localizations.chewa;
      case 'mg':
        return localizations.malagasy;
      case 'so':
        return localizations.somali;
      case 'am':
        return localizations.amharic;
      case 'ti':
        return localizations.tigrinya;
      case 'om':
        return localizations.oromo;
      case 'sn':
        return localizations.shona;
      case 'rw':
        return localizations.kinyarwanda;
      case 'ny':
        return localizations.nyanja;
      case 'ki':
        return localizations.kikuyu;
      case 'lu':
        return localizations.luba;
      case 'lg':
        return localizations.ganda;
      case 'ak':
        return localizations.akan;
      case 'tw':
        return localizations.twi;
      case 'ee':
        return localizations.ewe;
      case 'yo':
        return localizations.yoruba;
      case 'ig':
        return localizations.igbo;
      case 'ha':
        return localizations.hausa;
      case 'zu':
        return localizations.zulu;
      case 'xh':
        return localizations.xhosa;
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.generalSettings,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildLanguageCard(context, appState, localizations),
        const SizedBox(height: 16),
        _buildThemeCard(context, appState, localizations),
        const SizedBox(height: 16),
        _buildFontSizeCard(context, appState, localizations),
        const SizedBox(height: 16),
        _buildZoomLevelCard(context, appState, localizations),
      ],
    );
  }

  Widget _buildLanguageCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.language, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(localizations.language, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'ja', 'zh', 'ko', 'en', 'fr', 'es', 'de', 'it', 'pt', 'ru', 'ar', 'hi', 'th', 'vi', 'id', 'tr', 'pl', 'nl', 'sv', 'da', 'no', 'fi', 'cs', 'hu', 'ro', 'bg', 'hr', 'sk', 'sl', 'et', 'lv', 'lt', 'uk'
              ].map((code) => FilterChip(
                label: Text(_getLanguageName(context, code)),
                selected: appState.dictionaryLanguage == code,
                onSelected: (selected) => appState.setDictionaryLanguage(code),
                showCheckmark: false,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(localizations.themeMode, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'system', 'light', 'dark'
              ].map((theme) => FilterChip(
                label: Text(localizations.themeModeSubtitle),
                selected: appState.themeMode == theme,
                onSelected: (selected) => appState.setThemeMode(theme),
                showCheckmark: false,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSizeCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(localizations.fontSize, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(localizations.fontSizeSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Slider(
              value: appState.fontScale,
              min: 0.8,
              max: 2.0,
              divisions: 12,
              label: '${(appState.fontScale * 100).round()}%',
              onChanged: (value) => appState.setFontScale(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomLevelCard(BuildContext context, AppState appState, AppLocalizations localizations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.zoom_out_map, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(localizations.zoomLevel, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(localizations.zoomLevelSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Slider(
              value: appState.zoomLevel,
              min: 0.5,
              max: 3.0,
              divisions: 25,
              label: '${(appState.zoomLevel * 100).round()}%',
              onChanged: (value) => appState.setZoomLevel(value),
            ),
          ],
        ),
      ),
    );
  }
}