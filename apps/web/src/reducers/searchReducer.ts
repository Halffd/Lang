import { IchiMoeResult } from '../services/IchiMoeService';

export interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
}

export interface SearchState {
  inputText: string;
  results: TokenizedWord[];
  isAnalyzing: boolean;
  showHistory: boolean;
  autoConvert: boolean;
  clipboardMonitor: boolean;
  error: string | null;
}

export type SearchAction =
  | { type: 'SET_INPUT_TEXT'; payload: string }
  | { type: 'SET_ANALYZING'; payload: boolean }
  | { type: 'SET_RESULTS'; payload: TokenizedWord[] }
  | { type: 'CLEAR_RESULTS' }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'TOGGLE_AUTO_CONVERT' }
  | { type: 'TOGGLE_CLIPBOARD_MONITOR' }
  | { type: 'SET_SHOW_HISTORY'; payload: boolean }
  | { type: 'PROCESS_ICHI_MOE_RESULTS'; payload: IchiMoeResult[] };

export const initialSearchState: SearchState = {
  inputText: '',
  results: [],
  isAnalyzing: false,
  showHistory: false,
  autoConvert: true,
  clipboardMonitor: false,
  error: null,
};

function convertIchiMoeToTokenizedWord(ichiMoeResult: IchiMoeResult): TokenizedWord {
  return {
    word: ichiMoeResult.word,
    reading: ichiMoeResult.reading,
    definitions: ichiMoeResult.definitions,
    pos: ichiMoeResult.pos,
    frequency: Math.random() * 100, // Mock frequency for now
  };
}

export function searchReducer(state: SearchState, action: SearchAction): SearchState {
  switch (action.type) {
    case 'SET_INPUT_TEXT':
      return {
        ...state,
        inputText: action.payload,
        showHistory: action.payload.length > 0,
        error: null,
      };

    case 'SET_ANALYZING':
      return {
        ...state,
        isAnalyzing: action.payload,
        showHistory: action.payload ? false : state.showHistory,
      };

    case 'SET_RESULTS':
      return {
        ...state,
        results: action.payload,
      };

    case 'CLEAR_RESULTS':
      return {
        ...state,
        results: [],
      };

    case 'SET_ERROR':
      return {
        ...state,
        error: action.payload,
        results: [],
      };

    case 'TOGGLE_AUTO_CONVERT':
      return {
        ...state,
        autoConvert: !state.autoConvert,
      };

    case 'TOGGLE_CLIPBOARD_MONITOR':
      return {
        ...state,
        clipboardMonitor: !state.clipboardMonitor,
      };

    case 'SET_SHOW_HISTORY':
      return {
        ...state,
        showHistory: action.payload,
      };

    case 'PROCESS_ICHI_MOE_RESULTS':
      return {
        ...state,
        results: action.payload.map(convertIchiMoeToTokenizedWord),
        isAnalyzing: false,
        showHistory: false,
        error: null,
      };

    default:
      return state;
  }
} 