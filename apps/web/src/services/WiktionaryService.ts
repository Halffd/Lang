import { TokenizedWord } from '../types';
import { toast } from 'react-hot-toast';

interface WiktionaryResponse {
  html: string;
  etymology: string;
  definitions: string[];
  examples: string[];
}

interface KanjipediaResponse {
  origin: string;
  meaning: string;
  usage: string;
}

interface IchiMoeResponse {
  surface: string;
  reading: string;
  basic: string;
  pos: string;
  pos_detail: string[];
  definitions: string[];
  translations?: string[];
}

export class WiktionaryService {
  private static readonly WIKTIONARY_BASE_URL = 'https://en.wiktionary.org/wiki/';
  private static readonly KANJIPEDIA_BASE_URL = 'https://www.kanjipedia.jp/search?kt=1&sk=leftHand&k=';
  private static readonly ICHI_MOE_BASE_URL = 'https://ichi.moe/cl/qr/?q=';

  private async fetchWithTimeout(url: string, options: RequestInit = {}, timeout = 10000): Promise<Response> {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), timeout);
    
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal
      });
      clearTimeout(id);
      return response;
    } catch (error) {
      clearTimeout(id);
      throw error;
    }
  }

  private async fetchWiktionary(word: string): Promise<string> {
    try {
      const response = await this.fetchWithTimeout(
        `${WiktionaryService.WIKTIONARY_BASE_URL}${encodeURIComponent(word)}`,
        {
          headers: { 'Content-Type': 'text/html; charset=UTF-8' }
        }
      );
      
      if (!response.ok) {
        throw new Error(`Wiktionary request failed with status ${response.status}`);
      }
      
      return await response.text();
    } catch (error) {
      console.error('Error fetching from Wiktionary:', error);
      toast.error('Failed to fetch from Wiktionary');
      throw error;
    }
  }

  private async fetchKanjipedia(kanji: string): Promise<string> {
    try {
      const response = await this.fetchWithTimeout(
        `${WiktionaryService.KANJIPEDIA_BASE_URL}${encodeURIComponent(kanji)}`
      );
      
      if (!response.ok) {
        throw new Error(`Kanjipedia request failed with status ${response.status}`);
      }
      
      return await response.text();
    } catch (error) {
      console.error('Error fetching from Kanjipedia:', error);
      toast.error('Failed to fetch from Kanjipedia');
      throw error;
    }
  }

  private async fetchIchiMoe(word: string): Promise<IchiMoeResponse[]> {
    try {
      const response = await this.fetchWithTimeout(
        `${WiktionaryService.ICHI_MOE_BASE_URL}${encodeURIComponent(word)}`,
        {
          headers: { 'Content-Type': 'application/json' }
        }
      );
      
      if (!response.ok) {
        throw new Error(`Ichi.moe request failed with status ${response.status}`);
      }
      
      const data = await response.json();
      return data.items || [];
    } catch (error) {
      console.error('Error fetching from Ichi.moe:', error);
      toast.error('Failed to fetch from Ichi.moe');
      throw error;
    }
  }

  private parseWiktionaryResponse(html: string): WiktionaryResponse {
    try {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      
      const etymology = doc.querySelector('#Etymology')?.parentElement?.nextElementSibling?.textContent || '';
      const definitions: string[] = [];
      const examples: string[] = [];

      // Find Japanese section
      const japaneseSection = Array.from(doc.querySelectorAll('h2')).find(h2 => 
        h2.textContent?.includes('Japanese')
      );

      if (japaneseSection) {
        let currentElement = japaneseSection.nextElementSibling;
        while (currentElement && currentElement.tagName !== 'H2') {
          if (currentElement.tagName === 'OL') {
            const items = currentElement.querySelectorAll('li');
            items.forEach(item => {
              const text = item.textContent?.trim();
              if (text) {
                if (text.includes('Example:')) {
                  examples.push(text.replace('Example:', '').trim());
                } else {
                  definitions.push(text);
                }
              }
            });
          }
          currentElement = currentElement.nextElementSibling;
        }
      }

      return {
        html,
        etymology,
        definitions,
        examples
      };
    } catch (error) {
      console.error('Error parsing Wiktionary response:', error);
      toast.error('Failed to parse Wiktionary data');
      throw error;
    }
  }

  private parseKanjipediaResponse(html: string): KanjipediaResponse {
    try {
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');

      const origin = doc.querySelector('#kanjiRightSection > ul > li.naritachi > div:nth-child(2) > p')?.textContent || '';
      const meaning = doc.querySelector('#kanjiRightSection > ul > li:nth-child(1) > div > p')?.textContent || '';
      const usage = doc.querySelector('#kanjiRightSection > ul > li:nth-child(2) > div > p')?.textContent || '';

      return {
        origin,
        meaning,
        usage
      };
    } catch (error) {
      console.error('Error parsing Kanjipedia response:', error);
      toast.error('Failed to parse Kanjipedia data');
      throw error;
    }
  }

  private isChinese(text: string): boolean {
    return /[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff]/.test(text);
  }

  public async getWordInfo(word: string): Promise<{
    ichiMoe?: IchiMoeResponse[];
    wiktionary?: WiktionaryResponse;
    kanjipedia?: KanjipediaResponse;
  }> {
    try {
      const [ichiMoeData, wiktionaryHtml, kanjipediaHtml] = await Promise.all([
        this.fetchIchiMoe(word).catch(() => undefined),
        this.fetchWiktionary(word).catch(() => undefined),
        this.isChinese(word) ? this.fetchKanjipedia(word).catch(() => undefined) : Promise.resolve(undefined)
      ]);

      const wiktionaryData = wiktionaryHtml ? this.parseWiktionaryResponse(wiktionaryHtml) : undefined;
      const kanjipediaData = kanjipediaHtml ? this.parseKanjipediaResponse(kanjipediaHtml) : undefined;

      return {
        ichiMoe: ichiMoeData,
        wiktionary: wiktionaryData,
        kanjipedia: kanjipediaData
      };
    } catch (error) {
      console.error('Error getting word info:', error);
      toast.error('Failed to get word information');
      throw error;
    }
  }

  public async enhanceTokenizedWord(word: TokenizedWord): Promise<TokenizedWord> {
    try {
      const info = await this.getWordInfo(word.surface);
      
      const enhancedWord: TokenizedWord = {
        ...word,
        definitions: [...word.definitions],
        examples: [...(word.examples || [])]
      };

      // Add Ichi.moe data if available
      if (info.ichiMoe?.length) {
        const ichiMoeData = info.ichiMoe[0];
        enhancedWord.definitions = [...enhancedWord.definitions, ...ichiMoeData.definitions];
        if (ichiMoeData.translations) {
          enhancedWord.translations = [...(enhancedWord.translations || []), ...ichiMoeData.translations];
        }
      }

      // Add Wiktionary data if available
      if (info.wiktionary) {
        enhancedWord.etymology = info.wiktionary.etymology;
        enhancedWord.definitions = [...enhancedWord.definitions, ...info.wiktionary.definitions];
        enhancedWord.examples = [...enhancedWord.examples, ...info.wiktionary.examples];
      }

      // Add Kanjipedia data if available
      if (info.kanjipedia) {
        enhancedWord.additionalInfo = {
          kanjiInfo: {
            meaning: info.kanjipedia.meaning,
            usage: info.kanjipedia.usage
          }
        };
      }

      return enhancedWord;
    } catch (error) {
      console.error('Error enhancing tokenized word:', error);
      toast.error('Failed to enhance word data');
      return word;
    }
  }
}

export const wiktionaryService = new WiktionaryService(); 