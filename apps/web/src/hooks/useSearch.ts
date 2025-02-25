import { useReducer, useRef, useCallback } from 'react';
import { useApp } from '../context/AppContext';
import { analyzeText } from '../services/IchiMoeService';
import { searchReducer, initialSearchState } from '../reducers/searchReducer';
import { TokenizedWord } from '../types';

export function useSearch() {
  const [state, dispatch] = useReducer(searchReducer, initialSearchState);
  const { 
    inputText, 
    results, 
    isAnalyzing, 
    showHistory, 
    autoConvert, 
    clipboardMonitor, 
    error 
  } = state;
  
  const { addToHistory } = useApp();
  const abortControllerRef = useRef<AbortController | null>(null);

  const handleInputChange = useCallback((text: string) => {
    dispatch({ type: 'SET_INPUT_TEXT', payload: text });
    dispatch({ type: 'SET_SHOW_HISTORY', payload: text.length > 0 });
  }, []);

  const handleSearch = useCallback(async (text: string) => {
    // Cancel any ongoing request
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }

    // Create a new abort controller for this request
    abortControllerRef.current = new AbortController();
    
    dispatch({ type: 'SET_IS_ANALYZING', payload: true });
    dispatch({ type: 'SET_SHOW_HISTORY', payload: false });
    dispatch({ type: 'SET_ERROR', payload: null });

    try {
      const result = await analyzeText(text, abortControllerRef.current.signal);
      dispatch({ type: 'SET_RESULTS', payload: result });
      
      // Update search history
      if (text.trim()) {
        addToHistory(text);
      }
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Analysis failed:', error);
        dispatch({ type: 'SET_ERROR', payload: error.message || 'Analysis failed' });
        dispatch({ type: 'SET_RESULTS', payload: [] });
      }
    } finally {
      dispatch({ type: 'SET_IS_ANALYZING', payload: false });
      abortControllerRef.current = null;
    }
  }, [addToHistory]);

  const handleHistorySelect = useCallback((text: string) => {
    dispatch({ type: 'SET_INPUT_TEXT', payload: text });
    dispatch({ type: 'SET_SHOW_HISTORY', payload: false });
    handleSearch(text);
  }, [handleSearch]);

  const toggleAutoConvert = useCallback(() => {
    dispatch({ type: 'SET_AUTO_CONVERT', payload: !autoConvert });
  }, [autoConvert]);

  const toggleClipboardMonitor = useCallback(() => {
    dispatch({ type: 'SET_CLIPBOARD_MONITOR', payload: !clipboardMonitor });
  }, [clipboardMonitor]);

  return {
    state,
    dispatch,
    handleInputChange,
    handleSearch,
    handleHistorySelect,
    toggleAutoConvert,
    toggleClipboardMonitor
  };
} 