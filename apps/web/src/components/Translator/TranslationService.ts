import { TranslationMode, TranslationResult, WordTranslation } from './types';

export class TranslationService {
  static async translate(
    text: string,
    sourceLanguage: string,
    targetLanguage: string,
    mode: TranslationMode
  ): Promise<TranslationResult> {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Mock data for demonstration
    const words = text.split(' ');
    const wordByWord: WordTranslation[] = words.map((word, index) => ({
      source: word,
      translation: `translated_${word}`,
      pronunciation: mode === 'learning' ? `pronunciation_${word}` : undefined,
      partOfSpeech: mode === 'professional' ? 'noun' : undefined,
      alternativeTranslations: mode === 'professional' ? [`alt1_${word}`, `alt2_${word}`] : undefined,
      examples: mode === 'learning' ? [`example1_${word}`, `example2_${word}`] : undefined,
    }));

    return {
      wordByWord,
      fullTranslation: words.map(word => `translated_${word}`).join(' '),
      mode,
      confidence: mode === 'professional' ? 0.95 : undefined,
      formalityLevel: mode === 'professional' ? 'formal' : undefined,
      grammarNotes: mode === 'learning' ? ['Grammar note 1', 'Grammar note 2'] : undefined,
      commonPhrases: mode === 'learning' ? ['Common phrase 1', 'Common phrase 2'] : undefined,
    };
  }

  static getAvailableLanguages() {
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