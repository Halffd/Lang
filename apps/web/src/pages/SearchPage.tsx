import React, { useState, useEffect, useRef } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, Platform, ScrollView } from 'react-native';
import { MotiView, AnimatePresence } from 'moti';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as wanakana from 'wanakana';
import kuromoji from 'kuromoji';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string; // Part of speech
  frequency?: number;
}

interface HistoryItem {
  text: string;
  timestamp: number;
}

export default function SearchPage() {
  const [inputText, setInputText] = useState('');
  const [tokenizedWords, setTokenizedWords] = useState<TokenizedWord[]>([]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [showHistory, setShowHistory] = useState(false);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [autoConvert, setAutoConvert] = useState(true);
  const [clipboardMonitor, setClipboardMonitor] = useState(false);
  const tokenizer = useRef<any>(null);

  // Initialize kuromoji tokenizer
  useEffect(() => {
    kuromoji.builder({ dicPath: '/dict' }).build((err, _tokenizer) => {
      if (err) {
        console.error('Tokenizer error:', err);
        return;
      }
      tokenizer.current = _tokenizer;
    });

    // Load history from storage
    loadHistory();
  }, []);

  const loadHistory = async () => {
    try {
      const savedHistory = await AsyncStorage.getItem('searchHistory');
      if (savedHistory) {
        setHistory(JSON.parse(savedHistory));
      }
    } catch (error) {
      console.error('Error loading history:', error);
    }
  };

  const saveHistory = async (newHistory: HistoryItem[]) => {
    try {
      await AsyncStorage.setItem('searchHistory', JSON.stringify(newHistory));
    } catch (error) {
      console.error('Error saving history:', error);
    }
  };

  const handleInputChange = (text: string) => {
    if (autoConvert && text) {
      setInputText(wanakana.toKana(text, { IMEMode: true }));
    } else {
      setInputText(text);
    }
  };

  const handleAnalyze = async () => {
    if (!inputText.trim() || !tokenizer.current) return;

    setIsAnalyzing(true);
    
    // Add to history
    const newHistoryItem = {
      text: inputText,
      timestamp: Date.now()
    };
    const newHistory = [newHistoryItem, ...history.slice(0, 19)];
    setHistory(newHistory);
    saveHistory(newHistory);

    // Tokenize the input
    const tokens = tokenizer.current.tokenize(inputText);
    const analyzed = tokens.map((token: any) => ({
      word: token.surface_form,
      reading: token.reading,
      definitions: [token.pos, token.pos_detail_1].filter(Boolean),
      pos: token.pos,
      frequency: Math.random() * 100 // Mock frequency for demo
    }));

    setTokenizedWords(analyzed);
    setIsAnalyzing(false);
    setShowHistory(false);
  };

  const clearInput = () => {
    setInputText('');
    setTokenizedWords([]);
  };

  const loadFromHistory = (text: string) => {
    setInputText(text);
    setShowHistory(false);
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <MotiView
        style={styles.searchContainer}
        from={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ type: 'timing', duration: 300 }}
      >
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
              onSubmitEditing={handleAnalyze}
            />
            {inputText && (
              <TouchableOpacity style={styles.clearButton} onPress={clearInput}>
                <Text style={styles.clearButtonText}>×</Text>
              </TouchableOpacity>
            )}
          </View>

          <TouchableOpacity 
            style={[styles.analyzeButton, isAnalyzing && styles.analyzeButtonDisabled]}
            onPress={handleAnalyze}
            disabled={isAnalyzing}
          >
            <Text style={styles.analyzeButtonText}>
              {isAnalyzing ? '解析中...' : '解析'}
            </Text>
          </TouchableOpacity>
        </View>

        <AnimatePresence>
          {showHistory && (
            <MotiView
              style={styles.historyContainer}
              from={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
            >
              {history.map((item) => (
                <TouchableOpacity
                  key={item.timestamp}
                  style={styles.historyItem}
                  onPress={() => loadFromHistory(item.text)}
                >
                  <Text style={styles.historyText}>{item.text}</Text>
                  <Text style={styles.historyTime}>
                    {new Date(item.timestamp).toLocaleTimeString()}
                  </Text>
                </TouchableOpacity>
              ))}
            </MotiView>
          )}
        </AnimatePresence>
      </MotiView>

      <View style={styles.resultsContainer}>
        {tokenizedWords.map((word, index) => (
          <MotiView
            key={index}
            style={styles.wordCard}
            from={{ opacity: 0, translateY: 20 }}
            animate={{ opacity: 1, translateY: 0 }}
            transition={{ delay: index * 100 }}
          >
            <View style={styles.wordHeader}>
              <Text style={styles.wordText}>{word.word}</Text>
              {word.reading && (
                <Text style={styles.readingText}>（{word.reading}）</Text>
              )}
              {word.frequency && (
                <View style={[
                  styles.frequencyBadge,
                  { backgroundColor: word.frequency > 50 ? '#4CAF50' : '#FF9800' }
                ]}>
                  <Text style={styles.frequencyText}>
                    {Math.round(word.frequency)}%
                  </Text>
                </View>
              )}
            </View>
            <View style={styles.wordDetails}>
              {word.pos && (
                <Text style={styles.posText}>{word.pos}</Text>
              )}
              {word.definitions.map((def, idx) => (
                <Text key={idx} style={styles.definitionText}>
                  {idx + 1}. {def}
                </Text>
              ))}
            </View>
          </MotiView>
        ))}
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
  clearButton: {
    position: 'absolute',
    right: 12,
    top: 12,
    width: 24,
    height: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#e1e4e8',
    borderRadius: 12,
  },
  clearButtonText: {
    color: '#666',
    fontSize: 16,
    fontWeight: 'bold',
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
    overflow: 'hidden',
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
  wordCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 4,
    elevation: 2,
  },
  wordHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  },
  wordText: {
    fontSize: 24,
    fontWeight: '600',
    color: '#2c3e50',
  },
  readingText: {
    fontSize: 16,
    color: '#666',
    marginLeft: 8,
  },
  frequencyBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    marginLeft: 'auto',
  },
  frequencyText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
  wordDetails: {
    borderTopWidth: 1,
    borderTopColor: '#e1e4e8',
    paddingTop: 12,
  },
  posText: {
    fontSize: 14,
    color: '#4a90e2',
    fontWeight: '500',
    marginBottom: 8,
  },
  definitionText: {
    fontSize: 14,
    color: '#4a5568',
    lineHeight: 20,
    marginBottom: 4,
  },
}); 