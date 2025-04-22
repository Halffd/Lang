import React, { useState, useCallback } from 'react';
import {
  Box,
  HStack,
  Button,
  VStack,
  useColorModeValue,
  Icon,
  IconButton,
} from 'native-base';
import { MaterialIcons, Ionicons } from '@expo/vector-icons';
import { useApp } from '../context/AppContext';
import SearchBar from '../components/SearchBar';
import SearchResults from '../components/SearchResults';
import { Translator } from '../components/Translator';
import type { TokenizedWord } from '../types';
import { IchiMoeService } from '../services/IchiMoeService';
import { TranslationService } from '../services/TranslationService';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { RootStackParamList } from '../types/navigation';

type SearchPageNavigationProp = NativeStackNavigationProp<RootStackParamList, 'Search'>;

export const SearchPage: React.FC = () => {
  const [query, setQuery] = useState('');
  const [selectedResult, setSelectedResult] = useState<TokenizedWord | null>(null);
  const [showTranslator, setShowTranslator] = useState(false);
  const { history, addToHistory, clearHistory, settings } = useApp();
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<TokenizedWord[]>([]);
  const [selectedIndex, setSelectedIndex] = useState<number | undefined>();
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const navigation = useNavigation<SearchPageNavigationProp>();

  const activeButtonBgColor = useColorModeValue('primary.500', 'primary.700');
  const buttonBgColor = useColorModeValue('gray.100', 'gray.700');

  const handleSearch = useCallback(async (searchQuery: string) => {
    setQuery(searchQuery);
    if (!searchQuery.trim()) {
      setResults([]);
      setError(null);
      return;
    }

    setIsAnalyzing(true);
    setError(null);

    try {
      const ichiMoeService = new IchiMoeService();
      const analysis = await ichiMoeService.analyzeText(searchQuery);
      
      if (analysis && analysis.length > 0) {
        setResults(analysis);
        addToHistory(searchQuery);
      } else {
        setError('No results found');
        setResults([]);
      }
    } catch (err) {
      console.error('Search error:', err);
      setError(err instanceof Error ? err.message : 'An error occurred during search');
      setResults([]);
    } finally {
      setIsAnalyzing(false);
    }
  }, [addToHistory]);

  const handleWordSelect = useCallback((index: number) => {
    setSelectedIndex(index);
    setSelectedResult(results[index] || null);
  }, [results]);

  const handleTranslate = async (text: string, sourceLang: string, targetLang: string, mode: 'per-word' | 'dictionary' | 'scraping') => {
    try {
      return await TranslationService.translate(text, sourceLang, targetLang, mode);
    } catch (error) {
      console.error('Translation error:', error);
      throw error;
    }
  };

  return (
    <Box flex={1} safeArea>
      <VStack space={4} p={4}>
        <HStack space={2} justifyContent="center">
          <Button
            leftIcon={<Icon as={MaterialIcons} name="search" size="sm" />}
            variant={!showTranslator ? 'solid' : 'outline'}
            bg={!showTranslator ? activeButtonBgColor : buttonBgColor}
            onPress={() => setShowTranslator(false)}
          >
            Dictionary Search
          </Button>
          <Button
            leftIcon={<Icon as={MaterialIcons} name="translate" size="sm" />}
            variant={showTranslator ? 'solid' : 'outline'}
            bg={showTranslator ? activeButtonBgColor : buttonBgColor}
            onPress={() => setShowTranslator(true)}
          >
            Translator
          </Button>
        </HStack>

        {!showTranslator ? (
          <VStack space={4}>
            <SearchBar
              query={query}
              onSearch={handleSearch}
              searchHistory={history}
              onClearHistory={clearHistory}
              onHistoryItemClick={handleSearch}
              showFurigana={settings.showFurigana}
            />
            <SearchResults
              results={results}
              isLoading={isAnalyzing}
              error={error || undefined}
              onWordSelect={handleWordSelect}
              selectedWordIndex={selectedIndex}
              showFurigana={settings.showFurigana}
            />
          </VStack>
        ) : (
          <Box flex={1}>
            <Translator onTranslate={handleTranslate} />
          </Box>
        )}

        <IconButton
          icon={<Ionicons name="settings-outline" size={24} color="black" />}
          onPress={() => navigation.navigate('Settings')}
          style={{ marginTop: 10 }}
        />
      </VStack>
    </Box>
  );
};

export default SearchPage; 