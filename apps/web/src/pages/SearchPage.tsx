import React, { useState, useCallback, useEffect } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, Platform, ScrollView, Animated } from 'react-native';
import { SearchResults } from '../components/SearchResults';
import { useApp } from '../context/AppContext';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string; // Part of speech
  frequency?: number;
}

export default function SearchPage() {
  const [inputText, setInputText] = useState('');
  const [results, setResults] = useState<TokenizedWord[]>([]);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const [autoConvert, setAutoConvert] = useState(true);
  const [clipboardMonitor, setClipboardMonitor] = useState(false);

  // Animation values
  const fadeAnim = React.useRef(new Animated.Value(0)).current;
  const scaleAnim = React.useRef(new Animated.Value(0.9)).current;

  const { history, addToHistory } = useApp();

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
      Animated.timing(scaleAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const handleInputChange = useCallback((text: string) => {
    setInputText(text);
    setShowHistory(text.length > 0);
  }, []);

  const handleSearch = useCallback(async (text: string) => {
    if (!text.trim()) return;
    
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
      addToHistory(text);
    } catch (error) {
      console.error('Analysis failed:', error);
      setResults([]);
    } finally {
      setIsAnalyzing(false);
    }
  }, [addToHistory]);

  const handleHistorySelect = useCallback((text: string) => {
    setInputText(text);
    setShowHistory(false);
    handleSearch(text);
  }, [handleSearch]);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <Animated.View style={[
        styles.searchContainer,
        {
          opacity: fadeAnim,
          transform: [{ scale: scaleAnim }]
        }
      ]}>
        <View style={styles.searchHeader}>
          <View style={styles.optionsRow}>
            <TouchableOpacity
              style={[styles.optionButton, autoConvert && styles.optionButtonActive]}
              onPress={() => setAutoConvert(!autoConvert)}
            >
              <Text style={[styles.optionText, autoConvert && styles.optionTextActive]}>
                かな変換
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.optionButton, clipboardMonitor && styles.optionButtonActive]}
              onPress={() => setClipboardMonitor(!clipboardMonitor)}
            >
              <Text style={[styles.optionText, clipboardMonitor && styles.optionTextActive]}>
                クリップボード監視
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.inputContainer}>
            <TextInput
              style={styles.input}
              value={inputText}
              onChangeText={handleInputChange}
              placeholder="文章を入力してください..."
              placeholderTextColor="#666"
              multiline
              numberOfLines={Platform.OS === 'web' ? 3 : 1}
              onSubmitEditing={() => handleSearch(inputText)}
            />
          </View>

          <TouchableOpacity 
            style={[styles.analyzeButton, isAnalyzing && styles.analyzeButtonDisabled]}
            onPress={() => handleSearch(inputText)}
            disabled={isAnalyzing}
          >
            <Text style={styles.analyzeButtonText}>
              {isAnalyzing ? '解析中...' : '解析'}
            </Text>
          </TouchableOpacity>
        </View>

        {showHistory && history.length > 0 && (
          <View style={styles.historyContainer}>
            {history.map((item, index) => (
              <TouchableOpacity
                key={index}
                style={styles.historyItem}
                onPress={() => handleHistorySelect(item.text)}
              >
                <Text style={styles.historyText}>{item.text}</Text>
                <Text style={styles.historyTime}>
                  {new Date(item.timestamp).toLocaleTimeString()}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </Animated.View>

      <View style={styles.resultsContainer}>
        <SearchResults
          results={results}
          isLoading={isAnalyzing}
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f6fa',
  },
  contentContainer: {
    padding: 16,
  },
  searchContainer: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
  },
  searchHeader: {
    marginBottom: 16,
  },
  optionsRow: {
    flexDirection: 'row',
    marginBottom: 12,
    gap: 8,
  },
  optionButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    backgroundColor: '#f0f0f0',
  },
  optionButtonActive: {
    backgroundColor: '#4a90e2',
  },
  optionText: {
    fontSize: 14,
    color: '#666',
  },
  optionTextActive: {
    color: '#fff',
  },
  inputContainer: {
    position: 'relative',
  },
  input: {
    backgroundColor: '#f8f9fa',
    borderRadius: 12,
    padding: 16,
    fontSize: 16,
    borderWidth: 2,
    borderColor: '#e1e4e8',
    marginBottom: 12,
    minHeight: 100,
    textAlignVertical: 'top',
    ...Platform.select({
      web: {
        outlineStyle: 'none',
      },
    }),
  },
  analyzeButton: {
    backgroundColor: '#4a90e2',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
  },
  analyzeButtonDisabled: {
    backgroundColor: '#a0c4e8',
  },
  analyzeButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  historyContainer: {
    marginTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#e1e4e8',
  },
  historyItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e1e4e8',
  },
  historyText: {
    flex: 1,
    fontSize: 14,
    color: '#333',
  },
  historyTime: {
    fontSize: 12,
    color: '#666',
    marginLeft: 8,
  },
  resultsContainer: {
    marginTop: 24,
    gap: 12,
  },
});