import React, { useRef, useEffect, useMemo } from 'react';
import { StyleSheet, View, ScrollView, Animated, Platform } from 'react-native';
import { SearchBar } from '../components/SearchBar';
import { SearchResults } from '../components/SearchResults';
import { useApp } from '../context/AppContext';
import { useSearch } from '../hooks/useSearch';
import { useScrollMode } from '../hooks/useScrollMode';

// Memoized animation configuration
const ANIMATION_CONFIG = {
  duration: 300,
  useNativeDriver: true,
};

export default function SearchPage() {
  // Get search functionality from custom hook
  const { 
    state, 
    handleInputChange, 
    handleSearch, 
    handleHistorySelect 
  } = useSearch();
  
  const { 
    inputText, 
    results, 
    isAnalyzing, 
    showHistory, 
    error 
  } = state;

  // Animation values
  const fadeAnim = useRef(new Animated.Value(0)).current;
  const scaleAnim = useRef(new Animated.Value(0.9)).current;

  // Refs for DOM elements
  const scrollViewRef = useRef<ScrollView>(null);

  // Get history from context
  const { history } = useApp();

  // Get scroll mode functionality
  const { scrollMode, toggleScrollMode } = useScrollMode(scrollViewRef);

  // Memoized animation sequence
  const animationSequence = useMemo(() => 
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        ...ANIMATION_CONFIG,
      }),
      Animated.timing(scaleAnim, {
        toValue: 1,
        ...ANIMATION_CONFIG,
      }),
    ]),
    [fadeAnim, scaleAnim]
  );

  // Run animation on mount
  useEffect(() => {
    animationSequence.start();
  }, [animationSequence]);

  return (
    <Animated.View 
      style={[
        styles.container,
        { 
          opacity: fadeAnim,
          transform: [{ scale: scaleAnim }]
        }
      ]}
    >
      <SearchBar
        inputText={inputText}
        onInputChange={handleInputChange}
        onSearch={handleSearch}
        onHistorySelect={handleHistorySelect}
        history={history}
        showHistory={showHistory}
      />

      <View style={styles.resultsContainer}>
        <SearchResults
          results={results}
          isLoading={isAnalyzing}
          error={error}
          scrollViewRef={scrollViewRef}
        />
      </View>

      {Platform.OS === 'web' && (
        <View style={styles.scrollModeIndicator}>
          <View 
            style={[
              styles.scrollModeIcon, 
              scrollMode === 'CURSOR' && styles.scrollModeActive
            ]} 
          />
        </View>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  resultsContainer: {
    flex: 1,
  },
  scrollModeIndicator: {
    position: 'absolute',
    bottom: 20,
    right: 20,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(0, 0, 0, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  scrollModeIcon: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#ccc',
  },
  scrollModeActive: {
    backgroundColor: '#2196f3',
  },
});