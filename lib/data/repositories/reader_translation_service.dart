import 'package:flutter/foundation.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang_core/lang_core.dart' show Token;
import 'translation_service.dart';
import 'package:lang/data/datasources/remote/wiktionary_service.dart';
import 'package:lang/utils/language_detector.dart';

class ReaderTranslationService {
  final TranslationService _translationService;

  ReaderTranslationService(this._translationService);

  Future<void> getDetailedTranslationForToken(
    Token token,
    Function(String word, String language, List<String> details)
    onWiktionaryResult,
    Function(TranslationResult result) onTranslationResult,
    Function(String message) onError,
  ) async {
    if (!_isValidToken(token)) {
      return;
    }

    try {
      // First, detect the language of the token text
      final detectedLanguage = LanguageDetector.detect(token.surface);

      // Check if we should use the enhanced Wiktionary service for detailed information
      final wiktionaryDetails = await _fetchWiktionaryDetails(
        token.surface,
        detectedLanguage,
      );

      if (wiktionaryDetails.isNotEmpty) {
        // Use Wiktionary details as primary source for multi-language support
        onWiktionaryResult(token.surface, detectedLanguage, wiktionaryDetails);
        return;
      }

      // Fallback to the existing translation service if no Wiktionary details
      final request = TranslationRequest(
        sourceText: token.surface,
        sourceLanguage: detectedLanguage,
        targetLanguage: 'en', // Default to English output
      );

      final result = await _translationService.translate(request);

      if (result.wordTranslations.isNotEmpty) {
        // Show translation result
        onTranslationResult(result);
      } else {
        // If no translation found, show a message
        onError('No translation found for: ${token.surface}');
      }
    } catch (e) {
      onError('Failed to get translation for: ${token.surface}');
    }
  }

  bool _isValidToken(Token? token) {
    return token != null &&
        token.partOfSpeech == 'word' &&
        token.surface.isNotEmpty;
  }

  Future<List<String>> _fetchWiktionaryDetails(
    String text,
    String language,
  ) async {
    try {
      // the dictionary passthrough was a thin wrapper — call the
      // wiktionary service directly
      return await WiktionaryService().fetchWordDetailsForAnyLanguage(
        text,
        language,
      );
    } catch (e) {
      debugPrint('Error fetching Wiktionary details: $e');
      return [];
    }
  }
}
