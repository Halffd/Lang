import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import '../utils/html_renderer.dart';

/// A service for fetching and parsing Wiktionary and Kanjipedia data
class WiktionaryService {
  /// Fetches Wiktionary data for a given word and language
  ///
  /// Parameters:
  /// - wordToSearch: The word to look up
  /// - languageCode: Language code (0 for zh, 1 for ja, 2 for id, defaults to en, >50 defaults to en)
  Future<String> fetchWiktionaryData(String wordToSearch, [int? languageCode]) async {
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
    // Override to always use English for now (as in original JavaScript code)
    languageSubdomain = 'en';

    String url = 'https://$languageSubdomain.wiktionary.org/wiki/$wordToSearch';

    try {
      print('Wiktionary URL: $url'); // Keep for debugging during development
      final response = await http.get(
        Uri.parse(Uri.encodeFull(url)),
        headers: {'Content-Type': 'text/html; charset=UTF-8'},
      );

      // Only print status in debug mode
      if (const bool.fromEnvironment("dart.vm.product") != true) {
        print('Response status: ${response.statusCode}');
      }
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to load Wiktionary data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Wiktionary data: $e'); // Keep for debugging
      throw Exception('Error fetching Wiktionary data: $e');
    }
  }

  /// Fetches Kanjipedia data for Chinese characters
  Future<String> fetchKanjipediaData(String url, int flag, String word, bool isChineseCharacter) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'text/html; charset=UTF-8',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        // Only print in debug mode
        if (const bool.fromEnvironment("dart.vm.product") != true) {
          print('Kanjipedia request failed with status: ${response.statusCode}');
        }
        return '';
      }
    } catch (e) {
      // Only print in debug mode
      if (const bool.fromEnvironment("dart.vm.product") != true) {
        print('Error fetching Kanjipedia data: $e');
      }
      return '';
    }
  }

  /// Main function that combines Wiktionary and Kanjipedia data
  /// Returns a list containing [japaneseContent, originContent, alternativeContent, allContent, otherContent]
  /// This is similar to the originate function in the JavaScript version
  Future<List<List<String>>> fetchDetailedWordInformation(String word, bool isChineseCharacter) async {
    List<String> japaneseContent = [];      // Japanese content (jl)
    List<String> originContent = [];        // Origin content (org)
    List<String> alternativeContent = [];   // Alternative content (al)
    List<String> otherContent = [];         // Other content (b)
    List<String> allContent = [];           // All content (a)
    String kanjipediaResult = '';           // Kanjipedia content

    // First get Wiktionary data
    String wiktionaryContent = await fetchWiktionaryData(word);

    // Parse the Wiktionary content to extract different sections
    await _parseWiktionaryContent(wiktionaryContent, japaneseContent, originContent, alternativeContent, allContent, otherContent);

    // For Chinese characters, also get Kanjipedia data
    if (isChineseCharacter && word.length == 1) {
      String kanjipediaContent = await fetchKanjipediaData(
        'https://www.kanjipedia.jp/search?kt=1&sk=leftHand&k=$word',
        0,
        word,
        isChineseCharacter
      );
      kanjipediaResult = kanjipediaContent;

      // If we have Kanjipedia data, extract specific information
      if (kanjipediaResult.isNotEmpty) {
        // Parse Kanjipedia content to extract origin, meaning, and usage
        kanjipediaResult = _extractKanjipediaInfo(kanjipediaResult);
        if (kanjipediaResult.isNotEmpty) {
          originContent.add(kanjipediaResult);
        }
      }
    }

    return [japaneseContent, originContent, alternativeContent, allContent, otherContent];
  }

  /// Parse Wiktionary HTML content to extract relevant information
  /// Modifies the provided lists in place
  Future<void> _parseWiktionaryContent(
    String content,
    List<String> japaneseContent,      // Japanese content
    List<String> originContent,        // Origin content
    List<String> alternativeContent,   // Alternative content
    List<String> allContent,           // All content
    List<String> otherContent          // Other content
  ) async {
    try {
      final document = parse(content);
      final parserOutput = document.querySelector('.mw-parser-output');

      if (parserOutput == null) return;

      final elements = parserOutput.children;

      bool isInJapaneseSection = false;
      bool isInOriginSection = false;
      bool isInAlternativeSection = false;

      for (final element in elements) {
        final tagName = element.localName?.toLowerCase() ?? '';
        final innerHtml = element.innerHtml;
        final textContent = element.text.trim();

        // Check if this is a heading element that indicates a language section
        if (tagName.startsWith('h') && int.tryParse(tagName.substring(1)) != null) {
          if (textContent.contains('Chin') || textContent.contains('Glyph')) {
            isInOriginSection = true;
            isInJapaneseSection = false;
            isInAlternativeSection = false;
          } else if (textContent.contains('Japan')) {
            isInJapaneseSection = true;
            isInOriginSection = false;
            isInAlternativeSection = false;
          } else if (textContent.contains('Definitions')) {
            isInOriginSection = false;
            isInJapaneseSection = false;
          } else if (textContent.contains('Etymology')) {
            isInOriginSection = true;
            isInJapaneseSection = false;
          } else {
            isInJapaneseSection = false;
            isInOriginSection = false;
            isInAlternativeSection = false;
          }
        }

        // Add content to appropriate section based on flags
        if (isInJapaneseSection && innerHtml.isNotEmpty) {
          japaneseContent.add(innerHtml);
        } else if (isInOriginSection && innerHtml.isNotEmpty && !textContent.contains('Chinese') && !textContent.contains('Glyph origin')) {
          originContent.add(innerHtml);
        } else if (isInAlternativeSection && innerHtml.isNotEmpty) {
          alternativeContent.add(innerHtml);
        } else if (innerHtml.isNotEmpty) {
          allContent.add(innerHtml);
          otherContent.add(innerHtml);
        }
      }
    } catch (e) {
      // Only print in debug mode
      if (const bool.fromEnvironment("dart.vm.product") != true) {
        print('Error parsing Wiktionary content: $e');
      }
    }
  }

  /// Extract specific information from Kanjipedia content
  String _extractKanjipediaInfo(String content) {
    try {
      final document = parse(content);

      // Extract origin information
      final originElement = document.querySelector('#kanjiRightSection > ul > li.naritachi > div:nth-child(2) > p');
      final origin = originElement?.text.trim() ?? '';

      // Extract meaning information
      final meaningElement = document.querySelector('#kanjiRightSection > ul > li:nth-child(1) > div > p');
      final meaning = meaningElement?.text.trim() ?? '';

      // Extract usage information
      final usageElement = document.querySelector('#kanjiRightSection > ul > li:nth-child(2) > div > p');
      final usage = usageElement?.text.trim() ?? '';

      // Combine all information
      List<String> result = [];
      if (origin.isNotEmpty) result.add('Origin: $origin');
      if (meaning.isNotEmpty) result.add('Meaning: $meaning');
      if (usage.isNotEmpty) result.add('Usage: $usage');

      return result.join('</br>');
    } catch (e) {
      // Only print in debug mode
      if (const bool.fromEnvironment("dart.vm.product") != true) {
        print('Error extracting Kanjipedia info: $e');
      }
      return '';
    }
  }

  /// Enhanced method to fetch detailed information for any word in any language
  /// This method is specifically designed to support multi-language word lookup
  Future<List<String>> fetchWordDetailsForAnyLanguage(String word, String detectedLanguage) async {
    try {
      // Determine if the word is a Chinese character (single character)
      bool isChineseCharacter = isSingleChineseCharacter(word);

      // Fetch detailed information using the existing method
      final result = await fetchDetailedWordInformation(word, isChineseCharacter);

      // Return combined content from all sources
      final combinedContent = <String>[];
      for (final section in result) {
        combinedContent.addAll(section);
      }

      return combinedContent;
    } catch (e) {
      print('Error fetching detailed word info: $e');
      return [];
    }
  }

  /// Helper method to check if a word is a single Chinese character
  bool isSingleChineseCharacter(String word) {
    if (word.length != 1) return false;

    final chineseRegExp = RegExp(r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]'); // Chinese characters
    return chineseRegExp.hasMatch(word);
  }
}