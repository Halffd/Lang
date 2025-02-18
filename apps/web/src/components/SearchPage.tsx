import React, { useState, useEffect, useCallback } from 'react';
import { StyleSheet, View, TextInput, TouchableOpacity, Text, Platform } from 'react-native';
import { SearchResults } from './SearchResults';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
}

export function SearchPage() {
  const [inputText, setInputText] = useState('');
  const [results, setResults] = useState<TokenizedWord[]>([]);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [searchHistory, setSearchHistory] = useState<string[]>([]);
  const [showHistory, setShowHistory] = useState(false);

  // Load search history on mount
  useEffect(() => {
    const loadHistory = async () => {
      try {
        // In a real app, we would use AsyncStorage here
        const history = localStorage.getItem('searchHistory');
        if (history) {
          setSearchHistory(JSON.parse(history));
        }
      } catch (error) {
        console.error('Failed to load search history:', error);
      }
    };

    loadHistory();
  }, []);

  // Save search history when it changes
  useEffect(() => {
    try {
      localStorage.setItem('searchHistory', JSON.stringify(searchHistory));
    } catch (error) {
      console.error('Failed to save search history:', error);
    }
  }, [searchHistory]);

  const handleInputChange = useCallback((text: string) => {
    setInputText(text);
    setShowHistory(text.length > 0);
  }, []);

  const handleSearch = useCallback(async (text: string) => {
    setIsAnalyzing(true);
    setShowHistory(false);

    try {
      // Mock tokenization for now
      const mockResults: TokenizedWord[] = text.split(/\s+/).map(word => ({
        word,
        reading: word,
        definitions: [`Definition for ${word}`],
        translations: [`Translation for ${word}`],
        pos: 'noun',
        frequency: Math.random() * 100,
      }));

      // Simulate API delay
      await new Promise(resolve => setTimeout(resolve, 500));

      setResults(mockResults);
      
      // Update search history
      if (text.trim()) {
        setSearchHistory(prev => {
          const newHistory = [text, ...prev.filter(item => item !== text)].slice(0, 10);
          return newHistory;
        });
      }
    } catch (error) {
      console.error('Analysis failed:', error);
      setResults([]);
    } finally {
      setIsAnalyzing(false);
    }
  }, []);

  const handleHistorySelect = useCallback((text: string) => {
    setInputText(text);
    setShowHistory(false);
    handleSearch(text);
  }, [handleSearch]);

  return (
    <View style={styles.container}>
      <View style={styles.searchContainer}>
        <TextInput
          style={styles.input}
          value={inputText}
          onChangeText={handleInputChange}
          placeholder="Enter text to analyze..."
          placeholderTextColor="#999"
          onSubmitEditing={() => handleSearch(inputText)}
        />
        <TouchableOpacity
          style={styles.searchButton}
          onPress={() => handleSearch(inputText)}
        >
          <Text style={styles.buttonText}>Search</Text>
        </TouchableOpacity>
      </View>

      {showHistory && searchHistory.length > 0 && (
        <View style={styles.historyContainer}>
          {searchHistory.map((item, index) => (
            <TouchableOpacity
              key={index}
              style={styles.historyItem}
              onPress={() => handleHistorySelect(item)}
            >
              <Text style={styles.historyText}>{item}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}

      <View style={styles.resultsContainer}>
        <SearchResults
          results={results}
          isLoading={isAnalyzing}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  searchContainer: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  input: {
    flex: 1,
    height: 44,
    paddingHorizontal: 16,
    backgroundColor: '#f5f5f5',
    borderRadius: 8,
    fontSize: 16,
    color: '#333',
    ...(Platform.OS === 'web' ? { outlineStyle: 'none' } : {}),
  },
  searchButton: {
    backgroundColor: '#2196f3',
    paddingHorizontal: 24,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  historyContainer: {
    position: 'absolute',
    top: 76,
    left: 16,
    right: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
    zIndex: 1000,
  },
  historyItem: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 4,
  },
  historyText: {
    fontSize: 16,
    color: '#333',
  },
  resultsContainer: {
    flex: 1,
  },
}); 