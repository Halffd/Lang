import { useState, useEffect, useCallback } from 'react';
import type { TokenizedWord, ComplexityAnalysis, CustomDictionaryEntry, UserDefinedPattern } from '../services/TokenizerService';

export interface TokenizerState {
  isLoading: boolean;
  error: Error | null;
  tokenize: (text: string) => Promise<TokenizedWord[]>;
  analyzeComplexity: (text: string) => Promise<ComplexityAnalysis>;
  addCustomEntry: (entry: CustomDictionaryEntry) => Promise<void>;
  addPattern: (pattern: UserDefinedPattern) => Promise<void>;
}

export function useTokenizer(): TokenizerState {
  const [tokenizerService, setTokenizerService] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let mounted = true;

    async function loadTokenizer() {
      try {
        // Dynamically import the tokenizer service
        const { tokenizerService } = await import('../services/TokenizerService');
        if (mounted) {
          setTokenizerService(tokenizerService);
          setIsLoading(false);
        }
      } catch (err) {
        if (mounted) {
          setError(err instanceof Error ? err : new Error('Failed to load tokenizer'));
          setIsLoading(false);
        }
      }
    }

    loadTokenizer();

    return () => {
      mounted = false;
    };
  }, []);

  const tokenize = useCallback(async (text: string): Promise<TokenizedWord[]> => {
    if (!tokenizerService) {
      throw new Error('Tokenizer not initialized');
    }
    return tokenizerService.tokenize(text);
  }, [tokenizerService]);

  const analyzeComplexity = useCallback(async (text: string): Promise<ComplexityAnalysis> => {
    if (!tokenizerService) {
      throw new Error('Tokenizer not initialized');
    }
    return tokenizerService.analyzeComplexity(text);
  }, [tokenizerService]);

  const addCustomEntry = useCallback(async (entry: CustomDictionaryEntry): Promise<void> => {
    if (!tokenizerService) {
      throw new Error('Tokenizer not initialized');
    }
    return tokenizerService.addCustomDictionaryEntry(entry);
  }, [tokenizerService]);

  const addPattern = useCallback(async (pattern: UserDefinedPattern): Promise<void> => {
    if (!tokenizerService) {
      throw new Error('Tokenizer not initialized');
    }
    return tokenizerService.addUserDefinedPattern(pattern);
  }, [tokenizerService]);

  return {
    isLoading,
    error,
    tokenize,
    analyzeComplexity,
    addCustomEntry,
    addPattern
  };
} 