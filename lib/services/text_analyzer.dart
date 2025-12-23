import 'package:drift/drift.dart';
import '../services/database.dart';
import '../services/dictionary_service.dart';

class TextAnalyzer {
  final AppDatabase driftDb;
  final DictionaryService dictionaryService;

  TextAnalyzer(this.driftDb, this.dictionaryService);

  Future<List<WordFrequencyWithDefinition>> analyzeText(String text) async {
    // Use language detection to determine the best analysis method
    if (_hasJapaneseChars(text)) {
      // For Japanese, use the existing dictionary-based approach or MeCab when available
      return await _analyzeJapanese(text);
    } else if (_hasChineseChars(text)) {
      // For Chinese, use FTS5-based approach or Jieba when available
      return await _analyzeChineseWithFts5(text);
    } else {
      // Fallback to existing dictionary-based tokenizer
      return await _analyzeWithDictionary(text);
    }
  }

  // Analyze Japanese text
  Future<List<WordFrequencyWithDefinition>> _analyzeJapanese(String text) async {
    await driftDb.clearWordOccurrences();

    try {
      // Use existing dictionary tokenizer 
      final tokens = await dictionaryService.tokenizeText(text);
      final wordOccurrences = <WordOccurrencesCompanion>[];

      for (var i = 0; i < tokens.length; i++) {
        final tokenText = tokens[i].text;

        // Skip punctuation and particles if desired
        if (_isPunctuationOrParticle(tokenText)) {
          continue;
        }

        wordOccurrences.add(WordOccurrencesCompanion.insert(
          word: tokenText,
          reading: Value(tokens[i].entry?.reading ?? ''),
          baseForm: const Value(''), // Base form not available with current approach
          position: i,
        ));
      }

      if (wordOccurrences.isNotEmpty) {
        await driftDb.insertWordOccurrences(wordOccurrences);
      }

      final results = await driftDb.getWordFrequenciesWithDefinitions();
      return results;
    } catch (e) {
      print('Error during Japanese analysis: $e');
      rethrow;
    }
  }

  // Analyze Chinese text using FTS5 approach (for demonstration)
  Future<List<WordFrequencyWithDefinition>> _analyzeChineseWithFts5(String text) async {
    await driftDb.clearWordOccurrences();

    try {
      // For Chinese, we'll implement the FTS5 approach as described
      // This is a simplified version - in practice you'd want to use a proper tokenizer
      
      // For now, we'll split Chinese text by character as a basic approach
      // that works reasonably well for Chinese since many words are single characters
      final chars = _splitChineseCharacters(text);
      final wordOccurrences = <WordOccurrencesCompanion>[];

      for (var i = 0; i < chars.length; i++) {
        final char = chars[i];

        // Skip non-Chinese characters
        if (!_isChineseCharacter(char)) {
          continue;
        }

        wordOccurrences.add(WordOccurrencesCompanion.insert(
          word: char,
          reading: const Value(''), // No reading for pure Chinese chars
          baseForm: const Value(''),
          position: i,
        ));
      }

      if (wordOccurrences.isNotEmpty) {
        await driftDb.insertWordOccurrences(wordOccurrences);
      }

      final results = await driftDb.getWordFrequenciesWithDefinitions();
      return results;
    } catch (e) {
      print('Error during Chinese FTS5 analysis: $e');
      rethrow;
    }
  }

  // Simple character splitting for Chinese
  List<String> _splitChineseCharacters(String text) {
    // Remove non-Chinese characters first
    final cleaned = text.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
    return cleaned.split('');
  }

