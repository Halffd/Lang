import React, { useState, useCallback } from 'react';
import {
  Box,
  Container,
  Paper,
  Tabs,
  Tab,
  TextField,
  IconButton,
  Typography,
  useTheme,
  ThemeProvider,
  createTheme,
  CssBaseline,
} from '@mui/material';
import SearchIcon from '@mui/icons-material/Search';
import TranslateIcon from '@mui/icons-material/Translate';
import { useApp } from '../context/AppContext';
import SearchBar from '../components/SearchBar';
import SearchResults from '../components/SearchResults';
import { Translator } from '../components/Translator/Translator';
import type { TokenizedWord } from '../types';
import { IchiMoeService } from '../services/IchiMoeService';
import { TranslationService } from '../services/TranslationService';

const theme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: '#2196f3', // Blue
      dark: '#1976d2', // Dark Blue
    },
    secondary: {
      main: '#9c27b0', // Purple
      dark: '#7b1fa2', // Dark Purple
    },
    background: {
      default: '#121212',
      paper: '#1e1e1e',
    },
  },
  components: {
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
        },
      },
    },
  },
});

export const SearchPage: React.FC = () => {
  const [query, setQuery] = useState('');
  const [selectedResult, setSelectedResult] = useState<TokenizedWord | null>(null);
  const [activeTab, setActiveTab] = useState(0);
  const { history, addToHistory, clearHistory } = useApp();
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<TokenizedWord[]>([]);
  const [selectedIndex, setSelectedIndex] = useState<number | undefined>();
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    setActiveTab(newValue);
  };

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
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Paper elevation={3} sx={{ p: 3, mb: 3 }}>
          <Tabs
            value={activeTab}
            onChange={handleTabChange}
            indicatorColor="primary"
            textColor="primary"
            centered
            sx={{ mb: 3 }}
          >
            <Tab 
              icon={<SearchIcon />} 
              label="Dictionary Search" 
              sx={{ 
                color: activeTab === 0 ? 'primary.main' : 'text.secondary',
                '&.Mui-selected': { color: 'primary.main' }
              }}
            />
            <Tab 
              icon={<TranslateIcon />} 
              label="Translator" 
              sx={{ 
                color: activeTab === 1 ? 'primary.main' : 'text.secondary',
                '&.Mui-selected': { color: 'primary.main' }
              }}
            />
          </Tabs>

          {activeTab === 0 ? (
            <Box>
              <SearchBar
                query={query}
                onSearch={handleSearch}
                searchHistory={history}
                onClearHistory={clearHistory}
                onHistoryItemClick={handleSearch}
              />
              <Box sx={{ mt: 3 }}>
                <SearchResults
                  results={results}
                  isLoading={isAnalyzing}
                  error={error || undefined}
                  onWordSelect={handleWordSelect}
                  selectedWordIndex={selectedIndex}
                />
              </Box>
            </Box>
          ) : (
            <Box sx={{ mt: 2 }}>
              <Translator onTranslate={handleTranslate} />
            </Box>
          )}
        </Paper>
      </Container>
    </ThemeProvider>
  );
};

export default SearchPage;