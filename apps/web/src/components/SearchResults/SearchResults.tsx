import React from 'react';
import { Box, VStack, Text, useColorModeValue } from 'native-base';
import { ResultLine } from '../ResultLine/ResultLine';
import { TokenizedWord } from '../../types';
import { StyleSheet, ViewStyle } from 'react-native';

export interface SearchResultsProps {
  results: TokenizedWord[];
  isLoading?: boolean;
  error?: string;
  selectedWordIndex?: number;
  onWordSelect?: (index: number) => void;
}

const styles = StyleSheet.create({
  container: {
    display: 'flex' as const,
    width: '100%' as const,
  },
  emptyContainer: {
    display: 'flex' as const,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  }
});

export const SearchResults: React.FC<SearchResultsProps> = ({
  results,
  isLoading,
  error,
  selectedWordIndex,
  onWordSelect,
}) => {
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'white');

  if (isLoading) {
    return (
      <Box
        bg={bgColor}
        borderWidth={1}
        borderColor={borderColor}
        borderRadius="lg"
        alignItems="center"
        minHeight="200px"
        _web={{ style: styles.emptyContainer as ViewStyle }}
      >
        <Text color={textColor}>Loading...</Text>
      </Box>
    );
  }

  if (error) {
    return (
      <Box
        bg={bgColor}
        borderWidth={1}
        borderColor={borderColor}
        borderRadius="lg"
        alignItems="center"
        minHeight="200px"
        _web={{ style: styles.emptyContainer as ViewStyle }}
      >
        <Text color="red.500">{error}</Text>
      </Box>
    );
  }

  if (!results.length) {
    return (
      <Box
        bg={bgColor}
        borderWidth={1}
        borderColor={borderColor}
        borderRadius="lg"
        alignItems="center"
        minHeight="200px"
        _web={{ style: styles.emptyContainer as ViewStyle }}
      >
        <Text color={textColor}>No results found</Text>
      </Box>
    );
  }

  return (
    <Box
      bg={bgColor}
      borderWidth={1}
      borderColor={borderColor}
      borderRadius="lg"
      p={4}
      _web={{ style: styles.container as ViewStyle }}
    >
      <VStack space={4}>
        {results.map((word, index) => (
          <ResultLine
            key={`${word.surface}-${index}`}
            word={word}
            isSelected={selectedWordIndex === index}
            onSelect={() => onWordSelect?.(index)}
          />
        ))}
      </VStack>
    </Box>
  );
}; 