  bool _isChineseCharacter(String char) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(char);
  }

  // Fallback analysis using existing dictionary tokenizer
  Future<List<WordFrequencyWithDefinition>> _analyzeWithDictionary(String text) async {
    await driftDb.clearWordOccurrences();

    try {
      final tokens = await dictionaryService.tokenizeText(text);
      final wordOccurrences = <WordOccurrencesCompanion>[];

      for (var i = 0; i < tokens.length; i++) {
        final tokenText = tokens[i].text;

        // Skip punctuation and particles if desired
        if (_isPunctuationOrParticle(tokenText)) {
          continue;
        }

        wordOccurrences.add(WordOccurrencesCompanion.insert(
          word: tokenText,
          reading: Value(tokens[i].entry?.reading ?? ''),
          baseForm: const Value(''), // Base form not available with current approach
          position: i,
        ));
      }

      if (wordOccurrences.isNotEmpty) {
        await driftDb.insertWordOccurrences(wordOccurrences);
      }

      final results = await driftDb.getWordFrequenciesWithDefinitions();
      return results;
    } catch (e) {
      print('Error during dictionary analysis: $e');
      rethrow;
    }
  }

  // Helper method to detect if text contains Japanese characters
  bool _hasJapaneseChars(String text) {
    // Check for Japanese characters (Hiragana, Katakana, Kanji)
    return RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(text);
  }

  // Helper method to detect if text contains Chinese characters
  bool _hasChineseChars(String text) {
    // Check for Chinese characters (CJK Unified Ideographs)
    return RegExp(r'[\u4E00-\u9FFF]').hasMatch(text);
  }

  // Helper method to identify common Japanese punctuation and particles to exclude
  bool _isPunctuationOrParticle(String word) {
    // Common Japanese particles and punctuation to potentially exclude
    const particles = {
      'は', 'が', 'を', 'に', 'へ', 'で', 'の', 'と', 'も', 'や', 'か', 
      '、', '。', '「', '」', '『', '』', '（', '）', '…', '？', '！',
      'から', 'まで', 'より'
    };
    
    return particles.contains(word);
  }
  
  // Method to analyze text and return only the most frequent words
  Future<List<WordFrequencyWithDefinition>> analyzeTextTopWords(String text, {int limit = 100}) async {
    final allResults = await analyzeText(text);
    return allResults.take(limit).toList();
  }
  
  // Enhanced analysis that includes Yomichan dictionary lookups as well
  Future<List<EnhancedWordFrequency>> analyzeTextWithDictionary(String text) async {
    final db = await dictionaryService.yomichanDatabase;
    final basicResults = await analyzeText(text);
    
    // Enhance results with additional Yomichan dictionary data
    final enhancedResults = <EnhancedWordFrequency>[];
    
    for (final result in basicResults) {
      // Get additional dictionary information from Yomichan database
      final dictionaryEntries = await db.query(
        'entries',
        where: 'term = ? OR reading = ?',
        whereArgs: [result.word, result.word],
        limit: 5, // Get up to 5 matches
      );
      
      // Get frequency data
      final frequencyData = await db.query(
        'frequencies',
        where: 'term = ?',
        whereArgs: [result.word],
      );
      
      // Get pitch accent data
      final pitchData = await db.query(
        'pitches',
        where: 'term = ?',
        whereArgs: [result.word],
      );
      
      enhancedResults.add(EnhancedWordFrequency(
        word: result.word,
        count: result.count,
        firstOccurrence: result.firstOccurrence,
        definitions: result.definitions,
        reading: result.reading,
        popularity: result.popularity,
        dictionaryEntries: dictionaryEntries.length,
        frequencyData: frequencyData.length,
        pitchData: pitchData.length,
      ));
    }
    
    return enhancedResults;
  }
}

class EnhancedWordFrequency {
  final String word;
  final int count;
  final int firstOccurrence;
  final String? definitions;
  final String? reading;
  final int popularity;
  final int dictionaryEntries;
  final int frequencyData;
  final int pitchData;

  EnhancedWordFrequency({
    required this.word,
    required this.count,
    required this.firstOccurrence,
    this.definitions,
    this.reading,
    this.popularity = -1,
    required this.dictionaryEntries,
    required this.frequencyData,
    required this.pitchData,
  });
}