import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lang/domain/entities/translation_model.dart';
import '../datasources/local_translation_service.dart';

enum TranslationProvider { googleCloud, mlKit, gemini }

class TranslationService {
  static const String _baseUrl = 'https://translate.googleapis.com';
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final LocalTranslationService? localService;
  final String? geminiApiKey;
  TranslationProvider provider;

  TranslationService({
    this.localService,
    this.geminiApiKey,
    this.provider = TranslationProvider.googleCloud,
  });

  TranslationService withProvider(TranslationProvider p) {
    return TranslationService(
      localService: localService,
      geminiApiKey: geminiApiKey,
      provider: p,
    );
  }

  Future<TranslationResult> translate(TranslationRequest request) async {
    switch (provider) {
      case TranslationProvider.mlKit:
        return _translateMLKit(request);
      case TranslationProvider.gemini:
        return _translateGemini(request);
      case TranslationProvider.googleCloud:
        return _translateGoogleCloud(request);
    }
  }

  Future<TranslationResult> _translateMLKit(TranslationRequest request) async {
    if (localService == null ||
        !localService!.isLanguageSupported(request.sourceLanguage) ||
        !localService!.isLanguageSupported(request.targetLanguage)) {
      return _translateGoogleCloud(request);
    }
    try {
      return await localService!.translate(request);
    } catch (e) {
      return _translateGoogleCloud(request);
    }
  }

  Future<TranslationResult> _translateGemini(TranslationRequest request) async {
    if (geminiApiKey == null || geminiApiKey!.isEmpty) {
      return _translateGoogleCloud(request);
    }
    try {
      final fullTranslation = await _geminiTranslateText(
        request.sourceText, request.sourceLanguage, request.targetLanguage);

      final sourceWords = request.sourceText
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      final wordTranslations = <WordTranslation>[];
      for (final word in sourceWords) {
        try {
          final t = await _geminiTranslateText(word, request.sourceLanguage, request.targetLanguage);
          wordTranslations.add(WordTranslation(source: word, translation: t));
        } catch (_) {
          wordTranslations.add(WordTranslation(source: word, translation: word));
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

  Future<TranslationResult> _translateGoogleCloud(TranslationRequest request) async {
    try {
      final fullTranslation = await _googleTranslateText(
        request.sourceText, request.sourceLanguage, request.targetLanguage);

      final sourceWords = request.sourceText
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList();
      final wordTranslations = <WordTranslation>[];

      for (final word in sourceWords) {
        final wordTranslation = await _googleTranslateText(
          word, request.sourceLanguage, request.targetLanguage);
        wordTranslations.add(WordTranslation(
          source: word,
          translation: wordTranslation,
        ));
      }

      return TranslationResult(
        fullTranslation: fullTranslation,
        wordTranslations: wordTranslations,
      );
    } catch (e) {
      // If cloud fails, try ML Kit fallback
      if (localService != null &&
          localService!.isLanguageSupported(request.sourceLanguage) &&
          localService!.isLanguageSupported(request.targetLanguage)) {
        try {
          return await localService!.translate(request);
        } catch (_) {}
      }
      throw Exception('Translation failed: $e');
    }
  }

  Future<String> _googleTranslateText(String text, String sourceLang, String targetLang) async {
    final url = '$_baseUrl/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Translation request failed with status: ${response.statusCode}');
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

  Future<String> _geminiTranslateText(String text, String sourceLang, String targetLang) async {
    final langName = _languageName(targetLang);
    final prompt = 'Translate the following text to $langName. Output ONLY the translation, nothing else:\n\n$text';

    final url = Uri.parse('$_geminiUrl?key=$geminiApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'parts': [{'text': prompt}]
        }]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text']?.toString().trim() ?? text;
    } else {
      throw Exception('Gemini translation failed: ${response.statusCode}');
    }
  }

  static String _languageName(String code) {
    const names = {
      'en': 'English', 'ja': 'Japanese', 'zh': 'Chinese', 'ko': 'Korean',
      'es': 'Spanish', 'fr': 'French', 'de': 'German', 'it': 'Italian',
      'pt': 'Portuguese', 'ru': 'Russian', 'ar': 'Arabic', 'hi': 'Hindi',
      'th': 'Thai', 'vi': 'Vietnamese', 'id': 'Indonesian', 'ms': 'Malay',
      'tl': 'Filipino', 'tr': 'Turkish', 'nl': 'Dutch', 'pl': 'Polish',
      'uk': 'Ukrainian', 'sv': 'Swedish', 'da': 'Danish', 'fi': 'Finnish',
      'no': 'Norwegian', 'cs': 'Czech', 'ro': 'Romanian', 'hu': 'Hungarian',
      'el': 'Greek', 'he': 'Hebrew', 'bg': 'Bulgarian', 'hr': 'Croatian',
      'sk': 'Slovak', 'sl': 'Slovenian', 'et': 'Estonian', 'lv': 'Latvian',
      'lt': 'Lithuanian', 'ca': 'Catalan', 'sr': 'Serbian', 'sw': 'Swahili',
    };
    return names[code] ?? code;
  }
}
