import { IchiMoeResult } from '../services/IchiMoeService';
import { TokenizedWord } from '../types';

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
  | { type: 'SET_RESULTS'; payload: TokenizedWord[] }
  | { type: 'SET_IS_ANALYZING'; payload: boolean }
  | { type: 'SET_SHOW_HISTORY'; payload: boolean }
  | { type: 'SET_AUTO_CONVERT'; payload: boolean }
  | { type: 'SET_CLIPBOARD_MONITOR'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'RESET' };

export const initialSearchState: SearchState = {
  inputText: '',
  results: [],
  isAnalyzing: false,
  showHistory: false,
  autoConvert: true,
  clipboardMonitor: false,
  error: null,
};

// Memoized conversion function
export const convertIchiMoeToTokenizedWord = (ichiMoeResult: IchiMoeResult): TokenizedWord => ({
  word: ichiMoeResult.word,
  reading: ichiMoeResult.reading,
  definitions: ichiMoeResult.definitions,
  pos: ichiMoeResult.pos,
  frequency: Math.random() * 100, // Mock frequency for now
});

// Memoized state updates
const setInputTextState = (state: SearchState, text: string): SearchState => ({
  ...state,
  inputText: text,
  showHistory: text.length > 0,
  error: null,
});

const setAnalyzingState = (state: SearchState, analyzing: boolean): SearchState => ({
  ...state,
  isAnalyzing: analyzing,
  showHistory: analyzing ? false : state.showHistory,
});

const setResultsState = (state: SearchState, results: TokenizedWord[]): SearchState => ({
  ...state,
  results,
});

const setErrorState = (state: SearchState, error: string | null): SearchState => ({
  ...state,
  error,
  results: [],
});

const toggleAutoConvertState = (state: SearchState): SearchState => ({
  ...state,
  autoConvert: !state.autoConvert,
});

const toggleClipboardMonitorState = (state: SearchState): SearchState => ({
  ...state,
  clipboardMonitor: !state.clipboardMonitor,
});

const setShowHistoryState = (state: SearchState, show: boolean): SearchState => ({
  ...state,
  showHistory: show,
});

const processIchiMoeResultsState = (state: SearchState, results: IchiMoeResult[]): SearchState => ({
  ...state,
  results: results.map(convertIchiMoeToTokenizedWord),
  isAnalyzing: false,
  showHistory: false,
  error: null,
});

export function searchReducer(state: SearchState, action: SearchAction): SearchState {
  switch (action.type) {
    case 'SET_INPUT_TEXT':
      return setInputTextState(state, action.payload);

    case 'SET_RESULTS':
      return setResultsState(state, action.payload);

    case 'SET_IS_ANALYZING':
      return setAnalyzingState(state, action.payload);

    case 'SET_SHOW_HISTORY':
      return setShowHistoryState(state, action.payload);

    case 'SET_AUTO_CONVERT':
      return toggleAutoConvertState(state);

    case 'SET_CLIPBOARD_MONITOR':
      return toggleClipboardMonitorState(state);

    case 'SET_ERROR':
      return setErrorState(state, action.payload);

    case 'RESET':
      return initialSearchState;

    default:
      return state;
  }
} 