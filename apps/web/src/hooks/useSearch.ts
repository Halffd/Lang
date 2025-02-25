import { useState } from 'react';

// Define the result type
export interface SearchResult {
  id: string;
  word: string;
  reading: string;
  meaning: string;
}

export const useSearch = () => {
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const search = async (query: string) => {
    if (!query.trim()) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      // Simulate API call with timeout
      await new Promise(resolve => setTimeout(resolve, 1000));

      // Mock results - in a real app, this would be an API call
      const mockResults: SearchResult[] = [
        { id: '1', word: '猫', reading: 'ねこ', meaning: 'cat' },
        { id: '2', word: '犬', reading: 'いぬ', meaning: 'dog' },
        { id: '3', word: '鳥', reading: 'とり', meaning: 'bird' },
      ].filter(item => 
        item.word.includes(query) || 
        item.reading.includes(query) || 
        item.meaning.includes(query)
      );

      setResults(mockResults);
    } catch (err) {
      setError('An error occurred while searching. Please try again.');
      console.error('Search error:', err);
    } finally {
      setLoading(false);
    }
  };

  return {
    results,
    loading,
    error,
    search,
  };
}; 