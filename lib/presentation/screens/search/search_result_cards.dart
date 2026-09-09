import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/utils/screen_size.dart';
import 'package:lang/utils/font_scale.dart';

class SearchKanjiCard extends StatelessWidget {
  final KanjiEntry kanji;
  final SearchResult result;
  final ValueChanged<String> onDoubleTap;

  const SearchKanjiCard({
    super.key,
    required this.kanji,
    required this.result,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final dict = result.dictionaries[kanji.dictionaryId];

    return GestureDetector(
      onDoubleTap: () => onDoubleTap(kanji.character),
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: ScreenSize.isCompact(context) ? 8 : 16,
          vertical: 8,
        ),
        child: Padding(
          padding: EdgeInsets.all(ScreenSize.isCompact(context) ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    kanji.character,
                    style: TextStyle(
                      fontSize: fs(context, 48, 'kanji'),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (dict != null)
                    Chip(
                      label: Text(
                        dict.title,
                        style: TextStyle(fontSize: fs(context, 10)),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (kanji.onyomi != null && kanji.onyomi!.isNotEmpty) ...[
                const Text(
                  '音読み (On\'yomi)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(kanji.onyomi!.join(', ')),
                const SizedBox(height: 8),
              ],
              if (kanji.kunyomi != null && kanji.kunyomi!.isNotEmpty) ...[
                const Text(
                  '訓読み (Kun\'yomi)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(kanji.kunyomi!.join(', ')),
                const SizedBox(height: 8),
              ],
              if (kanji.meanings.isNotEmpty) ...[
                const Text(
                  'Meanings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...kanji.meanings.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${entry.key + 1}. ${entry.value}'),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SearchEntryCard extends StatelessWidget {
  final DictionaryEntry entry;
  final SearchResult result;
  final bool isSelected;
  final ValueChanged<DictionaryEntry> onTap;
  final ValueChanged<DictionaryEntry> onDoubleTap;

  const SearchEntryCard({
    super.key,
    required this.entry,
    required this.result,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final dict = result.dictionaries[entry.dictionaryId];
    final pitchKey = '${entry.term}_${entry.reading}';
    final pitches = result.pitchAccents[pitchKey];
    final frequencies = result.frequencies[pitchKey];

    return GestureDetector(
      onDoubleTap: () => onDoubleTap(entry),
    child: Card(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenSize.isCompact(context) ? 8 : 16,
        vertical: 8,
      ),
      elevation: isSelected ? 4 : 1,
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            )
          : null,
      child: InkWell(
        onTap: () => onTap(entry),
        borderRadius: isSelected ? BorderRadius.circular(12) : BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(ScreenSize.isCompact(context) ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                Text(
                  entry.term,
                  style: TextStyle(
                    fontSize: fs(context, 24, 'words'),
                    fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (entry.reading.isNotEmpty && entry.reading != entry.term)
                            Text(
                              entry.reading,
                              style: TextStyle(
                                fontSize: fs(context, 16, 'words'),
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (dict != null)
                      Chip(
                        label: Text(
                          dict.title,
                          style: TextStyle(fontSize: fs(context, 10)),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (appState.ankiWords.contains(entry.term))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.star, color: Colors.orange, size: 20),
                      ),
                    if (appState.favoriteWords.contains(entry.term))
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.favorite, color: Colors.red, size: 20),
                      ),
                    if (appState.savedWords.contains(entry.term))
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.bookmark, color: Theme.of(context).primaryColor, size: 20),
                      ),
                  ],
                ),
                if (entry.termTags != null && entry.termTags!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.termTags!.map((tagName) {
                      final tag = result.tags['${entry.dictionaryId}_$tagName'];
                      return Chip(
                        label: Text(
                          tag?.notes ?? tagName,
                          style: TextStyle(fontSize: fs(context, 10)),
                        ),
                        backgroundColor: getTagColor(tag?.category),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
                if (pitches != null && pitches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.graphic_eq, size: 16),
const SizedBox(width: 4),
            Text(
              'Pitch: ${pitches.map((p) => p.pitches.map((pp) => pp.position).join(", ")).join(" / ")}',
              style: TextStyle(
                fontSize: fs(context, 12, 'translations'),
                color: Colors.grey[700],
              ),
            ),
                    ],
                  ),
                ],
                if (result.toneInfo[pitchKey] != null && result.toneInfo[pitchKey]!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.hearing, size: 16),
                      const SizedBox(width: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final toneInfo in result.toneInfo[pitchKey]!)
                            for (final tonePattern in toneInfo.tones)
                              Text(
                                '${toneInfo.language.toUpperCase()} ${tonePattern.getToneName(toneInfo.language)}',
                                style: TextStyle(
                                  fontSize: fs(context, 11, 'ui'),
                                  color: Colors.green[700],
                                ),
                              ),
                        ],
                      ),
                    ],
                  ),
                ],
                if (frequencies != null && frequencies.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Frequency: ${frequencies.first.displayValue}',
                        style: TextStyle(
                          fontSize: fs(context, 12, 'translations'),
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
                if (result.etymology[pitchKey]?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  for (final etymologyEntry in result.etymology[pitchKey]!.take(1))
                    Row(
                      children: [
                        Icon(Icons.history, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Etymology: ${etymologyEntry.originalLanguage}',
                            style: TextStyle(
                              fontSize: fs(context, 11, 'ui'),
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                if (result.wiktionaryDetails[pitchKey]?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  for (final wiktionaryEntry in result.wiktionaryDetails[pitchKey]!.take(1))
                    Row(
                      children: [
                        Icon(Icons.menu_book, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${wiktionaryEntry.partOfSpeech.isNotEmpty ? '${wiktionaryEntry.partOfSpeech}: ' : ''}${wiktionaryEntry.definition.length > 60 ? '${wiktionaryEntry.definition.substring(0, 60)}...' : wiktionaryEntry.definition}',
                            style: TextStyle(
                              fontSize: fs(context, 11, 'ui'),
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...List.generate(entry.definitions.take(2).length, (index) {
                  final definition = entry.definitions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${index + 1}. ${formatDefinition(definition)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
                if (entry.definitions.length > 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+ ${entry.definitions.length - 2} more definitions',
                    style: TextStyle(
                      fontSize: fs(context, 12, 'translations'),
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color? getTagColor(String? category) {
  switch (category) {
    case 'partOfSpeech':
      return Colors.blue[50];
    case 'name':
      return Colors.green[50];
    case 'expression':
      return Colors.orange[50];
    case 'popular':
      return Colors.purple[50];
    default:
      return Colors.grey[200];
  }
}

String formatDefinition(String definition) {
  if (!definition.startsWith('{') && !definition.startsWith('[')) {
    return definition;
  }

  final extracted = extractPlainTextFromStructuredContent(definition);
  return extracted.isEmpty ? definition : extracted;
}

String extractPlainTextFromStructuredContent(String definition) {
  try {
    final dynamic jsonContent = jsonDecode(definition);
    return extractTextFromJson(jsonContent);
  } catch (_) {
    return definition;
  }
}

String extractTextFromJson(dynamic content) {
  if (content == null) return '';
  if (content is String) return content;
  if (content is List) return content.map(extractTextFromJson).join(' ');
  if (content is Map<String, dynamic>) {
    final result = <String>[];
    if (content['content'] != null) result.add(extractTextFromJson(content['content']));
    if (content['text'] != null) result.add(extractTextFromJson(content['text']));
    if (content['title'] != null) result.add(extractTextFromJson(content['title']));
    return result.where((s) => s.isNotEmpty).join(' ');
  }
  return content.toString();
}

