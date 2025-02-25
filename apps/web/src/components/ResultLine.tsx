import React, { memo } from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { TokenizedWord } from '../types';

interface ResultLineProps {
  word: TokenizedWord;
  onSelect: () => void;
  isSelected?: boolean;
}

export const ResultLine = memo(function ResultLine({ word, onSelect, isSelected = false }: ResultLineProps) {
  return (
    <TouchableOpacity 
      style={[styles.container, isSelected && styles.selectedContainer]} 
      onPress={onSelect}
      activeOpacity={0.7}
    >
      <View style={styles.wordContainer}>
        <Text style={styles.wordText}>{word.word}</Text>
        {word.reading && (
          <Text style={styles.readingText}>（{word.reading}）</Text>
        )}
      </View>
      
      <View style={styles.definitionContainer}>
        {word.definitions.length > 0 && (
          <Text style={styles.definitionText} numberOfLines={2}>
            {word.definitions[0]}
          </Text>
        )}
      </View>
      
      <View style={styles.metaContainer}>
        {word.pos && (
          <View style={styles.tag}>
            <Text style={styles.tagText}>{word.pos}</Text>
          </View>
        )}
        {word.frequency != null && (
          <View style={[styles.tag, styles.frequencyTag]}>
            <Text style={styles.tagText}>{Math.round(word.frequency)}%</Text>
          </View>
        )}
      </View>
    </TouchableOpacity>
  );
});

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 12,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  selectedContainer: {
    borderColor: '#2196f3',
    backgroundColor: '#e3f2fd',
  },
  wordContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
    gap: 8,
  },
  wordText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#2c3e50',
  },
  readingText: {
    fontSize: 16,
    color: '#666',
  },
  definitionContainer: {
    marginBottom: 8,
  },
  definitionText: {
    fontSize: 14,
    color: '#2c3e50',
    lineHeight: 20,
  },
  metaContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  tag: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  },
  frequencyTag: {
    backgroundColor: '#e8f5e9',
  },
  tagText: {
    fontSize: 12,
    color: '#64748b',
  },
}); 