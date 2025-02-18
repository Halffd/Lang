import React, { useCallback, useEffect, useRef, useReducer } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, Platform, ScrollView, Animated } from 'react-native';
import { SearchResults } from '../components/SearchResults';
import { useApp } from '../context/AppContext';
import { analyzeText } from '../services/IchiMoeService';
import { searchReducer, initialSearchState } from '../reducers/searchReducer';

export default function SearchPage() {
  const [state, dispatch] = useReducer(searchReducer, initialSearchState);
  const { 
    inputText, 
    results, 
    isAnalyzing, 
    showHistory, 
    autoConvert, 
    clipboardMonitor, 
    error 
  } = state;

  // Animation values
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0.9)).current;

  // Refs for DOM elements
  const scrollViewRef = useRef<ScrollView>(null);
  const inputRef = useRef<TextInput>(null);

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
    dispatch({ type: 'SET_INPUT_TEXT', payload: text });
  }, []);

  const handleSearch = useCallback(async (text: string) => {
    if (!text.trim()) return;
    
    dispatch({ type: 'SET_ANALYZING', payload: true });

    try {
      const ichiMoeResults = await analyzeText(text);
      dispatch({ type: 'PROCESS_ICHI_MOE_RESULTS', payload: ichiMoeResults });
      addToHistory(text);

      // Scroll to results
      setTimeout(() => {
        scrollViewRef.current?.scrollTo({ y: 0, animated: true });
      }, 100);
    } catch (error) {
      console.error('Analysis failed:', error);
      dispatch({ type: 'SET_ERROR', payload: 'Failed to analyze text. Please try again.' });
    }
  }, [addToHistory]);

  const handleHistorySelect = useCallback((text: string) => {
    dispatch({ type: 'SET_INPUT_TEXT', payload: text });
    dispatch({ type: 'SET_SHOW_HISTORY', payload: false });
    handleSearch(text);
  }, [handleSearch]);

  const focusInput = useCallback(() => {
    inputRef.current?.focus();
  }, []);

  return (
    <ScrollView 
      ref={scrollViewRef}
      style={styles.container} 
      contentContainerStyle={styles.contentContainer}
    >
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
              onPress={() => dispatch({ type: 'TOGGLE_AUTO_CONVERT' })}
            >
              <Text style={[styles.optionText, autoConvert && styles.optionTextActive]}>
                かな変換
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.optionButton, clipboardMonitor && styles.optionButtonActive]}
              onPress={() => dispatch({ type: 'TOGGLE_CLIPBOARD_MONITOR' })}
            >
              <Text style={[styles.optionText, clipboardMonitor && styles.optionTextActive]}>
                クリップボード監視
              </Text>
            </TouchableOpacity>
          </View>

          <View style={styles.inputContainer}>
            <TextInput
              ref={inputRef}
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

          {error && (
            <Text style={styles.errorText}>{error}</Text>
          )}
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
  errorText: {
    color: '#ff6b6b',
    fontSize: 14,
    marginTop: 8,
    textAlign: 'center',
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