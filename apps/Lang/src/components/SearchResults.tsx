import React from 'react';
import {
  Box,
  VStack,
  Text,
  Spinner,
  useColorModeValue,
  Pressable,
  HStack,
  Icon,
} from 'native-base';
import { MaterialIcons } from '@expo/vector-icons';
import type { TokenizedWord } from '../types';

export interface SearchResultsProps {
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
  const bgColor = useColorModeValue('white', 'gray.800');
  const selectedBgColor = useColorModeValue('primary.100', 'primary.900');
  const hoverBgColor = useColorModeValue('gray.100', 'gray.700');
  const borderColor = useColorModeValue('gray.200', 'gray.700');

  if (isLoading) {
    return (
      <Box flex={1} justifyContent="center" alignItems="center">
        <Spinner size="lg" color="primary.500" />
      </Box>
    );
  }

  if (error) {
    return (
      <Box flex={1} justifyContent="center" alignItems="center">
        <Text color="red.500">{error}</Text>
      </Box>
    );
  }

  if (results.length === 0) {
    return (
      <Box flex={1} justifyContent="center" alignItems="center">
        <Text color="gray.500">No results found</Text>
      </Box>
    );
  }

  return (
    <VStack space={2}>
      {results.map((result, index) => (
        <Pressable
          key={`${result.surface}-${index}`}
          onPress={() => onWordSelect?.(index)}
        >
          <Box
            bg={selectedWordIndex === index ? selectedBgColor : bgColor}
            p={4}
            borderRadius="md"
            borderWidth={1}
            borderColor={borderColor}
            _hover={{ bg: hoverBgColor }}
          >
            <HStack space={2} alignItems="center">
              <Text fontSize="lg" fontWeight="bold">
                {result.surface}
              </Text>
              {result.reading && (
                <Text color="gray.500">[{result.reading}]</Text>
              )}
              {result.pos && (
                <Text color="gray.500" fontSize="sm">
                  ({result.pos})
                </Text>
              )}
            </HStack>
            {result.definitions && result.definitions.length > 0 && (
              <VStack space={1} mt={2}>
                {result.definitions.map((def, defIndex) => (
                  <Text key={defIndex}>{def}</Text>
                ))}
              </VStack>
            )}
            {result.translations && result.translations.length > 0 && (
              <VStack space={1} mt={2}>
                {result.translations.map((trans, transIndex) => (
                  <HStack key={transIndex} space={2} alignItems="center">
                    <Icon
                      as={<MaterialIcons name="translate" />}
                      size={4}
                      color="gray.400"
                    />
                    <Text>{trans}</Text>
                  </HStack>
                ))}
              </VStack>
            )}
          </Box>
        </Pressable>
      ))}
    </VStack>
  );
};

export default SearchResults; 