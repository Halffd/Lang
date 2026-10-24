import 'dart:async';

import 'dictionary_db.dart';
import 'language_detector.dart';
import 'script_ranges.dart';
import 'token.dart';

/// Dictionary-backed segmentation: longest-prefix match over
/// [DictionaryDb] for Japanese, script-based segmentation for Chinese
/// and Korean, whitespace words for Latin-script languages.
///
/// Pure Dart. The host supplies the dictionary surface and optionally a
/// [Deconjugator]; everything else is self-contained.
class Tokenizer {
  final DictionaryDb? db;
  final LanguageDetector detector;
  final Deconjugator? deconjugator;

  Tokenizer({this.db, LanguageDetector? detector, this.deconjugator})
      : detector = detector ?? LanguageDetector();

  /// ISO 639-1 code for [text] — the same detector [tokenize] uses, so
  /// call sites keep lookup and tokenization in sync.
  String detectLanguage(String text) =>
      text.isEmpty ? 'en' : detector.detect(text);

  Future<List<Token>> tokenize(String text) async {
    if (text.isEmpty) return [];

    switch (detectLanguage(text)) {
      case 'ja':
        return _tokenizeJapanese(text);
      case 'zh':
        return _tokenizeChinese(text);
      case 'ko':
        return _tokenizeKorean(text);
      default:
        return _tokenizeEuropean(text);
    }
  }

  /// Japanese: longest dictionary match wins (up to 10 characters);
  /// falls back to single characters when nothing matches.
  Future<List<Token>> _tokenizeJapanese(String text) async {
    final List<Token> tokens = [];
    int cursor = 0;

    while (cursor < text.length) {
      final char = text[cursor];
      final code = char.runes.first;
      if (!ScriptRanges.isKana(code) && !ScriptRanges.isKanji(code)) {
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

      var matchFound = false;
      var maxLength = 10;
      if (cursor + maxLength > text.length) {
        maxLength = text.length - cursor;
      }

      final candidates = <String>[
        for (var i = maxLength; i >= 1; i--) text.substring(cursor, cursor + i),
      ];

      final match = await db?.longestMatch(candidates);
      if (match != null) {
        final termLen = match.term.length;
        tokens.add(
          Token(
            surface: text.substring(cursor, cursor + termLen),
            reading: match.reading,
            definition: match.definition,
            partOfSpeech: 'word',
            startIndex: cursor,
            endIndex: cursor + termLen,
            tags: match.tags,
          ),
        );
        cursor += termLen;
        matchFound = true;
      }

      // De-conjugation fallback: no direct match — try base forms of
      // the longest unmatched candidates (e.g. 食べて → 食べる).
      if (!matchFound && deconjugator != null && candidates.isNotEmpty) {
        for (final candidate in candidates) {
          if (candidate.length < 2) continue;
          for (final form in deconjugator!.deconjugate(candidate)) {
            if (form == candidate) continue;
            final base = await db?.exactMatch(form);
            if (base != null) {
              tokens.add(
                Token(
                  surface: candidate,
                  reading: base.reading,
                  definition: base.definition,
                  partOfSpeech: 'word',
                  startIndex: cursor,
                  endIndex: cursor + candidate.length,
                  tags: base.tags,
                  deconjugatedFrom: form,
                ),
              );
              cursor += candidate.length;
              matchFound = true;
              break;
            }
          }
          if (matchFound) break;
        }
      }

      if (!matchFound) {
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

  /// Chinese: longest dictionary match up to 3 characters when a
  /// dictionary is wired, single characters otherwise.
  Future<List<Token>> _tokenizeChinese(String text) async {
    final tokens = <Token>[];
    var cursor = 0;

    while (cursor < text.length) {
      final char = text[cursor];
      if (!ScriptRanges.containsChinese(char)) {
        cursor++;
        continue;
      }

      var matched = false;
      if (db != null) {
        var maxLength = 3; // zh words are typically 1-3 characters
        if (cursor + maxLength > text.length) {
          maxLength = text.length - cursor;
        }
        final candidates = <String>[
          for (var i = maxLength; i >= 1; i--)
            text.substring(cursor, cursor + i),
        ];
        final match = await db!.longestMatch(candidates);
        if (match != null) {
          tokens.add(
            Token(
              surface: match.term,
              reading: match.reading,
              definition: match.definition,
              partOfSpeech: 'word',
              startIndex: cursor,
              endIndex: cursor + match.term.length,
              tags: match.tags,
            ),
          );
          cursor += match.term.length;
          matched = true;
        }
      }

      if (!matched) {
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

  List<Token> _tokenizeKorean(String text) {
    final tokens = <Token>[];
    for (var i = 0; i < text.length; i++) {
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

  List<Token> _tokenizeEuropean(String text) {
    final tokens = <Token>[];
    final words = text.split(RegExp(r'\s+'));
    var index = 0;

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

  /// Maps surface → sentence for the analyzed words.
  ///
  /// Gaps between tokens (whitespace in Latin-script text) render as a
  /// single space in the sentence value; CJK tokens abut with no gaps,
  /// so Japanese behavior is unchanged.
  Map<String, String> splitSentences(List<Token> tokens) {
    final sentences = <String, String>{};
    var currentSentence = '';
    var currentToken = '';
    var previousEnd = -1;

    for (final token in tokens) {
      if (previousEnd >= 0 && token.startIndex > previousEnd) {
        currentSentence += ' ';
      }
      previousEnd = token.endIndex;

      currentToken += token.surface;
      currentSentence += token.surface;

      if (token.surface.contains(RegExp(r'[。！？.!?]'))) {
        sentences[currentToken.trim()] = currentSentence.trim();
        currentToken = '';
        currentSentence = '';
        previousEnd = -1;
      }
    }

    if (currentToken.isNotEmpty) {
      sentences[currentToken.trim()] = currentSentence.trim();
    }

    return sentences;
  }
}
