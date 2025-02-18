export interface IchiMoeResult {
  word: string;
  reading?: string;
  definitions: string[];
  pos?: string;
}

export async function analyzeText(text: string): Promise<IchiMoeResult[]> {
  try {
    // Encode text for URL
    const encodedText = encodeURIComponent(text);
    const response = await fetch(`https://ichi.moe/cl/qr/?q=${encodedText}&r=htr`);
    const html = await response.text();

    // Create a temporary div to parse the HTML
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');

    // Find all word containers
    const wordContainers = doc.querySelectorAll('.gloss-row');
    const results: IchiMoeResult[] = [];

    wordContainers.forEach((container) => {
      // Get the word and reading
      const wordElem = container.querySelector('.js-term-str');
      const readingElem = container.querySelector('.js-term-reading');
      const word = wordElem?.textContent?.trim() || '';
      const reading = readingElem?.textContent?.trim();

      // Get definitions
      const definitionElems = container.querySelectorAll('.gloss-content');
      const definitions: string[] = [];
      definitionElems.forEach((defElem) => {
        const def = defElem.textContent?.trim();
        if (def) definitions.push(def);
      });

      // Get part of speech
      const posElem = container.querySelector('.pos-desc');
      const pos = posElem?.textContent?.trim();

      if (word && definitions.length > 0) {
        results.push({
          word,
          reading,
          definitions,
          pos,
        });
      }
    });

    return results;
  } catch (error) {
    console.error('Failed to analyze text with ichi.moe:', error);
    throw error;
  }
} 