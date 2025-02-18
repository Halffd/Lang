import React, { useState, useEffect, useRef } from 'react';
import { StyleSheet, View, Text, ScrollView, Animated } from 'react-native';
import { ResultLine } from './ResultLine';
import { ResultDetails } from './ResultDetails';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
}

interface SearchResultsProps {
  results: TokenizedWord[];
  isLoading?: boolean;
}

export function SearchResults({ results, isLoading }: SearchResultsProps) {
  const [selectedWord, setSelectedWord] = useState<TokenizedWord | null>(null);
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scrollViewRef = useRef<ScrollView>(null);

  useEffect(() => {
    // Reset selection when results change
    setSelectedWord(null);

    // Animate new results
    fadeAnim.setValue(0);
    Animated.timing(fadeAnim, {
      toValue: 1,
      duration: 300,
      useNativeDriver: true,
    }).start();

    // Scroll to top when new results come in
    scrollViewRef.current?.scrollTo({ y: 0, animated: true });
  }, [results]);

  if (isLoading) {
    return (
      <View style={styles.container}>
        <Text style={styles.loadingText}>Analyzing text...</Text>
      </View>
    );
  }

  if (results.length === 0) {
    return (
      <View style={styles.container}>
        <Text style={styles.emptyText}>No results found</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ScrollView
        ref={scrollViewRef}
        style={styles.scrollView}
        contentContainerStyle={styles.scrollContent}
      >
        <Animated.View style={[styles.resultsContainer, { opacity: fadeAnim }]}>
          {results.map((word, index) => (
            <View key={index} style={styles.resultItem}>
              <ResultLine
                word={word}
                onSelect={() => setSelectedWord(word)}
              />
            </View>
          ))}
        </Animated.View>
      </ScrollView>

      {selectedWord && (
        <View style={styles.detailsContainer}>
          <ResultDetails word={selectedWord} />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
  },
  resultsContainer: {
    gap: 12,
  },
  resultItem: {
    borderRadius: 8,
    overflow: 'hidden',
  },
  detailsContainer: {
    backgroundColor: '#fff',
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    maxHeight: '50%',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: -2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
  },
  loadingText: {
    textAlign: 'center',
    fontSize: 16,
    color: '#666',
    marginTop: 20,
  },
  emptyText: {
    textAlign: 'center',
    fontSize: 16,
    color: '#666',
    marginTop: 20,
  },
}); 