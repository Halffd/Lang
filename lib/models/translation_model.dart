class TranslationRequest {
  final String sourceText;
  final String sourceLanguage;
  final String targetLanguage;

  TranslationRequest({
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceText': sourceText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
    };
  }
}

class TranslationResult {
  final String fullTranslation;
  final List<WordTranslation> wordTranslations;

  TranslationResult({
    required this.fullTranslation,
    required this.wordTranslations,
  });
}

class WordTranslation {
  final String source;
  final String translation;

  WordTranslation({
    required this.source,
    required this.translation,
  });
}

class LanguageOption {
  final String code;
  final String name;

  const LanguageOption(this.code, this.name);

  static const List<LanguageOption> all = [
    LanguageOption('af', 'Afrikaans'),
    LanguageOption('ar', 'Arabic'),
    LanguageOption('bg', 'Bulgarian'),
    LanguageOption('ca', 'Catalan'),
    LanguageOption('zh', 'Chinese'),
    LanguageOption('hr', 'Croatian'),
    LanguageOption('cs', 'Czech'),
    LanguageOption('da', 'Danish'),
    LanguageOption('nl', 'Dutch'),
    LanguageOption('en', 'English'),
    LanguageOption('et', 'Estonian'),
    LanguageOption('tl', 'Filipino'),
    LanguageOption('fi', 'Finnish'),
    LanguageOption('fr', 'French'),
    LanguageOption('de', 'German'),
    LanguageOption('el', 'Greek'),
    LanguageOption('iw', 'Hebrew'),
    LanguageOption('hi', 'Hindi'),
    LanguageOption('hu', 'Hungarian'),
    LanguageOption('id', 'Indonesian'),
    LanguageOption('it', 'Italian'),
    LanguageOption('ja', 'Japanese'),
    LanguageOption('ko', 'Korean'),
    LanguageOption('lv', 'Latvian'),
    LanguageOption('lt', 'Lithuanian'),
    LanguageOption('no', 'Norwegian'),
    LanguageOption('pl', 'Polish'),
    LanguageOption('pt', 'Portuguese'),
    LanguageOption('ro', 'Romanian'),
    LanguageOption('ru', 'Russian'),
    LanguageOption('sr', 'Serbian'),
    LanguageOption('sk', 'Slovak'),
    LanguageOption('sl', 'Slovenian'),
    LanguageOption('es', 'Spanish'),
    LanguageOption('sv', 'Swedish'),
    LanguageOption('th', 'Thai'),
    LanguageOption('tr', 'Turkish'),
    LanguageOption('uk', 'Ukrainian'),
    LanguageOption('vi', 'Vietnamese'),
  ];
}