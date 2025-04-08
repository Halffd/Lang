import { TranslationMode, TranslationResult } from '../components/Translator/types';

export class TranslationService {
  private static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  static async translate(
    text: string,
    sourceLanguage: string,
    targetLanguage: string,
    mode: TranslationMode
  ): Promise<TranslationResult> {
    // Simulate API delay
    await this.delay(1000);

    // Mock translation result
    const mockResult: TranslationResult = {
      wordByWord: [
        {
          source: text,
          translation: `Translated: ${text}`,
          pronunciation: mode === 'learning' ? 'Sample pronunciation' : undefined,
          partOfSpeech: mode === 'professional' ? 'noun' : undefined,
          alternativeTranslations: mode === 'professional' ? ['Alt 1', 'Alt 2'] : undefined,
          examples: mode === 'learning' ? ['Example 1', 'Example 2'] : undefined,
        },
      ],
      fullTranslation: `Complete translation of: ${text}`,
      mode,
      confidence: mode === 'professional' ? 0.95 : undefined,
      formalityLevel: mode === 'professional' ? 'formal' : undefined,
      grammarNotes: mode === 'learning' ? ['Grammar note 1', 'Grammar note 2'] : undefined,
      commonPhrases: mode === 'learning' ? ['Common phrase 1', 'Common phrase 2'] : undefined,
    };

    return mockResult;
  }

  static getAvailableLanguages(): { code: string; name: string }[] {
    return [
      { code: 'en', name: 'English' },
      { code: 'es', name: 'Spanish' },
      { code: 'fr', name: 'French' },
      { code: 'de', name: 'German' },
      { code: 'it', name: 'Italian' },
      { code: 'pt', name: 'Portuguese' },
      { code: 'ru', name: 'Russian' },
      { code: 'zh', name: 'Chinese' },
      { code: 'ja', name: 'Japanese' },
      { code: 'ko', name: 'Korean' },
    ];
  }
} 