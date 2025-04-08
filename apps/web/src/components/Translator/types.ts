export type TranslationMode = 'standard' | 'learning' | 'professional';

export interface WordTranslation {
  source: string;
  translation: string;
  pronunciation?: string;  // For learning mode
  partOfSpeech?: string;  // For professional mode
  alternativeTranslations?: string[];  // For professional mode
  examples?: string[];  // For learning mode
}

export interface TranslationResult {
  wordByWord: WordTranslation[];
  fullTranslation: string;
  mode: TranslationMode;
  confidence?: number;  // For professional mode
  formalityLevel?: 'formal' | 'informal' | 'neutral';  // For professional mode
  grammarNotes?: string[];  // For learning mode
  commonPhrases?: string[];  // For learning mode
} 