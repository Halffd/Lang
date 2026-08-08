import '../datasources/remote/wiktionary_service.dart';
import '../datasources/remote/wiktionary_etymology_service.dart';
import '../datasources/remote/ichi_moe_service.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../../domain/entities/etymology_model.dart';
import '../../domain/entities/tone_model.dart';
import '../../utils/chinese_util.dart';
import '../../utils/ideographic_util.dart';

/// Service for remote dictionary sources (Wiktionary, etymology, ichi.moe)
class RemoteDictionaryService {
  final WiktionaryService _wiktionaryService = WiktionaryService();
  final WiktionaryEtymologyService _etymologyService = WiktionaryEtymologyService();
  final IchiMoeService _ichiMoeService = IchiMoeService();

  /// Fetch detailed Wiktionary entries for a word
  Future<List<model.WiktionaryEntry>> fetchWiktionaryDetails(String word, {String language = 'en'}) async {
    try {
      return await _wiktionaryService.fetchWordDetails(word, language: language);
    } catch (e) {
      print('Error fetching Wiktionary details for $word: $e');
      return [];
    }
  }

  /// Fetch etymology information for a word
  Future<List<EtymologyEntry>> fetchEtymology(String word, {String language = 'en'}) async {
    try {
      final service = WiktionaryEtymologyService();
      final result = await service.fetchEtymologyDetailed(word, language);
      return result.sections.map((section) => EtymologyEntry(
        sectionTitle: section.title,
        originalLanguage: section.originalLanguage,
        content: section.content,
      )).toList();
    } catch (e) {
      print('Error fetching etymology for $word: $e');
      return [];
    }
  }

  /// Analyze Japanese text with ichi.moe
  Future<List<IchiMoeResult>> analyzeJapanese(String text) async {
    try {
      return await _ichiMoeService.analyze(text);
    } catch (e) {
      print('Error analyzing Japanese text: $e');
      return [];
    }
  }

  /// Search Wiktionary for European language words
  Future<List<model.WiktionaryEntry>> searchEuropeanWord(String query, {String language = 'en'}) async {
    try {
      return await _wiktionaryService.fetchWordDetails(query, language: language);
    } catch (e) {
      print('Error searching European word $query: $e');
      return [];
    }
  }

  /// Extract Japanese words from text using ideographic components
  List<String> extractJapaneseWords(String text) {
    final japaneseRegex = RegExp(r'[\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\u4e00-\u9faf\u3400-\u4dbf]+');
    final matches = japaneseRegex.allMatches(text);
    final words = <String>[];
    for (final match in matches) {
      final word = match.group(0);
      if (word != null && word.isNotEmpty && !words.contains(word)) {
        words.add(word);
      }
    }
    return words;
  }

  /// Extract Chinese words from text
  List<String> extractChineseWords(String text) {
    if (!ChineseUtil.containsChinese(text)) return [];
    // Simple extraction - could be enhanced with proper segmentation
    final words = <String>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (ChineseUtil.containsChinese(char) && !words.contains(char)) {
        words.add(char);
      }
    }
    return words;
  }

  /// Lookup single character kanji details
  Future<model.KanjiEntry?> lookupKanji(String character) async {
    try {
      // Try to get kanji info from Wiktionary
      final details = await _wiktionaryService.fetchWordDetails(character, language: 'ja');
      if (details.isNotEmpty) {
        return model.KanjiEntry(
          character: character,
          dictionaryId: 0,
          meaning: details.first.definition,
          reading: '',
        );
      }
    } catch (e) {
      print('Error looking up kanji: $e');
    }
    return null;
  }
}