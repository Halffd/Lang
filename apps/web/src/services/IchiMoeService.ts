import { TokenizedWord, DictionaryMetadata, ImportProgress } from '../types';

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

export class AnalysisError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AnalysisError';
  }
}

export class IchiMoeService {
  private baseUrl: string;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  async analyze(text: string): Promise<TokenizedWord[]> {
    try {
      const response = await fetch(`${this.baseUrl}/api/analyze`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return data.results.map((result: IchiMoeResult): TokenizedWord => ({
        surface: result.surface,
        reading: result.reading || result.surface,
        basic: result.basic || result.surface,
        pos: result.pos,
        pos_detail: result.pos_detail,
        definitions: result.definitions,
        translations: result.translations,
        frequency: result.frequency,
      }));
    } catch (error) {
      console.error('Error analyzing text:', error);
      throw error;
    }
  }

  // Mock data for testing
  private mockWords: Record<string, TokenizedWord> = {
    '日本語': {
      surface: '日本語',
      reading: 'にほんご',
      basic: '日本語',
      pos: 'noun',
      pos_detail: ['common'],
      definitions: ['Japanese language'],
      translations: ['Japanese'],
      frequency: 95
    },
    '勉強': {
      surface: '勉強',
      reading: 'べんきょう',
      basic: '勉強',
      pos: 'noun',
      pos_detail: ['common'],
      definitions: ['study', 'learning', 'diligence'],
      translations: ['to study', 'to learn'],
      frequency: 85
    },
    '食べる': {
      surface: '食べる',
      reading: 'たべる',
      basic: '食べる',
      pos: 'verb',
      pos_detail: ['common'],
      definitions: ['to eat', 'to consume'],
      translations: ['to eat'],
      frequency: 90
    }
  };

  async mockAnalyze(text: string): Promise<TokenizedWord[]> {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 800));

    const results: TokenizedWord[] = [];
    const words = text.split(/\s+/);
    
    for (const word of words) {
      if (this.mockWords[word]) {
        results.push(this.mockWords[word]);
      } else {
        results.push({
          surface: word,
          reading: word,
          basic: word,
          pos: 'unknown',
          pos_detail: ['unknown'],
          definitions: [`Definition for ${word}`],
          translations: [`Translation for ${word}`],
          frequency: Math.random() * 50,
        });
      }
    }

    return results;
  }
} 