import { TokenizedWord } from '../types';

export interface IchiMoeResult {
  word: string;
  reading?: string;
  definitions: string[];
  pos?: string;
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
    word: '日本語',
    reading: 'にほんご',
    definitions: ['Japanese language'],
    translations: ['Japanese'],
    pos: 'noun',
    frequency: 95,
  },
  '勉強': {
    word: '勉強',
    reading: 'べんきょう',
    definitions: ['study', 'learning', 'diligence'],
    translations: ['to study', 'to learn'],
    pos: 'noun',
    frequency: 85,
  },
  '食べる': {
    word: '食べる',
    reading: 'たべる',
    definitions: ['to eat', 'to consume'],
    translations: ['to eat'],
    pos: 'verb',
    frequency: 90,
  },
};

/**
 * Analyzes Japanese text and returns tokenized words
 */
export async function analyzeText(text: string, signal?: AbortSignal): Promise<TokenizedWord[]> {
  // Simulate API delay
  await new Promise(resolve => setTimeout(resolve, 800));

  // Check if the request was aborted
  if (signal?.aborted) {
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
        word,
        reading: word,
        definitions: [`Definition for ${word}`],
        translations: [`Translation for ${word}`],
        pos: 'unknown',
        frequency: Math.random() * 50,
      });
    }
  }

  // If no results, throw an error
  if (results.length === 0) {
    throw new AnalysisError('No words found in the text');
  }

  return results;
} 