import React, { memo } from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
}

interface ResultLineProps {
  word: TokenizedWord;
  onSelect?: () => void;
}

export const ResultLine = memo(function ResultLine({ word, onSelect }: ResultLineProps) {
  return (
    <TouchableOpacity
      style={styles.container}
      onPress={onSelect}
      activeOpacity={0.7}
    >
      <View style={styles.mainContent}>
        <Text style={styles.wordText}>{word.word}</Text>
        {word.reading && (
          <Text style={styles.readingText}>（{word.reading}）</Text>
        )}
      </View>

      {word.pos && (
        <View style={styles.posContainer}>
          <Text style={styles.posText}>{word.pos}</Text>
        </View>
      )}

      {word.frequency != null && (
        <View style={[
          styles.frequencyBadge,
          { backgroundColor: word.frequency > 50 ? '#4CAF50' : '#FF9800' }
        ]}>
          <Text style={styles.frequencyText}>
            {Math.round(word.frequency)}%
          </Text>
        </View>
      )}
    </TouchableOpacity>
  );
});

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    backgroundColor: '#f8f9fa',
  },
  mainContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  wordText: {
    fontSize: 20,
    fontWeight: '600',
    color: '#2c3e50',
  },
  readingText: {
    fontSize: 16,
    color: '#666',
  },
  posContainer: {
    backgroundColor: '#e3f2fd',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 16,
    marginRight: 8,
  },
  posText: {
    fontSize: 12,
    color: '#1976d2',
    fontWeight: '500',
  },
  frequencyBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  frequencyText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '600',
  },
}); 