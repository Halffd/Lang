import 'language_detector.dart';
import '../../domain/entities/dictionary.dart' as model;
import '../datasources/remote/ichi_moe_service.dart';

/// Service for multi-language text tokenization
class TokenizerService {
  final LanguageDetector _languageDetector = LanguageDetector();
  final IchiMoeService _ichiMoeService = IchiMoeService();

  /// Tokenize text based on detected language
  Future<List<Token>> tokenize(String text) async {
    if (text.isEmpty) return [];

    final language = _languageDetector.detect(text);
    
    switch (language) {
      case 'ja':
        return await _tokenizeJapanese(text);
      case 'zh':
        return _tokenizeChinese(text);
      case 'ko':
        return _tokenizeKorean(text);
      default:
        return _tokenizeEuropean(text);
    }
  }

  /// Tokenize Japanese text using ichi.moe
  Future<List<Token>> _tokenizeJapanese(String text) async {
    try {
      final results = await _ichiMoeService.analyze(text);
      return results.map((r) => Token(
        surface: r.word,
        reading: r.reading,
        definition: r.definitions.join('; '),
        partOfSpeech: r.partOfSpeech,
        startIndex: 0, // ichi.moe doesn't provide indices
        endIndex: 0,
      )).toList();
    } catch (e) {
      print('Japanese tokenization failed: $e');
      return _fallbackJapaneseTokenize(text);
    }
  }

  /// Fallback Japanese tokenization (character-based)
  List<Token> _fallbackJapaneseTokenize(String text) {
    final tokens = <Token>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]').hasMatch(char)) {
        tokens.add(Token(
          surface: char,
          reading: '',
          definition: '',
          partOfSpeech: 'character',
          startIndex: i,
          endIndex: i + 1,
        ));
      }
    }
    return tokens;
  }

  /// Tokenize Chinese text (character-based)
  List<Token> _tokenizeChinese(String text) {
    final tokens = <Token>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (ChineseUtil.containsChinese(char)) {
        tokens.add(Token(
          surface: char,
          reading: '',
          definition: '',
          partOfSpeech: 'character',
          startIndex: i,
          endIndex: i + 1,
        ));
      }
    }
    return tokens;
  }

  /// Tokenize Korean text
  List<Token> _tokenizeKorean(String text) {
    // For now, return character tokens
    // Could integrate a Korean morphological analyzer
    final tokens = <Token>[];
    for (int i = 0; i < text.length; i++) {
      tokens.add(Token(
        surface: text[i],
        reading: '',
        definition: '',
        partOfSpeech: 'character',
        startIndex: i,
        endIndex: i + 1,
      ));
    }
    return tokens;
  }

  /// Tokenize European (Latin-based) text by words
  List<Token> _tokenizeEuropean(String text) {
    final tokens = <Token>[];
    final words = text.split(RegExp(r'\s+'));
    int index = 0;
    
    for (final word in words) {
      if (word.isNotEmpty) {
        tokens.add(Token(
          surface: word,
          reading: '',
          definition: '',
          partOfSpeech: 'word',
          startIndex: index,
          endIndex: index + word.length,
        ));
      }
      index += word.length + 1; // +1 for space
    }
    return tokens;
  }
}

/// Token representation
class Token {
  final String surface;
  final String reading;
  final String definition;
  final String partOfSpeech;
  final int startIndex;
  final int endIndex;

  const Token({
    required this.surface,
    required this.reading,
    required this.definition,
    required this.partOfSpeech,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toJson() => {
    'surface': surface,
    'reading': reading,
    'definition': definition,
    'partOfSpeech': partOfSpeech,
    'startIndex': startIndex,
    'endIndex': endIndex,
  };
}