import axios from 'axios';
import { SearchResult } from '../types';

class ScraperService {
  private readonly JISHO_API = 'https://jisho.org/api/v1/search/words';
  private readonly EXAMPLES_API = 'https://tatoeba.org/eng/api/search';

  async search(query: string): Promise<SearchResult[]> {
    try {
      // Search Jisho API
      const response = await axios.get(`${this.JISHO_API}/${encodeURIComponent(query)}`);
      const words = response.data.data;

      // Transform and enrich the results
      const results = await Promise.all(words.map(async (word: any) => {
        const japanese = word.japanese[0];
        const senses = word.senses[0];
        
        // Get example sentences from Tatoeba
        const examples = await this.getExamples(japanese.word || japanese.reading);

        return {
          id: word.slug,
          word: japanese.word || japanese.reading,
          reading: japanese.reading,
          definitions: senses.english_definitions,
          pos: senses.parts_of_speech[0],
          frequency: this.calculateFrequency(word),
          examples
        };
      }));

      return results;
    } catch (error) {
      console.error('Scraping error:', error);
      throw new Error('Failed to fetch dictionary data');
    }
  }

  private async getExamples(word: string): Promise<{ japanese: string; english: string; }[]> {
    try {
      const response = await axios.get(this.EXAMPLES_API, {
        params: {
          query: word,
          from: 'jpn',
          to: 'eng',
          limit: 3
        }
      });

      return response.data.results.map((result: any) => ({
        japanese: result.source,
        english: result.target
      }));
    } catch (error) {
      console.error('Failed to fetch examples:', error);
      return [];
    }
  }

  private calculateFrequency(word: any): number {
    // This is a simplified frequency calculation
    // In a real app, you'd want to use actual frequency data
    const hasJlpt = word.jlpt.length > 0;
    const isCommon = word.is_common;
    const wanikaniLevel = word.wanikani_level;

    let frequency = 50; // Base frequency

    if (isCommon) frequency += 20;
    if (hasJlpt) frequency += 15;
    if (wanikaniLevel) frequency += Math.max(0, 15 - wanikaniLevel);

    return Math.min(100, frequency);
  }
}

export const scraperService = new ScraperService(); 