import { TokenizedWord } from '../../types';

interface MockFunction<T = any> {
  (...args: any[]): T;
  mock: {
    calls: any[][];
    implementations: Array<(...args: any[]) => T>;
  };
  mockImplementation: (fn: (...args: any[]) => T) => MockFunction<T>;
  mockReturnValue: (value: T) => MockFunction<T>;
}

const createMockFunction = <T>(): MockFunction<T> => {
  const fn = ((...args: any[]) => {
    fn.mock.calls.push(args);
    const impl = fn.mock.implementations[fn.mock.implementations.length - 1];
    return impl ? impl(...args) : undefined;
  }) as MockFunction<T>;

  fn.mock = { calls: [], implementations: [] };
  
  fn.mockImplementation = (impl: (...args: any[]) => T) => {
    fn.mock.implementations.push(impl);
    return fn;
  };
  
  fn.mockReturnValue = (val: T) => {
    fn.mockImplementation(() => val);
    return fn;
  };
  
  return fn;
};

export const tokenizerService = {
  tokenize: createMockFunction<Promise<TokenizedWord[]>>().mockImplementation(
    async (text: string) => [{
      surface: text,
      reading: text,
      basic: text,
      pos: 'noun',
      pos_detail: ['common'],
      definitions: [],
      translations: []
    }]
  ),

  findWords: createMockFunction<Promise<TokenizedWord[]>>().mockImplementation(
    async (text: string) => [{
      surface: text,
      reading: text,
      basic: text,
      pos: 'noun',
      pos_detail: ['common'],
      definitions: [],
      translations: []
    }]
  ),

  analyzeComplexity: createMockFunction<Promise<{
    uniqueWords: number;
    avgWordLength: number;
    grammarPoints: Array<{ name: string; level: string; description: string }>;
    jlptLevel: string;
    readingComplexity: number;
    grammarComplexity: number;
    vocabularyLevel: string;
    kanjiDensity: number;
    uniqueKanji: number;
    conjugationTypes: string[];
    honorificLevel: string;
    sentenceLength: number;
    particleDensity: number;
  }>>().mockImplementation(async () => ({
    uniqueWords: 1,
    avgWordLength: 3,
    grammarPoints: [],
    jlptLevel: 'N5',
    readingComplexity: 0.1,
    grammarComplexity: 0.1,
    vocabularyLevel: 'beginner',
    kanjiDensity: 0.1,
    uniqueKanji: 1,
    conjugationTypes: [],
    honorificLevel: 'casual',
    sentenceLength: 1,
    particleDensity: 0.1
  })),

  addCustomDictionaryEntry: createMockFunction().mockImplementation(() => Promise.resolve()),
  
  addUserDefinedPattern: createMockFunction().mockImplementation(() => Promise.resolve()),
  
  initialize: createMockFunction().mockImplementation(() => Promise.resolve()),
  
  isInitialized: createMockFunction().mockReturnValue(true),

  getReadings: createMockFunction().mockImplementation((text: string) => {
    return text.split(' ').map(word => word);
  }),

  getDictionaryForms: createMockFunction().mockImplementation((text: string) => {
    return text.split(' ').map(word => word);
  })
}; 