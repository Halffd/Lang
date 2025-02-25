export interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
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