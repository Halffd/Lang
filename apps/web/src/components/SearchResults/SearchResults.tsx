import React from 'react';
import { Box, Text, VStack, HStack, Divider, useColorModeValue } from '@mui/material';
import { TokenizedWord } from '../../types';

interface SearchResultsProps {
  results: TokenizedWord[];
  isLoading?: boolean;
  error?: string;
  selectedWordIndex?: number;
  onWordSelect?: (index: number) => void;
}

export const SearchResults: React.FC<SearchResultsProps> = ({
  results,
  isLoading,
  error,
  selectedWordIndex,
  onWordSelect,
}) => {
  const bgColor = useColorModeValue('white', 'grey.900');
  const textColor = useColorModeValue('black', 'white');
  const dividerColor = useColorModeValue('grey.200', 'grey.700');

  if (isLoading) {
    return (
      <Box p={2}>
        <Text>Loading...</Text>
      </Box>
    );
  }

  if (error) {
    return (
      <Box p={2}>
        <Text color="error">{error}</Text>
      </Box>
    );
  }

  if (results.length === 0) {
    return (
      <Box p={2}>
        <Text>No results found</Text>
      </Box>
    );
  }

  return (
    <VStack spacing={2} width="100%">
      {results.map((result, index) => (
        <Box
          key={`${result.surface}-${index}`}
          p={2}
          bgcolor={bgColor}
          borderRadius={1}
          width="100%"
          onClick={() => onWordSelect?.(index)}
          sx={{
            cursor: 'pointer',
            '&:hover': {
              bgcolor: useColorModeValue('grey.100', 'grey.800'),
            },
          }}
        >
          <VStack spacing={1} alignItems="flex-start">
            <HStack spacing={2}>
              <Text fontWeight="bold" fontSize="lg">
                {result.surface}
              </Text>
              <Text color="grey.500">[{result.reading}]</Text>
            </HStack>
            
            <Text color="grey.600">{result.pos}</Text>
            
            {result.definitions.map((def, i) => (
              <Text key={i}>{def}</Text>
            ))}

            {result.etymology && (
              <Box mt={1}>
                <Text fontWeight="bold" color="grey.600">Etymology:</Text>
                <Text>{result.etymology}</Text>
              </Box>
            )}

            {result.additionalInfo?.kanjiInfo && (
              <Box mt={1}>
                <Text fontWeight="bold" color="grey.600">Kanji Information:</Text>
                <Text>Meaning: {result.additionalInfo.kanjiInfo.meaning}</Text>
                <Text>Usage: {result.additionalInfo.kanjiInfo.usage}</Text>
              </Box>
            )}

            {result.examples && result.examples.length > 0 && (
              <Box mt={1}>
                <Text fontWeight="bold" color="grey.600">Examples:</Text>
                {result.examples.map((example, i) => (
                  <Text key={i}>{example}</Text>
                ))}
              </Box>
            )}
          </VStack>
        </Box>
      ))}
    </VStack>
  );
}; 