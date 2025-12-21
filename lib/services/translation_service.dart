import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/translation_model.dart';

class TranslationService {
  static const String _baseUrl = 'https://translate.googleapis.com';

  /// Translates text using Google Translate API
  Future<TranslationResult> translate(TranslationRequest request) async {
    try {
      // First, get the full sentence translation
      final fullTranslation = await _translateText(request.sourceText, 
          request.sourceLanguage, request.targetLanguage);

      // Then get word-by-word translations
      final sourceWords = request.sourceText.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
      final wordTranslations = <WordTranslation>[];

      for (final word in sourceWords) {
        final wordTranslation = await _translateText(word, request.sourceLanguage, request.targetLanguage);
        
        // Only add to list if the translation is different from the source word
        if (word.toLowerCase() != wordTranslation.toLowerCase()) {
          wordTranslations.add(WordTranslation(
            source: word,
            translation: wordTranslation,
          ));
        } else {
          // Add the word even if translation is same, so we can display the structure
          wordTranslations.add(WordTranslation(
            source: word,
            translation: wordTranslation,
          ));
        }
      }

      return TranslationResult(
        fullTranslation: fullTranslation,
        wordTranslations: wordTranslations,
      );
    } catch (e) {
      throw Exception('Translation failed: $e');
    }
  }

  /// Internal method to translate individual text
  Future<String> _translateText(String text, String sourceLang, String targetLang) async {
    final url = '$_baseUrl/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}';
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('Translation request failed with status: ${response.statusCode}');
    }
    
    final data = json.decode(response.body);
    
    // Google Translate API returns a complex nested array
    // First element contains an array of translations
    if (data != null && data is List && data.length > 0 && data[0] is List) {
      final translations = data[0] as List;
      
      // Combine all translation segments
      final result = <String>[];
      for (final segment in translations) {
        if (segment is List && segment.length > 0 && segment[0] != null) {
          result.add(segment[0].toString());
        }
      }
      
      return result.join('').trim();
    } else {
      throw Exception('Unexpected translation response format');
    }
  }
}