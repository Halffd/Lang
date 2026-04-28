import '../../domain/entities/dictionary.dart';
import '../../domain/entities/translation_model.dart';
import '../repositories/dictionary_service.dart';
import '../repositories/translation_service.dart';
import '../../utils/language_detector.dart';

class ReaderTranslationService {
  final DictionaryService _dictionaryService;
  final TranslationService _translationService;

  ReaderTranslationService(this._dictionaryService, this._translationService);

  Future<void> getDetailedTranslationForToken(
    Token token, 
    Function(String word, String language, List<String> details) onWiktionaryResult,
    Function(TranslationResult result) onTranslationResult,
    Function(String message) onError,
  ) async {
    if (!_isValidToken(token)) {
      return;
    }

    try {
      // First, detect the language of the token text
      final detectedLanguage = LanguageDetector.detect(token.text);

      // Check if we should use the enhanced Wiktionary service for detailed information
      final wiktionaryDetails = await _fetchWiktionaryDetails(token.text, detectedLanguage);

      if (wiktionaryDetails.isNotEmpty) {
        // Use Wiktionary details as primary source for multi-language support
        onWiktionaryResult(token.text, detectedLanguage, wiktionaryDetails);
        return;
      }

      // Fallback to the existing translation service if no Wiktionary details
      final request = TranslationRequest(
        sourceText: token.text,
        sourceLanguage: detectedLanguage,
        targetLanguage: 'en', // Default to English output
      );

      final result = await _translationService.translate(request);

      if (result.wordTranslations.isNotEmpty) {
        // Show translation result
        onTranslationResult(result);
      } else {
        // If no translation found, show a message
        onError('No translation found for: ${token.text}');
      }
    } catch (e) {
      onError('Failed to get translation for: ${token.text}');
    }
  }

  bool _isValidToken(Token? token) {
    return token != null && token.isWord && token.text.isNotEmpty;
  }

  Future<List<String>> _fetchWiktionaryDetails(String text, String language) async {
    try {
      return await _dictionaryService.fetchWordDetailsMultiLanguage(text, language);
    } catch (e) {
      print('Error fetching Wiktionary details: $e');
      return [];
    }
  }
}