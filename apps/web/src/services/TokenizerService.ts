import * as kuromoji from 'kuromoji';
import { Platform } from 'react-native';

export interface TokenizedWord {
  surface: string;
  reading: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  translations?: string[];
  frequency?: number;
  conjugation?: string;
  conjugation_type?: string;
  pronunciation?: string;
  tags?: string[];
}

export interface GrammarPattern {
  name: string;
  level: string;
  pattern: RegExp | ((tokens: TokenizedWord[], index: number) => boolean);
  description: string;
}

export interface CustomDictionaryEntry {
  word: string;
  reading: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  tags?: string[];
  frequency?: number;
}

export interface UserDefinedPattern {
  name: string;
  pattern: (tokens: TokenizedWord[], index: number) => boolean;
  description: string;
  priority?: number;
  level?: string;
}

export interface ComplexityAnalysis {
  uniqueWords: number;
  avgWordLength: number;
  readingComplexity: number;
  grammarComplexity: number;
  vocabularyLevel: string;
  grammarPoints: Array<{ name: string; level: string; description: string }>;
  jlptLevel: string;
  kanjiDensity: number;
  uniqueKanji: number;
  conjugationTypes: string[];
  honorificLevel: string;
  sentenceLength: number;
  particleDensity: number;
  readingVariety: number;
}

