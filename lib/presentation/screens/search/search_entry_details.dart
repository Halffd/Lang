import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/anki_connect_service.dart';
import '../../../domain/entities/app_state.dart';
import '../../../domain/entities/dictionary.dart';
import '../../../data/repositories/dictionary_service.dart';
import '../../widgets/etymology_widget.dart';
import '../../widgets/wiktionary_details_widget.dart';
import '../../widgets/wikipedia_article_sheet.dart';
import 'search_result_cards.dart';

class SearchEntryDetailsPanel extends StatelessWidget {
  final SearchResult result;
  final DictionaryEntry entry;

  const SearchEntryDetailsPanel({
    super.key,
    required this.result,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SearchEntryDetailsContent(result: result, entry: entry),
    );
  }
}

class SearchEntryDetailsContent extends StatelessWidget {
  final SearchResult result;
  final DictionaryEntry entry;
  final ScrollController? controller;
  final bool showCloseButton;

  const SearchEntryDetailsContent({
    super.key,
    required this.result,
    required this.entry,
    this.controller,
    this.showCloseButton = false,
  });

  Future<void> _launchExternalLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch url: $e')),
        );
      }
    }
  }

  Widget _buildExternalLinkButton(BuildContext context, IconData icon, String label, String url) {
    return InkWell(
      onTap: () => _launchExternalLink(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWikipediaButton(BuildContext context, DictionaryEntry entry) {
    return InkWell(
      onTap: () => showWikipediaArticle(context, entry.term, languageCode: 'ja'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(Icons.language, size: 24, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              'Wikipedia',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dict = result.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = result.pitchAccents[pitchKey];
    final frequencies = result.frequencies[pitchKey];

    final appState = Provider.of<AppState>(context, listen: false);
    final isSaved = appState.savedWords.contains(entry.term);
    final isFavorite = appState.favoriteWords.contains(entry.term);
    final isAnki = appState.ankiWords.contains(entry.term);

    return ListView(
      controller: controller,
      padding: showCloseButton ? EdgeInsets.zero : const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.term,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (entry.reading.isNotEmpty && entry.reading != entry.term)
                    Text(
                      entry.reading,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                  color: isSaved ? Theme.of(context).primaryColor : null,
                  tooltip: isSaved ? 'Remove from Saved' : 'Save',
                  onPressed: () => isSaved
                      ? appState.removeSavedWord(entry.term)
                      : appState.addSavedWord(entry.term, details: entry.toJson()),
                ),
                IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                  color: isFavorite ? Colors.red : null,
                  tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  onPressed: () => isFavorite ? appState.removeFavoriteWord(entry.term) : appState.addFavoriteWord(entry.term),
                ),
                IconButton(
                  icon: Icon(isAnki ? Icons.star : Icons.star_border),
                  color: isAnki ? Colors.orange : null,
                  tooltip: isAnki ? 'Remove from Anki' : 'Add to Anki',
                  onPressed: () => isAnki ? appState.removeAnkiWord(entry.term) : appState.addAnkiWord(entry.term),
                ),
                if (appState.ankiConnectEnabled)
                  IconButton(
                    icon: const Icon(Icons.auto_stories),
                    tooltip: 'Send to AnkiConnect',
                    onPressed: () async {
                      final service = AnkiConnectService(appState.ankiConnectUrl);
                      try {
                        final meaning = entry.definitions.isNotEmpty
                            ? entry.definitions.first.meaning
                            : entry.reading;
                        await service.addNote(
                          deckName: appState.currentAnkiDeck,
                          modelName: appState.ankiConnectModel,
                          fields: {'Front': entry.term, 'Back': meaning},
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sent to Anki')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('AnkiConnect: $e')),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
            if (showCloseButton)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (dict != null)
          Chip(
            label: Text('Source: ${dict.title}'),
            avatar: const Icon(Icons.book, size: 16),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildExternalLinkButton(
              context,
              Icons.image,
              'Images',
              'https://www.google.com/search?tbm=isch&q=${Uri.encodeComponent(entry.term)}',
            ),
            _buildWikipediaButton(context, entry),
            _buildExternalLinkButton(
              context,
              Icons.menu_book,
              'Wiktionary',
              'https://ja.wiktionary.org/wiki/${Uri.encodeComponent(entry.term)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (entry.termTags != null && entry.termTags!.isNotEmpty) ...[
          const Text(
            'Tags',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.termTags!.map((tagName) {
              final tag = result.tags['${entry.dictionaryId}_$tagName'];
              return Chip(
                label: Text(tag?.notes ?? tagName),
                backgroundColor: getTagColor(tag?.category),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (pitches != null && pitches.isNotEmpty) ...[
          const Text(
            'Pitch Accent',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...pitches.expand(
            (pitch) => pitch.pitches.map(
              (pattern) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq),
                      const SizedBox(width: 12),
                      Text(
                        'Downstep: ${pattern.position}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      if (pattern.tags != null) ...[
                        const Spacer(),
                        Text(
                          pattern.tags!.join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (result.toneInfo[pitchKey] != null && result.toneInfo[pitchKey]!.isNotEmpty) ...[
          const Text(
            'Tones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...result.toneInfo[pitchKey]!.expand(
            (toneInfo) => toneInfo.tones.map(
              (pattern) => Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.hearing, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${toneInfo.language.toUpperCase()} Tone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${pattern.position + 1}. ${pattern.getToneName(toneInfo.language)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (pattern.romanization != null)
                              Text(
                                'Reading: ${pattern.romanization}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (frequencies != null && frequencies.isNotEmpty) ...[
          const Text(
            'Frequency',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...frequencies.map((freq) {
            final freqDict = result.dictionaries[freq.dictionaryId];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up),
                    const SizedBox(width: 12),
                    Text(
                      '${freqDict?.title ?? "Unknown"}: ${freq.displayValue ?? freq.value}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
        if (result.etymology[pitchKey]?.isNotEmpty == true)
          EtymologyWidget(
            etymologyEntries: result.etymology[pitchKey]!,
            word: entry.term,
          ),
        if (result.wiktionaryDetails[pitchKey]?.isNotEmpty == true)
          WiktionaryDetailsWidget(
            wiktionaryEntries: result.wiktionaryDetails[pitchKey]!,
            word: entry.term,
          ),
        const Text(
          'Definitions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...entry.definitions.asMap().entries.map((defEntry) {
          final index = defEntry.key;
          final definition = defEntry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formatDefinition(definition),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

