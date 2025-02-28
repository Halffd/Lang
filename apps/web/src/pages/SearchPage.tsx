import React, { useState } from 'react';
import { 
  VStack, 
  Input, 
  Box, 
  Text, 
  Heading, 
  HStack, 
  Spinner, 
  FlatList, 
  useColorModeValue,
  IconButton,
  Center,
  useBreakpointValue
} from 'native-base';
import { Platform } from 'react-native';
import Card from '../components/Card';
import Icon from '../components/CustomIcon';
import { useSearch } from '../hooks/useSearch';

// Mock data for demonstration
const SAMPLE_RESULTS = [
  { id: '1', word: '猫', reading: 'ねこ', meaning: 'cat' },
  { id: '2', word: '犬', reading: 'いぬ', meaning: 'dog' },
  { id: '3', word: '鳥', reading: 'とり', meaning: 'bird' },
];

export default function SearchPage() {
  const [query, setQuery] = useState('');
  const { results, loading, error, search } = useSearch();
  
  // Use theme colors
  const inputBgColor = useColorModeValue('white', 'gray.800');
  const placeholderColor = useColorModeValue('gray.400', 'gray.500');
  
  // Responsive width for desktop/web
  const containerWidth = useBreakpointValue({
    base: '100%',
    md: '90%',
    lg: '80%',
    xl: '70%'
  });
  
  const handleSearch = () => {
    if (query.trim()) {
      search(query);
    }
  };
  
  const handleKeyPress = (e: any) => {
    if (Platform.OS === 'web' && e.key === 'Enter') {
      handleSearch();
    }
  };
  
  return (
    <Box p={4} flex={1} alignItems="center">
      <VStack space={4} width={containerWidth} maxW="1200px">
        <Heading size="xl" mb={2}>
          Japanese Dictionary
        </Heading>
        
        <HStack width="100%" space={2} alignItems="center">
          <Input
            flex={1}
            placeholder="Search for words in Japanese or English"
            value={query}
            onChangeText={setQuery}
            onKeyPress={handleKeyPress}
            bg={inputBgColor}
            borderRadius="md"
            fontSize="md"
            py={Platform.OS === 'web' ? 3 : 2}
            px={4}
            _focus={{
              borderColor: 'primary.500',
              borderWidth: 2,
            }}
            placeholderTextColor={placeholderColor}
          />
          <IconButton
            icon={<Icon name="search" size="md" color="white" />}
            onPress={handleSearch}
            bg="primary.500"
            _hover={{ bg: 'primary.600' }}
            _pressed={{ bg: 'primary.700' }}
            borderRadius="md"
            size="lg"
          />
        </HStack>
        
        <Box flex={1} width="100%">
          {loading ? (
            <Center flex={1} mt={10}>
              <Spinner size="lg" color="primary.500" />
              <Text mt={2}>Searching...</Text>
            </Center>
          ) : error ? (
            <Center flex={1} mt={10}>
              <Text color="error.500">{error}</Text>
            </Center>
          ) : (
            <FlatList
              data={results}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <Card
                  title={item.word}
                  description={`${item.reading} - ${item.meaning}`}
                  onPress={() => console.log('Selected:', item.word)}
                  mb={4}
                />
              )}
              ListEmptyComponent={
                <Center flex={1} mt={10}>
                  <Text>No results found. Try a different search term.</Text>
                </Center>
              }
              contentContainerStyle={{
                paddingTop: 4,
                paddingBottom: Platform.OS === 'web' ? 20 : 4
              }}
            />
          )}
        </Box>
      </VStack>
    </Box>
  );
}