export class TokenizerService {
  private tokenizer: any = null;
  private initializing: boolean = false;
  private initPromise: Promise<void> | null = null;
  private customDictionary: Map<string, TokenizedWord> = new Map();
  private userPatterns: UserDefinedPattern[] = [];
  private grammarPatterns: GrammarPattern[] = [
    {
      name: 'causative',
      level: 'N3',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.conjugation === 'causative' || 
               t.surface.endsWith('させる') || 
               t.surface.endsWith('させられる');
      },
      description: 'Making someone do something'
    },
    {
      name: 'passive',
      level: 'N4',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.conjugation === 'passive' || 
               t.surface.endsWith('れる') || 
               t.surface.endsWith('られる');
      },
      description: 'Passive voice construction'
    },
    {
      name: 'potential',
      level: 'N4',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.conjugation === 'potential' || 
               t.surface.endsWith('える') || 
               t.surface.endsWith('られる');
      },
      description: 'Ability to do something'
    },
    {
      name: 'volitional',
      level: 'N3',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.conjugation === 'volitional' || 
               t.surface.endsWith('よう') || 
               t.surface.endsWith('ましょう');
      },
      description: 'Expressing intention or invitation'
    },
    {
      name: 'conditional-ba',
      level: 'N4',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.surface.endsWith('ば') || 
               t.surface.endsWith('れば');
      },
      description: 'If/when conditional using ば'
    },
    {
      name: 'conditional-tara',
      level: 'N4',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.surface.endsWith('たら') || 
               t.surface.endsWith('だら');
      },
      description: 'If/when conditional using たら'
    },
    {
      name: 'te-form-progressive',
      level: 'N4',
      pattern: (tokens, i) => {
        if (i >= tokens.length - 1) return false;
        const t = tokens[i];
        const next = tokens[i + 1];
        return t.surface.endsWith('て') && 
               (next.basic === 'いる' || next.basic === 'います');
      },
      description: 'Ongoing action using て-form + いる'
    },
    {
      name: 'honorific',
      level: 'N2',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.surface.includes('お') || 
               t.surface.includes('ご') || 
               t.surface.endsWith('ます') ||
               t.surface.endsWith('です');
      },
      description: 'Honorific or polite expressions'
    },
    {
      name: 'humble',
      level: 'N2',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.surface.endsWith('させていただく') || 
               t.surface.includes('申し上げ');
      },
      description: 'Humble expressions'
    },
    {
      name: 'causative-passive',
      level: 'N2',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.surface.endsWith('させられる');
      },
      description: 'Being made to do something'
    },
    {
      name: 'imperative',
      level: 'N3',
      pattern: (tokens, i) => {
        const t = tokens[i];
        return t.conjugation === 'imperative' || 
               t.surface.endsWith('なさい') ||
               t.surface.endsWith('ください');
      },
      description: 'Commands or requests'
    },
    {
      name: 'benefactive',
      level: 'N3',
      pattern: (tokens, i) => {
        if (i >= tokens.length - 1) return false;
        const t = tokens[i];
        const next = tokens[i + 1];
        return t.surface.endsWith('て') && 
               (next.basic === 'あげる' || 
                next.basic === 'くれる' || 
                next.basic === 'もらう');
      },
      description: 'Giving/receiving actions'
    }
  ];

  constructor() {
    this.initialize();
  }

  async addCustomDictionaryEntry(entry: CustomDictionaryEntry) {
    this.customDictionary.set(entry.word, {
      surface: entry.word,
      reading: entry.reading,
      basic: entry.basic,
      pos: entry.pos,
      pos_detail: entry.pos_detail,
      definitions: entry.definitions,
      tags: entry.tags,
      frequency: entry.frequency,
    });
  }

  async addCustomDictionaryEntries(entries: CustomDictionaryEntry[]) {
    for (const entry of entries) {
      await this.addCustomDictionaryEntry(entry);
    }
  }

  async addUserDefinedPattern(pattern: UserDefinedPattern) {
    this.userPatterns.push(pattern);
    // Sort patterns by priority (higher numbers first)
    this.userPatterns.sort((a, b) => (b.priority || 0) - (a.priority || 0));
  }

  async removeUserDefinedPattern(name: string) {
    this.userPatterns = this.userPatterns.filter(p => p.name !== name);
  }

  async clearCustomDictionary() {
    this.customDictionary.clear();
  }

  private async initialize(): Promise<void> {
    if (this.tokenizer || this.initializing) {
      return this.initPromise!;
    }

    this.initializing = true;
    this.initPromise = new Promise((resolve, reject) => {
      kuromoji.builder({ dicPath: '/dict' }).build((err, tokenizer) => {
        if (err) {
          console.error('Tokenizer initialization failed:', err);
          this.initializing = false;
          reject(err);
          return;
        }

        this.tokenizer = tokenizer;
        this.initializing = false;
        resolve();
      });
    });

    return this.initPromise;
  }

  async tokenize(text: string): Promise<TokenizedWord[]> {
    await this.initialize();

    if (!this.tokenizer) {
      throw new Error('Tokenizer not initialized');
    }

    // Check custom dictionary first
    const customTokens: TokenizedWord[] = [];
    let remainingText = text;

    this.customDictionary.forEach((value, key) => {
      if (remainingText.includes(key)) {
        customTokens.push(value);
        remainingText = remainingText.replace(key, ' '.repeat(key.length));
      }
    });

    // Tokenize remaining text
    const kuromojiTokens = this.tokenizer.tokenize(remainingText).map((token: any) => ({
      surface: token.surface_form,
      reading: token.reading,
      basic: token.basic_form,
      pos: token.pos,
      pos_detail: [token.pos_detail_1, token.pos_detail_2, token.pos_detail_3].filter(Boolean),
      pronunciation: token.pronunciation,
      conjugation: token.conjugation,
      conjugation_type: token.conjugation_type
    }));

    // Merge and sort tokens by their position in the original text
    return [...customTokens, ...kuromojiTokens].sort((a, b) => 
      text.indexOf(a.surface) - text.indexOf(b.surface)
    );
  }

  async findWords(text: string): Promise<TokenizedWord[]> {
    const tokens = await this.tokenize(text);
    
    // Filter out particles, auxiliary verbs, and punctuation
    return this.filterTokens(tokens);
  }

  async getReadings(text: string): Promise<string[]> {
    const tokens = await this.tokenize(text);
    return tokens.map(token => token.reading || token.surface);
  }

  async getDictionaryForms(text: string): Promise<string[]> {
    const tokens = await this.tokenize(text);
    return tokens.map(token => token.basic || token.surface);
  }

  async analyzeComplexity(text: string): Promise<ComplexityAnalysis> {
    const tokens = await this.findWords(text);
    const allTokens = await this.tokenize(text); // Include particles for full analysis
    
    // Basic metrics
    const uniqueWords = new Set(tokens.map(t => t.basic)).size;
    const avgWordLength = tokens.reduce((sum, t) => sum + t.surface.length, 0) / tokens.length;

    // Grammar analysis
    const grammarPoints = this.identifyGrammarPoints(tokens);
    const readingComplexity = this.calculateReadingComplexity(tokens);
    const grammarComplexity = this.calculateGrammarComplexity(grammarPoints);
    
    // Advanced metrics
    const detailedMetrics = this.calculateDetailedMetrics(allTokens, text);
    
    // Vocabulary level considering all metrics
    const vocabularyLevel = this.estimateVocabularyLevel(tokens, detailedMetrics);
    
    // Final JLPT level estimation
    const jlptLevel = this.estimateJLPTLevel(
      tokens,
      grammarPoints,
      readingComplexity,
      detailedMetrics
    );

    return {
      uniqueWords,
      avgWordLength,
      grammarPoints: grammarPoints.map(g => ({
        name: g.name,
        level: g.level,
        description: g.description
      })),
      jlptLevel,
      readingComplexity,
      grammarComplexity,
      vocabularyLevel,
      kanjiDensity: detailedMetrics.kanjiDensity,
      uniqueKanji: detailedMetrics.uniqueKanji,
      conjugationTypes: detailedMetrics.conjugationTypes,
      honorificLevel: this.determineHonorificLevel(tokens),
      sentenceLength: allTokens.length,
      particleDensity: detailedMetrics.particleDensity,
      readingVariety: detailedMetrics.readingVariety
    };
  }

  private identifyGrammarPoints(tokens: TokenizedWord[]): GrammarPattern[] {
    const foundPatterns: GrammarPattern[] = [];
    
    // Check built-in patterns
    for (let i = 0; i < tokens.length; i++) {
      for (const pattern of this.grammarPatterns) {
        if (typeof pattern.pattern === 'function') {
          if (pattern.pattern(tokens, i)) {
            foundPatterns.push(pattern);
          }
        } else {
          if (pattern.pattern.test(tokens[i].surface)) {
            foundPatterns.push(pattern);
          }
        }
      }

      // Check user-defined patterns
      for (const pattern of this.userPatterns) {
        if (pattern.pattern(tokens, i)) {
          foundPatterns.push({
            name: pattern.name,
            level: pattern.level || 'N3',
            pattern: pattern.pattern,
            description: pattern.description
          });
        }
      }
    }
    
    return [...new Set(foundPatterns)];
  }

  private calculateReadingComplexity(tokens: TokenizedWord[]): number {
    let complexity = 0;
    const kanjiRegex = /[\u4E00-\u9FAF]/g;
    
    tokens.forEach(token => {
      // Count kanji characters
      const kanjiCount = (token.surface.match(kanjiRegex) || []).length;
      complexity += kanjiCount * 2;
      
      // Add complexity for long readings
      if (token.reading && token.reading.length > 3) {
        complexity += token.reading.length - 3;
      }
    });
    
    return Math.min(100, complexity);
  }

  private calculateGrammarComplexity(patterns: GrammarPattern[]): number {
    const levelWeights = {
      'N5': 1,
      'N4': 2,
      'N3': 3,
      'N2': 4,
      'N1': 5
    };
    
    return Math.min(100, patterns.reduce((sum, pattern) => 
      sum + (levelWeights[pattern.level as keyof typeof levelWeights] || 3) * 10, 
    0));
  }

  private calculateDetailedMetrics(tokens: TokenizedWord[], text: string): {
    kanjiDensity: number;
    uniqueKanji: number;
    conjugationTypes: string[];
    honorificLevel: number;
    sentenceLength: number;
    particleDensity: number;
    readingVariety: number;
  } {
    // Extract all kanji from text
    const kanjiRegex = /[\u4E00-\u9FAF]/g;
    const allKanji = text.match(kanjiRegex) || [];
    const uniqueKanjiSet = new Set(allKanji);
    
    // Calculate kanji density
    const kanjiDensity = (allKanji.length / text.length) * 100;
    
    // Analyze conjugations
    const conjugationTypes = this.analyzeConjugations(tokens);
    
    // Calculate honorific level
    const honorificLevel = tokens.reduce((level, t) => {
      if (t.surface.includes('ございます')) level += 3;
      else if (t.surface.endsWith('です') || t.surface.endsWith('ます')) level += 1;
      else if (t.surface.includes('お') || t.surface.includes('ご')) level += 1;
      return level;
    }, 0);
    
    // Calculate particle density
    const particles = tokens.filter(t => this.isParticle(t));
    const particleDensity = (particles.length / tokens.length) * 100;
    
    // Calculate reading variety
    const readings = tokens
      .filter(t => t.reading)
      .map(t => t.reading);
    const uniqueReadings = new Set(readings);
    const readingVariety = (uniqueReadings.size / readings.length) * 100;
    
    return {
      kanjiDensity,
      uniqueKanji: uniqueKanjiSet.size,
      conjugationTypes,
      honorificLevel,
      sentenceLength: tokens.length,
      particleDensity,
      readingVariety
    };
  }

  private estimateVocabularyLevel(
    tokens: TokenizedWord[],
    metrics: ReturnType<typeof this.calculateDetailedMetrics>
  ): string {
    let score = 0;
    
    // Word complexity (40%)
    const complexWords = tokens.filter(t => 
      t.pos === '動詞' || 
      t.pos === '形容詞' || 
      (t.surface.match(/[\u4E00-\u9FAF]/g) || []).length > 2
    ).length;
    score += (complexWords / tokens.length) * 40;
    
    // Kanji usage (30%)
    score += (metrics.kanjiDensity / 2) * 0.3;
    
    // Grammar variety (20%)
    score += (metrics.conjugationTypes.length * 5);
    
    // Formality (10%)
    score += metrics.honorificLevel * 2;
    
    if (score > 80) return 'Advanced';
    if (score > 60) return 'Upper Intermediate';
    if (score > 40) return 'Intermediate';
    if (score > 20) return 'Upper Beginner';
    return 'Beginner';
  }

  private estimateJLPTLevel(
    tokens: TokenizedWord[],
    grammarPatterns: GrammarPattern[],
    readingComplexity: number,
    metrics: ReturnType<typeof this.calculateDetailedMetrics>
  ): string {
    let score = 0;
    
    // Grammar complexity (25%)
    score += this.calculateGrammarComplexity(grammarPatterns) * 0.25;
    
    // Reading complexity (25%)
    score += readingComplexity * 0.25;
    
    // Vocabulary and kanji usage (25%)
    const vocabScore = Math.min(100, 
      (metrics.uniqueKanji * 2) +
      (metrics.conjugationTypes.length * 5) +
      (metrics.honorificLevel * 3)
    );
    score += vocabScore * 0.25;
    
    // Sentence structure complexity (25%)
    const structureScore = Math.min(100,
      (metrics.particleDensity * 0.5) +
      (metrics.sentenceLength * 2) +
      (metrics.readingVariety * 0.5)
    );
    score += structureScore * 0.25;
    
    // Map final score to JLPT levels
    if (score > 85) return 'N1';
    if (score > 70) return 'N2';
    if (score > 55) return 'N3';
    if (score > 40) return 'N4';
    return 'N5';
  }

  // Helper functions for pattern detection
  private isVerbOrAdjective(token: TokenizedWord): boolean {
    return token.pos === '動詞' || 
           token.pos === '形容詞' || 
           token.pos === '形容動詞';
  }

  private isParticle(token: TokenizedWord): boolean {
    return token.pos === '助詞';
  }

  private isAuxiliaryVerb(token: TokenizedWord): boolean {
    return token.pos === '助動詞';
  }

  private getConjugationLevel(pattern: GrammarPattern): number {
    const levelMap: { [key: string]: number } = {
      'N5': 1,
      'N4': 2,
      'N3': 3,
      'N2': 4,
      'N1': 5
    };
    return levelMap[pattern.level] || 0;
  }

  private determineHonorificLevel(tokens: TokenizedWord[]): string {
    const honorificWords = tokens.filter(t => 
      t.pos_detail?.includes('尊敬語') ||
      t.pos_detail?.includes('謙譲語')
    );
    
    if (honorificWords.length > 2) return 'formal';
    if (honorificWords.length > 0) return 'polite';
    return 'casual';
  }

  private filterTokens(tokens: TokenizedWord[]): TokenizedWord[] {
    return tokens.filter(token =>
      !['助詞', '助動詞', '記号'].includes(token.pos) &&
      token.surface.trim().length > 0
    );
  }

  private analyzeConjugations(tokens: TokenizedWord[]): string[] {
    const conjugationTypes = [...new Set(
      tokens
        .filter(t => t.conjugation)
        .map(t => t.conjugation!)
    )];
    return conjugationTypes;
  }
}

export const tokenizerService = new TokenizerService(); 