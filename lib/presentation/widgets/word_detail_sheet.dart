import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/widgets/anki_export_dialog.dart';
import 'package:lang/presentation/providers/ai_provider.dart';
import 'package:lang/utils/pinyin_util.dart';

class WordDetailSheet extends StatelessWidget {
  final AnalyzedWord word;
  final AnalyzerProvider provider;

  const WordDetailSheet({
    super.key,
    required this.word,
    required this.provider,
  });

  String get _currentLanguage => provider.currentLanguage;

  static void show(
    BuildContext context,
    AnalyzerProvider provider,
    AnalyzedWord word,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) =>
            WordDetailSheet(word: word, provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = Provider.of<AiProvider>(context);
    final theme = Theme.of(context);
    final freq = word.frequency;
    final sentence = word.sentence;
    final moeDefs = word.ichiMoeDefinitions;
    final wikiHtml = word.wiktionaryHtml;
    final kanjis = word.kanjiList;
    final locals = word.localDefinitions;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            word.word,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (PinyinUtil.isChinese(word.word) &&
              word.reading == null &&
              provider.currentLanguage == 'zh')
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
              child: Text(
                PinyinUtil.getPinyin(word.word) ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                word.word,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => provider.playAudio(word.word),
                  ),
                  Consumer<AppState>(
                    builder: (context, appState, _) {
                      if (!appState.ankiConnectEnabled) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        icon: const Icon(Icons.auto_stories),
                        tooltip: 'Send to Anki',
                        onPressed: () =>
                            showAnkiExportDialog(context, provider, word),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          Text(
            AppLocalizations.of(context)!.frequency(freq ?? 0),
            style: TextStyle(color: _getFreqColor(freq ?? 0)),
          ),
          const SizedBox(height: 20),
          if (aiProvider.isAiEnabled) ...[
            _SectionHeader(
              icon: Icons.auto_awesome,
              title: AppLocalizations.of(context)!.aiInsights,
              color: Colors.amberAccent,
            ),
            ElevatedButton.icon(
              onPressed: () {
                aiProvider.runBreakdown(word.word);
                Navigator.pop(context); // Close sheet to show result in AI tab
                // Optionally switch tab? For now user can just tap tab
              },
              icon: const Icon(Icons.reorder),
              label: Text(AppLocalizations.of(context)!.runAiBreakdown),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (sentence != null) ...[
            _SectionHeader(
              icon: Icons.short_text,
              title: AppLocalizations.of(context)!.context,
              color: Colors.deepPurpleAccent,
            ),
            Text(
              sentence,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
            ),
            const SizedBox(height: 20),
          ],
          if (locals.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.storage,
              title: AppLocalizations.of(context)!.localDictionary,
              color: Colors.greenAccent,
            ),
            ...locals.map((entry) {
              final List glossary = json.decode(entry['glossary']);
              final String reading = entry['reading'];
              final String displayReading =
                  _currentLanguage == 'zh' && reading != word.word
                  ? '$reading (${word.word})'
                  : reading;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.reading(displayReading),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(glossary.join(', ')),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
          if (moeDefs.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.menu_book,
              title: AppLocalizations.of(context)!.ichiMoe,
              color: Colors.blueAccent,
            ),
            ...moeDefs.map(
              (def) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text('• $def'),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (kanjis.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.grid_view,
              title: AppLocalizations.of(context)!.kanjiBreakdown,
              color: Colors.pinkAccent,
            ),
            ...kanjis.map((k) {
              final details = word.kanjiDetails[k];
              final kjp = word.kanjipediaData[k];
              if (details == null && kjp == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details != null) ...[
                      Text(
                        '$k: ${(details['meanings'] as List).take(3).join(", ")}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppLocalizations.of(context)!.readings(
                          [
                            ...(details['kun_readings'] as List),
                            ...(details['on_readings'] as List),
                          ].join(", "),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                    if (kjp != null) ...[
                      const SizedBox(height: 4),
                      if (kjp['origin'] != null)
                        HtmlWidget(
                          '<b>${AppLocalizations.of(context)!.origin}:</b> ${kjp['origin']!}',
                          textStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      if (kjp['usage'] != null)
                        HtmlWidget(
                          '<b>${AppLocalizations.of(context)!.usage}:</b> ${kjp['usage']!}',
                          textStyle: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],
          if (wikiHtml != null) ...[
            _SectionHeader(
              icon: Icons.public,
              title: AppLocalizations.of(context)!.wiktionary,
              color: Colors.orangeAccent,
            ),
            HtmlWidget(wikiHtml, textStyle: const TextStyle(fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Color _getFreqColor(int freq) {
    if (freq <= 1000) return Colors.greenAccent;
    if (freq <= 5000) return Colors.lightGreenAccent;
    if (freq <= 15000) return Colors.yellowAccent;
    return Colors.orangeAccent;
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
