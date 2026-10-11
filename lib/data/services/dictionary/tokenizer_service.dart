import 'package:lang/utils/chinese_util.dart';
import 'package:lang/data/services/dictionary/language_detector.dart';
import 'package:lang/database/database_manager.dart';
import 'package:lang/domain/entities/dictionary.dart';

/// Service for multi-language text tokenization
class TokenizerService {
  final LanguageDetector _languageDetector = LanguageDetector();

  /// Detected ISO 639-1 code for [text] — the same detector [tokenize]
  /// uses, exposed so call sites can keep lookup and tokenisation in sync.
  String detectLanguage(String text) =>
      text.isEmpty ? 'en' : _languageDetector.detect(text);

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

  /// Tokenize Japanese text using the yomichan dictionary database
  /// for proper MeCab-style word segmentation.
  Future<List<Token>> _tokenizeJapanese(String text) async {
    final db = await DatabaseManager().database;
    final List<Token> tokens = [];
    int cursor = 0;

    while (cursor < text.length) {
      // Skip non-Japanese characters (spaces, punctuation, etc.)
      final char = text[cursor];
      if (!RegExp(
        r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]',
      ).hasMatch(char)) {
        tokens.add(
          Token(
            surface: char,
            reading: '',
            definition: '',
            partOfSpeech: 'punctuation',
            startIndex: cursor,
            endIndex: cursor + 1,
          ),
        );
        cursor++;
        continue;
      }

      bool matchFound = false;

      // Try longest match first (up to 10 characters)
      int maxLength = 10;
      if (cursor + maxLength > text.length) {
        maxLength = text.length - cursor;
      }

      final candidates = <String>[];
      for (int i = maxLength; i >= 1; i--) {
        candidates.add(text.substring(cursor, cursor + i));
      }

      if (candidates.isNotEmpty) {
        final placeholders = List.filled(candidates.length, '?').join(',');
        final results = await db.query(
          'entries',
          where: 'term IN ($placeholders)',
          whereArgs: candidates,
          orderBy: 'length(term) DESC',
          limit: 1,
        );

        if (results.isNotEmpty) {
          final row = results.first;
          final entry = DictionaryEntry.fromJson(row);
          final termLen = entry.term.length;
          tokens.add(
            Token(
              surface: text.substring(cursor, cursor + termLen),
              reading: entry.reading,
              definition: entry.definitions.isNotEmpty
                  ? entry.definitions.first
                  : '',
              partOfSpeech: 'word',
              startIndex: cursor,
              endIndex: cursor + termLen,
            ),
          );
          cursor += termLen;
          matchFound = true;
        }
      }

      if (!matchFound) {
        // No dictionary match, fallback to single character
        tokens.add(
          Token(
            surface: char,
            reading: '',
            definition: '',
            partOfSpeech: 'character',
            startIndex: cursor,
            endIndex: cursor + 1,
          ),
        );
        cursor++;
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
        tokens.add(
          Token(
            surface: char,
            reading: '',
            definition: '',
            partOfSpeech: 'character',
            startIndex: i,
            endIndex: i + 1,
          ),
        );
      }
    }
    return tokens;
  }

  /// Tokenize Korean text
  List<Token> _tokenizeKorean(String text) {
    final tokens = <Token>[];
    for (int i = 0; i < text.length; i++) {
      tokens.add(
        Token(
          surface: text[i],
          reading: '',
          definition: '',
          partOfSpeech: 'character',
          startIndex: i,
          endIndex: i + 1,
        ),
      );
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
        tokens.add(
          Token(
            surface: word,
            reading: '',
            definition: '',
            partOfSpeech: 'word',
            startIndex: index,
            endIndex: index + word.length,
          ),
        );
      }
      index += word.length + 1; // +1 for space
    }
    return tokens;
  }

  /// Split text into sentences
  Map<String, String> splitSentences(List<Token> tokens) {
    final sentences = <String, String>{};
    String currentSentence = '';
    String currentToken = '';

    for (final token in tokens) {
      currentToken += token.surface;
      currentSentence += token.surface;

      if (token.surface.contains(RegExp(r'[。！？.!?]'))) {
        sentences[currentToken.trim()] = currentSentence.trim();
        currentToken = '';
        currentSentence = '';
      }
    }

    if (currentToken.isNotEmpty) {
      sentences[currentToken.trim()] = currentSentence.trim();
    }

    return sentences;
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
