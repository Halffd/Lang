import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:lang_cli/utils/html_sanitizer.dart';

class WiktionaryEntry {
  final String word;
  final String language;
  final List<String> definitions;
  final List<String> etymology;
  final List<String> pronunciation;
  final List<String> examples;
  final String partOfSpeech;

  WiktionaryEntry({
    required this.word,
    required this.language,
    required this.definitions,
    required this.etymology,
    required this.pronunciation,
    required this.examples,
    required this.partOfSpeech,
  });

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'language': language,
      'definitions': definitions,
      'etymology': etymology,
      'pronunciation': pronunciation,
      'examples': examples,
      'partOfSpeech': partOfSpeech,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== $word ($language) ===');
    if (partOfSpeech.isNotEmpty) {
      buffer.writeln('Part of Speech: $partOfSpeech');
    }
    if (pronunciation.isNotEmpty) {
      buffer.writeln('Pronunciation: ${pronunciation.join(', ')}');
    }
    if (etymology.isNotEmpty) {
      buffer.writeln('Etymology: ${etymology.join('; ')}');
    }
    if (definitions.isNotEmpty) {
      buffer.writeln('Definitions:');
      for (final def in definitions) {
        buffer.writeln('  - $def');
      }
    }
    if (examples.isNotEmpty) {
      buffer.writeln('Examples:');
      for (final ex in examples) {
        buffer.writeln('  - $ex');
      }
    }
    return buffer.toString();
  }
}

class WiktionaryService {
  final http.Client _client = http.Client();

  Future<String> fetchWiktionaryData(
    String wordToSearch, [
    int? languageCode,
  ]) async {
    String languageSubdomain = 'en';

    if (languageCode == 0) {
      languageSubdomain = 'zh';
    } else if (languageCode == 1) {
      languageSubdomain = 'ja';
    } else if (languageCode == 2) {
      languageSubdomain = 'id';
    }
    if (languageCode != null && languageCode > 50) {
      languageSubdomain = 'en';
    }
    languageSubdomain = 'en';

    String url = 'https://$languageSubdomain.wiktionary.org/wiki/$wordToSearch';

    try {
      final response = await _client.get(
        Uri.parse(Uri.encodeFull(url)),
        headers: {'Content-Type': 'text/html; charset=UTF-8'},
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception(
          'Failed to load Wiktionary data: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching Wiktionary data: $e');
    }
  }

  Future<List<WiktionaryEntry>> lookup(
    String word, {
    String language = 'en',
  }) async {
    String languageSubdomain;
    switch (language) {
      case 'ja':
        languageSubdomain = 'ja';
        break;
      case 'zh':
        languageSubdomain = 'zh';
        break;
      case 'ko':
        languageSubdomain = 'ko';
        break;
      default:
        languageSubdomain = 'en';
    }

    String url =
        'https://$languageSubdomain.wiktionary.org/wiki/${Uri.encodeComponent(word)}';

    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: {'Content-Type': 'text/html; charset=UTF-8'},
      );

      if (response.statusCode != 200) {
        return [];
      }

      return _parseWiktionaryContent(response.body, word, language);
    } catch (e) {
      return [];
    }
  }

  List<WiktionaryEntry> _parseWiktionaryContent(
    String content,
    String word,
    String language,
  ) {
    final entries = <WiktionaryEntry>[];
    try {
      final document = parse(content);
      final parserOutput = document.querySelector('.mw-parser-output');
      if (parserOutput == null) return entries;

      final elements = parserOutput.children;

      String currentPartOfSpeech = '';
      String currentLanguage = '';
      final definitions = <String>[];
      final etymology = <String>[];
      final pronunciation = <String>[];
      final examples = <String>[];

      for (final element in elements) {
        final tagName = element.localName?.toLowerCase() ?? '';
        final innerHtml = element.innerHtml;
        final sanitizedHtml = HtmlSanitizer.sanitize(innerHtml);
        final textContent = element.text.trim();

        if (tagName.startsWith('h') &&
            int.tryParse(tagName.substring(1)) != null) {
          if (textContent.contains('Chin') ||
              textContent.contains('Glyph') ||
              textContent.contains('Etymology')) {
            currentLanguage = 'zh';
          } else if (textContent.contains('Japan')) {
            currentLanguage = 'ja';
          } else if (textContent.contains('Korean')) {
            currentLanguage = 'ko';
          } else if (textContent.contains('English')) {
            currentLanguage = 'en';
          }

          if (textContent.contains('Noun') ||
              textContent.contains('Verb') ||
              textContent.contains('Adjective') ||
              textContent.contains('Adverb') ||
              textContent.contains('Particle') ||
              textContent.contains('Pronoun') ||
              textContent.contains('Conjunction') ||
              textContent.contains('Preposition') ||
              textContent.contains('Interjection') ||
              textContent.contains('Proper noun')) {
            if (definitions.isNotEmpty ||
                etymology.isNotEmpty ||
                pronunciation.isNotEmpty) {
              if (currentLanguage == language || language == 'en') {
                entries.add(
                  WiktionaryEntry(
                    word: word,
                    language: currentLanguage,
                    definitions: List.from(definitions),
                    etymology: List.from(etymology),
                    pronunciation: List.from(pronunciation),
                    examples: List.from(examples),
                    partOfSpeech: currentPartOfSpeech,
                  ),
                );
              }
            }
            definitions.clear();
            etymology.clear();
            pronunciation.clear();
            examples.clear();
            currentPartOfSpeech = textContent.replaceAll('[edit]', '').trim();
          }
        } else if (tagName == 'p' || tagName == 'ul' || tagName == 'ol') {
          if (textContent.isNotEmpty && sanitizedHtml.isNotEmpty) {
            if (currentPartOfSpeech.contains('Etymology') ||
                textContent.toLowerCase().contains('from')) {
              etymology.add(sanitizedHtml);
            } else if (currentPartOfSpeech.contains('Pronunciation') ||
                textContent.contains('IPA') ||
                textContent.contains('Audio')) {
              pronunciation.add(sanitizedHtml);
            } else if (tagName == 'ul' || tagName == 'ol') {
              final items = element.querySelectorAll('li');
              for (final item in items) {
                definitions.add(HtmlSanitizer.sanitize(item.innerHtml));
              }
            } else {
              definitions.add(sanitizedHtml);
            }
          }
        }
      }

      if (definitions.isNotEmpty ||
          etymology.isNotEmpty ||
          pronunciation.isNotEmpty) {
        if (currentLanguage == language || language == 'en') {
          entries.add(
            WiktionaryEntry(
              word: word,
              language: currentLanguage,
              definitions: definitions,
              etymology: etymology,
              pronunciation: pronunciation,
              examples: examples,
              partOfSpeech: currentPartOfSpeech,
            ),
          );
        }
      }
    } catch (e) {
      // Return empty list on parse error
    }

    return entries;
  }

  void dispose() {
    _client.close();
  }
}
