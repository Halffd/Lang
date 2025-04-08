import { useState, useCallback } from 'react';
import { TokenizedWord } from '../types';

export interface IchiMoeResult {
  surface: string;
  reading?: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  translations?: string[];
  frequency?: number;
}

export class AnalysisError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AnalysisError';
  }
}

// Mock data for testing
const mockWords: Record<string, TokenizedWord> = {
  '日本語': {
    surface: '日本語',
    basic: '日本語',
    reading: 'にほんご',
    pos: 'noun',
    pos_detail: ['common'],
    definitions: ['Japanese language'],
    translations: ['Japanese']
  },
  '勉強': {
    surface: '勉強',
    basic: '勉強',
    reading: 'べんきょう',
    pos: 'verb',
    pos_detail: ['common'],
    definitions: ['study', 'learning', 'diligence'],
    translations: ['to study', 'to learn']
  },
  '食べる': {
    surface: '食べる',
    basic: '食べる',
    reading: 'たべる',
    pos: 'verb',
    pos_detail: ['common'],
    definitions: ['to eat'],
    translations: ['to eat', 'to consume']
  }
};

interface UseIchiMoeScraperProps {
  onError?: (error: Error) => void;
  onAnalysisStart?: () => void;
  onAnalysisComplete?: (results: IchiMoeResult[]) => void;
}

export function useIchiMoeScraper({
  onError,
  onAnalysisStart,
  onAnalysisComplete,
}: UseIchiMoeScraperProps = {}) {
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [abortController, setAbortController] = useState<AbortController | null>(null);

  const analyze = useCallback(async (text: string): Promise<TokenizedWord[]> => {
    if (isAnalyzing) {
      throw new Error('Analysis already in progress');
    }

    try {
      setIsAnalyzing(true);
      onAnalysisStart?.();

      // Create new abort controller for this request
      const controller = new AbortController();
      setAbortController(controller);

      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 800));

      // Check if the request was aborted
      if (controller.signal.aborted) {
        throw new Error('Request aborted');
      }

      // For testing, return mock data if the text contains any of our mock words
      const results: TokenizedWord[] = [];
      
      // Split the text into words (this is a very simplified approach)
      const words = text.split(/\s+/);
      
      for (const word of words) {
        if (mockWords[word]) {
          results.push(mockWords[word]);
        } else {
          // For unknown words, create a mock result
          results.push({
            surface: word,
            basic: word,
            reading: word,
            definitions: [`Definition for ${word}`],
            translations: [`Translation for ${word}`],
            pos: 'unknown',
            pos_detail: ['unknown'],
            frequency: Math.random() * 50,
          });
        }
      }

      // If no results, throw an error
      if (results.length === 0) {
        throw new AnalysisError('No words found in the text');
      }

      onAnalysisComplete?.(results);
      return results;
    } catch (error) {
      if (error instanceof Error) {
        onError?.(error);
      } else {
        onError?.(new Error('Unknown error occurred during analysis'));
      }
      throw error;
    } finally {
      setIsAnalyzing(false);
      setAbortController(null);
    }
  }, [onAnalysisStart, onAnalysisComplete, onError, isAnalyzing]);

  const abort = useCallback(() => {
    if (abortController) {
      abortController.abort();
      setAbortController(null);
      setIsAnalyzing(false);
    }
  }, [abortController]);

  return {
    analyze,
    abort,
    isAnalyzing
  };
} 