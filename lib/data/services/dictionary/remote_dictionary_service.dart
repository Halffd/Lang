import 'package:lang/utils/chinese_util.dart';
import 'package:lang/utils/ideographic_util.dart';
import 'package:lang/domain/entities/etymology_model.dart';
import 'package:lang/domain/entities/tone_model.dart';
import 'package:lang/domain/entities/dictionary.dart';

/// Service for remote dictionary sources (Wiktionary, etymology, ichi.moe)
/// Simplified stub implementation
class RemoteDictionaryService {
  /// Fetch detailed Wiktionary entries for a word
  Future<List<WiktionaryEntry>> fetchWiktionaryDetails(String word, {String language = 'en'}) async {
    return [];
  }

  /// Fetch etymology information for a word
  Future<List<EtymologyEntry>> fetchEtymology(String word, {String language = 'en'}) async {
    return [];
  }

  /// Analyze Japanese text with ichi.moe
  Future<List<IchiMoeResult>> analyzeJapanese(String text) async {
    return [];
  }

  /// Search Wiktionary for European language words
  Future<List<WiktionaryEntry>> searchEuropeanWord(String query, {String language = 'en'}) async {
    return [];
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
  Future<KanjiEntry?> lookupKanji(String character) async {
    return null;
  }
}

/// Stub classes for remote dictionary types
class IchiMoeResult {
  final String word;
  final String? reading;
  final List<String> definitions;

  IchiMoeResult({required this.word, this.reading, this.definitions = const []});
}