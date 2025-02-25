import React, { forwardRef, useImperativeHandle, useCallback, useState } from 'react';
import { analyzeText, IchiMoeResult } from '../services/IchiMoeService';

export interface ScraperHandle {
  analyze: (text: string) => Promise<IchiMoeResult[]>;
  abort: () => void;
  isAnalyzing: boolean;
}

interface ScraperProps {
  onError?: (error: Error) => void;
  onAnalysisStart?: () => void;
  onAnalysisComplete?: (results: IchiMoeResult[]) => void;
}

export const IchiMoeScraper = forwardRef<ScraperHandle, ScraperProps>(
  ({ onError, onAnalysisStart, onAnalysisComplete }, ref) => {
    const [isAnalyzing, setIsAnalyzing] = useState(false);
    const [abortController, setAbortController] = useState<AbortController | null>(null);

    const analyze = useCallback(async (text: string): Promise<IchiMoeResult[]> => {
      if (isAnalyzing) {
        throw new Error('Analysis already in progress');
      }

      try {
        setIsAnalyzing(true);
        onAnalysisStart?.();

        // Create new abort controller for this request
        const controller = new AbortController();
        setAbortController(controller);

        const results = await analyzeText(text, controller.signal);
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

    useImperativeHandle(ref, () => ({
      analyze,
      abort,
      isAnalyzing
    }), [analyze, abort, isAnalyzing]);

    // This is a headless component, so it doesn't render anything
    return null;
  }
); 