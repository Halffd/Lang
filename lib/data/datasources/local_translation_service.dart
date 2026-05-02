import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import '../../domain/entities/translation_model.dart';

class LocalTranslationService {
  final OnDeviceTranslatorModelManager _modelManager = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators = {};

  static const Map<String, TranslateLanguage> _langMap = {
    'af': TranslateLanguage.afrikaans,
    'sq': TranslateLanguage.albanian,
    'ar': TranslateLanguage.arabic,
    'be': TranslateLanguage.belarusian,
    'bn': TranslateLanguage.bengali,
    'bg': TranslateLanguage.bulgarian,
    'ca': TranslateLanguage.catalan,
    'zh': TranslateLanguage.chinese,
    'hr': TranslateLanguage.croatian,
    'cs': TranslateLanguage.czech,
    'da': TranslateLanguage.danish,
    'nl': TranslateLanguage.dutch,
    'en': TranslateLanguage.english,
    'eo': TranslateLanguage.esperanto,
    'et': TranslateLanguage.estonian,
    'fi': TranslateLanguage.finnish,
    'fr': TranslateLanguage.french,
    'gl': TranslateLanguage.galician,
    'ka': TranslateLanguage.georgian,
    'de': TranslateLanguage.german,
    'el': TranslateLanguage.greek,
    'gu': TranslateLanguage.gujarati,
    'ht': TranslateLanguage.haitian,
    'he': TranslateLanguage.hebrew,
    'hi': TranslateLanguage.hindi,
    'hu': TranslateLanguage.hungarian,
    'is': TranslateLanguage.icelandic,
    'id': TranslateLanguage.indonesian,
    'ga': TranslateLanguage.irish,
    'it': TranslateLanguage.italian,
    'ja': TranslateLanguage.japanese,
    'kn': TranslateLanguage.kannada,
    'ko': TranslateLanguage.korean,
    'lv': TranslateLanguage.latvian,
    'lt': TranslateLanguage.lithuanian,
    'mk': TranslateLanguage.macedonian,
    'ms': TranslateLanguage.malay,
    'mt': TranslateLanguage.maltese,
    'mr': TranslateLanguage.marathi,
    'no': TranslateLanguage.norwegian,
    'fa': TranslateLanguage.persian,
    'pl': TranslateLanguage.polish,
    'pt': TranslateLanguage.portuguese,
    'ro': TranslateLanguage.romanian,
    'ru': TranslateLanguage.russian,
    'sk': TranslateLanguage.slovak,
    'sl': TranslateLanguage.slovenian,
    'es': TranslateLanguage.spanish,
    'sw': TranslateLanguage.swahili,
    'sv': TranslateLanguage.swedish,
    'tl': TranslateLanguage.tagalog,
    'ta': TranslateLanguage.tamil,
    'te': TranslateLanguage.telugu,
    'th': TranslateLanguage.thai,
    'tr': TranslateLanguage.turkish,
    'uk': TranslateLanguage.ukrainian,
    'ur': TranslateLanguage.urdu,
    'vi': TranslateLanguage.vietnamese,
    'cy': TranslateLanguage.welsh,
  };

  TranslateLanguage? _resolveLang(String code) => _langMap[code];

  bool isLanguageSupported(String code) => _langMap.containsKey(code);

  OnDeviceTranslator _getTranslator(String sourceLang, String targetLang) {
    final key = '${sourceLang}_$targetLang';
    return _translators.putIfAbsent(key, () {
      final src = _resolveLang(sourceLang) ?? TranslateLanguage.english;
      final tgt = _resolveLang(targetLang) ?? TranslateLanguage.english;
      return OnDeviceTranslator(sourceLanguage: src, targetLanguage: tgt);
    });
  }

  Future<bool> isModelDownloaded(String langCode) async {
    final lang = _resolveLang(langCode);
    if (lang == null) return false;
    return await _modelManager.isModelDownloaded(lang.bcpCode);
  }

  Future<void> ensureModelDownloaded(String langCode) async {
    final lang = _resolveLang(langCode);
    if (lang == null) return;
    final downloaded = await _modelManager.isModelDownloaded(lang.bcpCode);
    if (!downloaded) {
      await _modelManager.downloadModel(lang.bcpCode);
    }
  }

  Future<String> translateText(String text, String sourceLang, String targetLang) async {
    if (!isLanguageSupported(sourceLang) || !isLanguageSupported(targetLang)) {
      throw UnsupportedError('Language pair $sourceLang -> $targetLang not supported by ML Kit');
    }

    await ensureModelDownloaded(sourceLang);
    await ensureModelDownloaded(targetLang);

    final translator = _getTranslator(sourceLang, targetLang);
    return await translator.translateText(text);
  }

  Future<TranslationResult> translate(TranslationRequest request) async {
    final fullTranslation = await translateText(
      request.sourceText,
      request.sourceLanguage,
      request.targetLanguage,
    );

    final sourceWords = request.sourceText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final wordTranslations = <WordTranslation>[];
    for (final word in sourceWords) {
      try {
        final t = await translateText(word, request.sourceLanguage, request.targetLanguage);
        wordTranslations.add(WordTranslation(source: word, translation: t));
      } catch (_) {
        wordTranslations.add(WordTranslation(source: word, translation: word));
      }
    }

    return TranslationResult(
      fullTranslation: fullTranslation,
      wordTranslations: wordTranslations,
    );
  }

  Future<void> deleteModel(String langCode) async {
    final lang = _resolveLang(langCode);
    if (lang == null) return;
    await _modelManager.deleteModel(lang.bcpCode);
  }

  void dispose() {
    for (final t in _translators.values) {
      t.close();
    }
    _translators.clear();
  }
}
