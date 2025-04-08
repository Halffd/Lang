import React, { useState, useCallback, Suspense } from 'react';
import {
  Box,
  VStack,
  HStack,
  Text,
  Spinner,
  useColorModeValue,
  IconButton,
  Tooltip,
  Center,
  Button,
} from 'native-base';
import { ViewStyle } from 'react-native';
import { Icon } from '../components/CustomIcon';
import { useTokenizerContext } from '../context/TokenizerContext';
import { useSearch } from '../hooks/useSearch';
import { useApp } from '../context/AppContext';
import type { TokenizedWord } from '../types';
import styles from './SearchPage.module.scss';
import SearchBar from '../components/SearchBar';
import SearchResults from '../components/SearchResults';
import { useIchiMoeScraper } from '../hooks/useIchiMoeScraper';
import { useLocalStorage } from '../hooks/useLocalStorage';
import { Translator } from '../components/Translator/Translator';

// Lazy loaded components
const ResultDetails = React.lazy(() => import('../components/ResultDetails'));

export const SearchPage: React.FC = () => {
  const [query, setQuery] = useState('');
  const [selectedResult, setSelectedResult] = useState<TokenizedWord | null>(null);
  const { analyze, isAnalyzing: loading } = useIchiMoeScraper();
  const [history, setHistory] = useLocalStorage<string[]>('searchHistory', []);
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<TokenizedWord[]>([]);
  const [showTranslator, setShowTranslator] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState<number | undefined>();

  const { tokenize } = useTokenizerContext();
  const { searchMode, setSearchMode } = useSearch();
  const { results: searchResults, error: searchError } = useSearch();

  const bgColor = useColorModeValue('gray.50', 'gray.900');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.600', 'gray.400');
  const buttonBgColor = useColorModeValue('white', 'gray.800');
  const activeButtonBgColor = useColorModeValue('gray.100', 'gray.700');

  const addToHistory = useCallback((searchQuery: string) => {
    setHistory(prev => {
      const newHistory = [searchQuery, ...prev.filter(item => item !== searchQuery)];
      return newHistory.slice(0, 10); // Keep only last 10 items
    });
  }, [setHistory]);

  const clearHistory = useCallback(() => {
    setHistory([]);
  }, [setHistory]);

  const handleSearch = useCallback(async (searchQuery: string) => {
    setQuery(searchQuery);
    if (!searchQuery.trim()) {
      setResults([]);
      setError(null);
      return;
    }

    try {
      const searchResults = await analyze(searchQuery);
      setResults(searchResults);
      setError(null);
      addToHistory(searchQuery);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
      setResults([]);
    }
  }, [analyze, addToHistory]);

  const toggleSearchMode = useCallback(() => {
    setSearchMode(prev => prev === 'db' ? 'scrape' : 'db');
  }, [setSearchMode]);

  const handleWordSelect = useCallback((index: number) => {
    setSelectedIndex(index);
    setSelectedResult(results[index] || null);
  }, [results]);

  return (
    <Box
      flex={1}
      bg={bgColor}
      _web={{ style: styles['container'] as unknown as ViewStyle }}
    >
      <VStack
        space={6}
        flex={1}
        p={4}
      >
        <HStack space={4} mb={4}>
          <Button
            flex={1}
            variant="solid"
            bg={!showTranslator ? activeButtonBgColor : buttonBgColor}
            _hover={{ bg: activeButtonBgColor }}
            onPress={() => setShowTranslator(false)}
            _text={{ color: textColor }}
          >
            Dictionary Search
          </Button>
          <Button
            flex={1}
            variant="solid"
            bg={showTranslator ? activeButtonBgColor : buttonBgColor}
            _hover={{ bg: activeButtonBgColor }}
            onPress={() => setShowTranslator(true)}
            _text={{ color: textColor }}
          >
            Translator
          </Button>
        </HStack>

        {!showTranslator ? (
          <VStack space={4}>
            <HStack space={4} alignItems="center">
              <Box flex={1}>
                <Suspense fallback={<Spinner size="sm" />}>
                  <SearchBar
                    query={query}
                    onSearch={handleSearch}
                    searchHistory={history}
                    onClearHistory={clearHistory}
                    onHistoryItemClick={handleSearch}
                  />
                </Suspense>
              </Box>
              <Tooltip label={`Switch to ${searchMode === 'db' ? 'web scraping' : 'database'} mode`}>
                <IconButton
                  icon={<Box>{searchMode === 'db' ? '🔍' : '🌐'}</Box>}
                  variant="ghost"
                  aria-label="Toggle search mode"
                  onPress={toggleSearchMode}
                  _web={{ style: styles['modeToggle'] as unknown as ViewStyle }}
                />
              </Tooltip>
            </HStack>

            <Box
              flex={1}
              borderWidth={1}
              borderColor={borderColor}
              borderRadius="lg"
              overflow="hidden"
              _web={{ style: styles['resultsContainer'] as unknown as ViewStyle }}
            >
              <HStack height="100%" space={0} alignItems="stretch">
                <Box
                  flex={1}
                  borderRightWidth={1}
                  borderColor={borderColor}
                  _web={{ style: styles['resultsList'] as unknown as ViewStyle }}
                >
                  <Suspense fallback={<Spinner size="lg" />}>
                    <SearchResults
                      results={results}
                      isLoading={loading}
                      error={error || undefined}
                      onWordSelect={handleWordSelect}
                      selectedWordIndex={selectedIndex}
                    />
                  </Suspense>
                </Box>

                {selectedResult && (
                  <Box
                    width="400px"
                    p={4}
                    _web={{ style: styles['detailsPanel'] as unknown as ViewStyle }}
                  >
                    <Suspense fallback={<Spinner size="sm" />}>
                      <ResultDetails result={selectedResult} />
                    </Suspense>
                  </Box>
                )}
              </HStack>
            </Box>
          </VStack>
        ) : (
          <Box flex={1}>
            <Suspense fallback={<Spinner size="lg" />}>
              <Translator />
            </Suspense>
          </Box>
        )}
      </VStack>
    </Box>
  );
};

export default SearchPage;