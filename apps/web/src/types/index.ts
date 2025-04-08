export interface TokenizedWord {
  surface: string;  // The word as it appears in text
  reading?: string; // Reading in hiragana
  basic: string;    // Dictionary form
  pos: string;      // Part of speech
  pos_detail: string[];
  pronunciation?: string;
  conjugation?: string;
  conjugation_type?: string;
  definitions: string[];
  translations?: string[];
  frequency?: number;
}

export interface ComplexityAnalysis {
  uniqueWords: number;
  averageWordLength: number;
  grammarPoints: Array<{
    name: string;
    level: string;
    description: string;
  }>;
  estimatedJlptLevel: string;
  readingComplexity: number;
  grammarComplexity: number;
  kanjiDensity: number;
  uniqueKanji: number;
  conjugationTypes: string[];
  honorificLevel: string;
  sentenceLength: number;
  particleDensity: number;
}

export interface HistoryItem {
  text: string;
  timestamp: number;
}

export interface Note {
  id: string;
  word: string;
  content: string;
  timestamp: number;
}

export const SCROLL_MODES = {
  NORMAL: 'NORMAL',
  CURSOR: 'CURSOR'
} as const;

export type ScrollMode = typeof SCROLL_MODES[keyof typeof SCROLL_MODES]; 