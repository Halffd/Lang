import { TranslationMode } from '../components/Translator/Translator';

export class TranslationService {
  private static delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  static async translate(
    text: string,
    sourceLang: string,
    targetLang: string,
    mode: TranslationMode
  ): Promise<string> {
    // Simulate API latency
    await this.delay(500);

    switch (mode) {
      case 'per-word':
        return this.translatePerWord(text, sourceLang, targetLang);
      case 'dictionary':
        return this.translateDictionary(text, sourceLang, targetLang);
      case 'scraping':
        return this.translateScraping(text, sourceLang, targetLang);
      default:
        throw new Error(`Unsupported translation mode: ${mode}`);
    }
  }

  private static async translatePerWord(
    text: string,
    sourceLang: string,
    targetLang: string
  ): Promise<string> {
    // Split text into words and translate each word
    const words = text.split(/\s+/);
    const translatedWords = await Promise.all(
      words.map(async (word) => {
        // Simulate per-word translation
        await this.delay(100);
        return `${word} (${this.getMockTranslation(word, sourceLang, targetLang)})`;
      })
    );
    return translatedWords.join(' ');
  }

  private static async translateDictionary(
    text: string,
    sourceLang: string,
    targetLang: string
  ): Promise<string> {
    // Simulate dictionary lookup
    await this.delay(300);
    return `Dictionary Entry:\n${text}\n\nTranslation: ${this.getMockTranslation(text, sourceLang, targetLang)}\n\nExample: ${this.getMockExample(text)}`;
  }

  private static async translateScraping(
    text: string,
    sourceLang: string,
    targetLang: string
  ): Promise<string> {
    // Check if text is a URL
    const isUrl = /^https?:\/\/\S+$/.test(text);
    
    if (isUrl) {
      // Simulate web scraping
      await this.delay(1000);
      return `Scraped Content from ${text}:\n\n${this.getMockScrapedContent()}\n\nTranslation: ${this.getMockTranslation(this.getMockScrapedContent(), sourceLang, targetLang)}`;
    } else {
      // Treat as regular text
      await this.delay(500);
      return `Scraped Text:\n${text}\n\nTranslation: ${this.getMockTranslation(text, sourceLang, targetLang)}`;
    }
  }

  private static getMockTranslation(text: string, sourceLang: string, targetLang: string): string {
    // Mock translation based on language pair
    const translations: Record<string, Record<string, string>> = {
      'en-ja': {
        'hello': 'こんにちは',
        'world': '世界',
        'translate': '翻訳',
        'dictionary': '辞書',
        'scraping': 'スクレイピング',
      },
      'ja-en': {
        'こんにちは': 'hello',
        '世界': 'world',
        '翻訳': 'translate',
        '辞書': 'dictionary',
        'スクレイピング': 'scraping',
      },
    };

    const key = `${sourceLang}-${targetLang}`;
    return translations[key]?.[text.toLowerCase()] || `[${text}]`;
  }

  private static getMockExample(word: string): string {
    const examples: Record<string, string> = {
      'hello': 'Hello, how are you today?',
      'world': 'The world is a beautiful place.',
      'translate': 'Can you translate this sentence?',
      'dictionary': 'I looked up the word in the dictionary.',
      'scraping': 'Web scraping is a useful technique for data collection.',
    };
    return examples[word.toLowerCase()] || `Example sentence for ${word}`;
  }

  private static getMockScrapedContent(): string {
    return `This is a sample of scraped content from a webpage. It includes multiple paragraphs and different types of content.

The content might include:
- Headers
- Lists
- Links
- Images
- And other HTML elements

This is just a mock example to demonstrate the scraping functionality.`;
  }

  static getAvailableLanguages(): { code: string; name: string }[] {
    return [
      { code: 'en', name: 'English' },
      { code: 'es', name: 'Spanish' },
      { code: 'fr', name: 'French' },
      { code: 'de', name: 'German' },
      { code: 'it', name: 'Italian' },
      { code: 'pt', name: 'Portuguese' },
      { code: 'ru', name: 'Russian' },
      { code: 'zh', name: 'Chinese' },
      { code: 'ja', name: 'Japanese' },
      { code: 'ko', name: 'Korean' },
    ];
  }
} 