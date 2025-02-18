import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, Platform, ScrollView, Animated } from 'react-native';

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

  // Animation values
  const fadeAnim = React.useRef(new Animated.Value(0)).current;
  const scaleAnim = React.useRef(new Animated.Value(0.9)).current;

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

  const handleAnalyze = async () => {
    if (!inputText.trim()) return;
    setIsAnalyzing(true);

    // Add to history
    const newHistoryItem = {
      text: inputText,
      timestamp: Date.now()
    };
    const newHistory = [newHistoryItem, ...history.slice(0, 19)];
    setHistory(newHistory);

    // Mock tokenization
    setTimeout(() => {
      const words = inputText.split(/\s+/);
      const analyzed: TokenizedWord[] = words.map(word => ({
        word,
        reading: word.length > 2 ? word.split('').join('・') : undefined,
        definitions: ['Example definition', 'Alternative meaning'],
        pos: ['Noun', 'Verb', 'Adjective'][Math.floor(Math.random() * 3)],
        frequency: Math.random() * 100
      }));

      setTokenizedWords(analyzed);
      setIsAnalyzing(false);
      setShowHistory(false);
    }, 500);
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
              onChangeText={setInputText}
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

        {showHistory && (
          <View style={styles.historyContainer}>
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
          </View>
        )}
      </Animated.View>

      <View style={styles.resultsContainer}>
        {tokenizedWords.map((word, index) => (
          <Animated.View
            key={index}
            style={[
              styles.wordCard,
              {
                opacity: fadeAnim,
                transform: [{
                  translateY: fadeAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: [20, 0]
                  })
                }]
              }
            ]}
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
          </Animated.View>
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