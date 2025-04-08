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
  private static readonly API_URL = 'https://ichi.moe/cl/qr/';
  private static readonly ROMA_MODE = 'hb';

  private isJapanese(text: string): boolean {
    return /[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]/.test(text);
  }

  private async fetchIchiMoe(query: string): Promise<string> {
    const url = `${IchiMoeService.API_URL}?r=${IchiMoeService.ROMA_MODE}&q=${encodeURIComponent(query)}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Ichi.moe API request failed: ${response.status}`);
    }
    return await response.text();
  }

  private parseIchiMoeResponse(html: string): IchiMoeResult[] {
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const glossElements = doc.querySelectorAll('div.gloss-content.scroll-pane > dl');
    
    return Array.from(glossElements)
      .filter(element => element.innerHTML.trim() !== '')
      .map(element => {
        const dt = element.querySelector('dt');
        const dd = element.querySelector('dd');
        const senseInfo = element.querySelector('.sense-info-note.has-tip');
        const conjVia = element.querySelector('.conj-via');
        const compounds = element.querySelector('.compounds');
        const conjGloss = element.querySelector('.conj-gloss');
        
        if (!dt || !dd) {
          throw new Error('Invalid Ichi.moe response format');
        }

        const ttt = dt.innerHTML.split(' ');
        const surface = parseInt(ttt[0].substring(0, 1)) >= 0 && ttt.length > 1 ? ttt[1] : ttt[0];
        
        const definitions = Array.from(dd.querySelectorAll('li'))
          .map(li => li.innerHTML.trim())
          .filter(text => text.length > 0);

        return {
          surface,
          reading: surface, // Default to surface if no reading available
          basic: surface, // Default to surface if no basic form available
          pos: 'unknown', // Would need to parse from senseInfo
          pos_detail: [],
          definitions,
          translations: definitions, // Using definitions as translations for now
          frequency: Math.random() * 100, // Mock frequency
        };
      });
  }

  public async analyzeText(text: string): Promise<TokenizedWord[]> {
    if (!this.isJapanese(text)) {
      throw new Error('Text must contain Japanese characters');
    }

    // Clean the text
    const cleanedText = text.replace(/[&/\\#,+()$~%.'":*?<>{}]/g, '');

    try {
      const html = await this.fetchIchiMoe(cleanedText);
      const results = this.parseIchiMoeResponse(html);
      
      return results.map(result => ({
        surface: result.surface,
        reading: result.reading || result.surface,
        basic: result.basic || result.surface,
        pos: result.pos,
        pos_detail: result.pos_detail,
        definitions: result.definitions,
        translations: result.translations,
        frequency: result.frequency || Math.random() * 100,
      }));
    } catch (error) {
      console.error('Ichi.moe analysis error:', error);
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