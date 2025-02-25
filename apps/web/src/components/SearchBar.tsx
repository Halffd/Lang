import React, { memo, useRef } from 'react';
import { StyleSheet, View, TextInput, TouchableOpacity, Text, Platform } from 'react-native';
import { HistoryItem } from '../types';

interface SearchBarProps {
  inputText: string;
  onInputChange: (text: string) => void;
  onSearch: (text: string) => void;
  onHistorySelect: (text: string) => void;
  history: HistoryItem[];
  showHistory: boolean;
}

export const SearchBar = memo(function SearchBar({
  inputText,
  onInputChange,
  onSearch,
  onHistorySelect,
  history,
  showHistory
}: SearchBarProps) {
  const inputRef = useRef<TextInput>(null);

  return (
    <View style={styles.container}>
      <View style={styles.searchContainer}>
        <TextInput
          ref={inputRef}
          style={styles.input}
          value={inputText}
          onChangeText={onInputChange}
          placeholder="Enter text to analyze..."
          placeholderTextColor="#999"
          onSubmitEditing={() => onSearch(inputText)}
          autoFocus={Platform.OS === 'web'}
        />
        <TouchableOpacity
          style={styles.searchButton}
          onPress={() => onSearch(inputText)}
        >
          <Text style={styles.buttonText}>Search</Text>
        </TouchableOpacity>
      </View>

      {showHistory && history.length > 0 && (
        <View style={styles.historyContainer}>
          {history.map((item, index) => (
            <TouchableOpacity
              key={index}
              style={styles.historyItem}
              onPress={() => onHistorySelect(item.text)}
            >
              <Text style={styles.historyText}>{item.text}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    position: 'relative',
    zIndex: 10,
  },
  searchContainer: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
    backgroundColor: '#fff',
  },
  input: {
    flex: 1,
    height: 44,
    paddingHorizontal: 16,
    backgroundColor: '#f5f5f5',
    borderRadius: 8,
    fontSize: 16,
    color: '#333',
    ...(Platform.OS === 'web' ? { outlineStyle: 'none' as any } : {}),
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
}); 