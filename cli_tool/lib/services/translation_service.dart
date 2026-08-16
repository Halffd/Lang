import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lang_cli/utils/japanese_utils.dart';
import 'package:lang_cli/utils/chinese_util.dart';

class TranslationResult {
  final String fullTranslation;
  final List<WordTranslation> wordTranslations;

  TranslationResult({
    required this.fullTranslation,
    required this.wordTranslations,
  });

  Map<String, dynamic> toJson() {
    return {
      'fullTranslation': fullTranslation,
      'wordTranslations': wordTranslations.map((w) => w.toJson()).toList(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    if (wordTranslations.isNotEmpty) {
      final maxSourceLen = wordTranslations.map((w) => w.source.length).reduce((a, b) => a > b ? a : b);
      final colWidth = maxSourceLen + 2;
      buffer.writeln('${wordTranslations.map((w) => w.source).join(' ')}');
      buffer.writeln(fullTranslation);
      buffer.writeln('');
      buffer.writeln('Word-by-word:');
      for (final w in wordTranslations) {
        final padded = w.source.padRight(colWidth);
        buffer.writeln('$padded ${w.translation}');
      }
    } else {
      buffer.writeln(fullTranslation);
    }
    return buffer.toString();
  }
}

class WordTranslation {
  final String source;
  final String translation;

  WordTranslation({required this.source, required this.translation});

  Map<String, dynamic> toJson() {
    return {'source': source, 'translation': translation};
  }
}

class TranslationRequest {
  final String sourceText;
  final String sourceLanguage;
  final String targetLanguage;

  TranslationRequest({
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

enum TranslationProvider { googleCloud, gemini }

class TranslationService {
  static const String _baseUrl = 'https://translate.googleapis.com';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final String? geminiApiKey;
  TranslationProvider provider;

  TranslationService({
    this.geminiApiKey,
    this.provider = TranslationProvider.googleCloud,
  });

  Future<TranslationResult> translate(TranslationRequest request) async {
    switch (provider) {
      case TranslationProvider.gemini:
        return _translateGemini(request);
      case TranslationProvider.googleCloud:
        return _translateGoogleCloud(request);
    }
  }

  Future<TranslationResult> _translateGemini(TranslationRequest request) async {
    if (geminiApiKey == null || geminiApiKey!.isEmpty) {
      return _translateGoogleCloud(request);
    }
    try {
      final fullTranslation = await _geminiTranslateText(
        request.sourceText,
        request.sourceLanguage,
        request.targetLanguage,
      );

      final sourceWords = _tokenizeForWordTranslation(
          request.sourceText, request.sourceLanguage);
      final wordTranslations = <WordTranslation>[];
      for (final word in sourceWords) {
        try {
          final t = await _geminiTranslateText(
            word,
            request.sourceLanguage,
            request.targetLanguage,
          );
          wordTranslations.add(WordTranslation(source: word, translation: t));
        } catch (_) {
          wordTranslations.add(
            WordTranslation(source: word, translation: word),
          );
        }
      }

      return TranslationResult(
        fullTranslation: fullTranslation,
        wordTranslations: wordTranslations,
      );
    } catch (e) {
      return _translateGoogleCloud(request);
    }
  }

  Future<TranslationResult> _translateGoogleCloud(
    TranslationRequest request,
  ) async {
    try {
      final fullTranslation = await _googleTranslateText(
        request.sourceText,
        request.sourceLanguage,
        request.targetLanguage,
      );

      final sourceWords = _tokenizeForWordTranslation(
          request.sourceText, request.sourceLanguage);
      final wordTranslations = <WordTranslation>[];

      for (final word in sourceWords) {
        final wordTranslation = await _googleTranslateText(
          word,
          request.sourceLanguage,
          request.targetLanguage,
        );
        wordTranslations.add(
          WordTranslation(source: word, translation: wordTranslation),
        );
      }

      return TranslationResult(
        fullTranslation: fullTranslation,
        wordTranslations: wordTranslations,
      );
    } catch (e) {
      throw Exception('Translation failed: $e');
    }
  }

  Future<String> _googleTranslateText(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    final url =
        '$_baseUrl/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception(
        'Translation request failed with status: ${response.statusCode}',
      );
    }

    final data = json.decode(response.body);
    if (data != null && data is List && data.isNotEmpty && data[0] is List) {
      final translations = data[0] as List;
      final result = <String>[];
      for (final segment in translations) {
        if (segment is List && segment.isNotEmpty && segment[0] != null) {
          result.add(segment[0].toString());
        }
      }
      return result.join('').trim();
    } else {
      throw Exception('Unexpected translation response format');
    }
  }

  Future<String> _geminiTranslateText(
    String text,
    String sourceLang,
    String targetLang,
  ) async {
    final langName = _languageName(targetLang);
    final prompt =
        'Translate the following text to $langName. Output ONLY the translation, nothing else:\n\n$text';

    final url = Uri.parse('$_geminiUrl?key=$geminiApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text']
              ?.toString()
              .trim() ??
          text;
    } else {
      throw Exception('Gemini translation failed: ${response.statusCode}');
    }
  }

  static List<String> _tokenizeForWordTranslation(
      String text, String sourceLang) {
    if (sourceLang == 'ja') {
      return _tokenizeJapanese(text);
    } else if (sourceLang == 'zh') {
      return _tokenizeChinese(text);
    } else if (sourceLang == 'ko') {
      return _tokenizeKorean(text);
    } else {
      return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    }
  }

  static List<String> _tokenizeJapanese(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    String currentType = '';

    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      String type;
      if (JapaneseUtils.isKanji(ch)) {
        type = 'kanji';
      } else if (JapaneseUtils.isHiragana(ch) || JapaneseUtils.isKatakana(ch)) {
        type = 'kana';
      } else if (RegExp(r'[a-zA-Z0-9]').hasMatch(ch)) {
        type = 'latin';
      } else {
        type = 'other';
      }

      if (currentType.isEmpty) {
        currentType = type;
      } else if (type != currentType &&
          type != 'other' &&
          currentType != 'other') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        currentType = type;
      }

      buffer.write(ch);
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens.where((t) => t.trim().isNotEmpty).toList();
  }

  static List<String> _tokenizeChinese(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (final char in text.runes) {
      final ch = String.fromCharCode(char);
      if (ChineseUtil.containsChinese(ch)) {
        if (buffer.isNotEmpty &&
            !ChineseUtil.containsChinese(buffer.toString())) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(ch);
      } else if (RegExp(r'[a-zA-Z0-9]').hasMatch(ch)) {
        if (buffer.isNotEmpty &&
            ChineseUtil.containsChinese(buffer.toString())) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(ch);
      } else {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        if (ch.trim().isNotEmpty) {
          tokens.add(ch);
        }
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens.where((t) => t.trim().isNotEmpty).toList();
  }

  static List<String> _tokenizeKorean(String text) {
    return text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  static String _languageName(String code) {
    const names = {
      'en': 'English',
      'ja': 'Japanese',
      'zh': 'Chinese',
      'ko': 'Korean',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'tl': 'Filipino',
      'tr': 'Turkish',
      'nl': 'Dutch',
      'pl': 'Polish',
      'uk': 'Ukrainian',
      'sv': 'Swedish',
      'da': 'Danish',
      'fi': 'Finnish',
      'no': 'Norwegian',
      'cs': 'Czech',
      'ro': 'Romanian',
      'hu': 'Hungarian',
      'el': 'Greek',
      'he': 'Hebrew',
      'bg': 'Bulgarian',
      'hr': 'Croatian',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'et': 'Estonian',
      'lv': 'Latvian',
      'lt': 'Lithuanian',
      'ca': 'Catalan',
      'sr': 'Serbian',
      'sw': 'Swahili',
    };
    return names[code] ?? code;
  }
}
