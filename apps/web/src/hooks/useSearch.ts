import { useState, useCallback } from 'react';
import { SearchResult } from '../types';
import { databaseService } from '../services/DatabaseService';
import { scraperService } from '../services/ScraperService';

export type SearchMode = 'db' | 'scrape';

export function useSearch() {
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [searchMode, setSearchMode] = useState<SearchMode>('db');

  const search = useCallback(async (query: string) => {
    if (!query.trim()) {
      return;
    }

    setLoading(true);
    setError(null);
    setResults([]);

    try {
      let searchResults: SearchResult[];

      if (searchMode === 'db') {
        // Search in local database
        searchResults = await databaseService.search(query);
        
        // If no results in DB, try scraping
        if (searchResults.length === 0) {
          searchResults = await scraperService.search(query);
          
          // Save new results to database
          await Promise.all(searchResults.map(result => 
            databaseService.addWord(result)
          ));
        }
      } else {
        // Direct web scraping
        searchResults = await scraperService.search(query);
        
        // Save results to database in background
        searchResults.forEach(result => 
          databaseService.addWord(result).catch(console.error)
        );
      }

      setResults(searchResults);
    } catch (err) {
      console.error('Search error:', err);
      setError(err instanceof Error ? err.message : 'An error occurred while searching');
    } finally {
      setLoading(false);
    }
  }, [searchMode]);

  return {
    results,
    loading,
    error,
    search,
    searchMode,
    setSearchMode
  };
} 