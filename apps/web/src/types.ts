export interface SearchResult {
  id: number;
  word: string;
  reading: string;
  definitions: string[];
  pos: string[];
  frequency?: number;
  examples?: Example[];
  tags?: string[];
}

export interface Example {
  id: number;
  japanese: string;
  english: string;
  source: string;
  tags: string[];
  words: string[];
  complexity_metrics: {
    uniqueWords: number;
    avgWordLength: number;
    readingComplexity: number;
    grammarComplexity: number;
    vocabularyLevel: string;
  };
  jlpt_level: string;
  grammar_points: Array<{
    name: string;
    level: string;
    description: string;
  }>;
}

export interface DictionaryInfo {
  name: string;
  description: string;
  version: string;
  author: string;
  url?: string;
  license?: string;
  revision?: string;
}

export interface DictionaryMetadata {
  title: string;
  format: string | number;
  revision: string;
  sequenced?: boolean;
}

export interface DictionaryEntry {
  type: 'term' | 'kanji';
  expression: string;
  reading: string;
  definitions: string[];
  tags?: string[];
  rules?: string[];
  score?: number;
  sequence?: number;
}

export interface ImportProgress {
  type: 'import' | 'frequency-import';
  percent: number;
  processed: number;
  total: number;
  status?: 'processing' | 'complete';
}

export interface FrequencyList {
  id: string;
  name: string;
  description: string;
  entries: FrequencyEntry[];
  priority?: number;
}

export interface FrequencyEntry {
  word: string;
  rank?: number;
  frequency?: number;
  tags?: string[];
}

export interface TagGroup {
  name: string;
  description: string;
  tags: string[];
}

export interface ExampleCollection {
  source: string;
  sentences: Example[];
  tags?: string[];
  metadata?: Record<string, any>;
}

export interface TokenizedWord {
  surface: string;
  reading: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  translations?: string[];
  examples?: string[];
  etymology?: string;
  additionalInfo?: {
    kanjiInfo?: {
      meaning: string;
      usage: string;
    };
  };
}

export interface IchiMoeResult {
  surface: string;
  reading: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  translations?: string[];
  tags?: string[];
  frequency?: number;
}

export interface Note {
  id: string;
  word: string;
  content: string;
  timestamp: number;
}

export interface HistoryItem {
  text: string;
  timestamp: number;
}

export const SCROLL_MODES = {
  NORMAL: 'NORMAL',
  CURSOR: 'CURSOR'
} as const;

export type ScrollMode = typeof SCROLL_MODES[keyof typeof SCROLL_MODES]; 