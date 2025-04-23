import React, { useState, useRef } from 'react';
import {
  Box,
  Input,
  IconButton,
  HStack,
  VStack,
  Text,
  Pressable,
  useColorModeValue,
  Icon,
} from 'native-base';
import { MaterialIcons } from '@expo/vector-icons';

export interface SearchBarProps {
  query: string;
  onSearch: (query: string) => void;
  placeholder?: string;
  searchHistory?: string[];
  onHistoryItemClick?: (item: string) => void;
  onClearHistory?: () => void;
}

export const SearchBar: React.FC<SearchBarProps> = ({
  query,
  onSearch,
  placeholder = 'Search...',
  searchHistory = [],
  onHistoryItemClick,
  onClearHistory,
}) => {
  const [showHistory, setShowHistory] = useState(false);
  const inputRef = useRef<any>(null);
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const hoverBgColor = useColorModeValue('gray.100', 'gray.700');

  const handleKeyPress = (e: any) => {
    if (e.nativeEvent.key === 'Enter') {
      setShowHistory(false);
    }
  };

  const handleHistoryItemClick = (item: string) => {
    onHistoryItemClick?.(item);
    setShowHistory(false);
    inputRef.current?.focus();
  };

  return (
    <Box position="relative">
      <HStack space={2}>
        <Input
          flex={1}
          value={query}
          onChangeText={onSearch}
          onKeyPress={handleKeyPress}
          onFocus={() => setShowHistory(true)}
          placeholder={placeholder}
          ref={inputRef}
          InputLeftElement={
            <Icon
              as={<MaterialIcons name="search" />}
              size={5}
              ml={2}
              color="gray.400"
            />
          }
          InputRightElement={
            query ? (
              <IconButton
                icon={<Icon as={<MaterialIcons name="clear" />} size={5} />}
                onPress={() => onSearch('')}
                variant="ghost"
                size="sm"
              />
            ) : undefined
          }
        />
      </HStack>

      {showHistory && searchHistory.length > 0 && (
        <VStack
          position="absolute"
          top="100%"
          left={0}
          right={0}
          mt={1}
          bg={bgColor}
          borderRadius="md"
          borderWidth={1}
          borderColor={borderColor}
          maxH="200"
          overflow="hidden"
          zIndex={1}
        >
          {searchHistory.map((item) => (
            <Pressable
              key={item}
              onPress={() => handleHistoryItemClick(item)}
              _hover={{ bg: hoverBgColor }}
              p={2}
            >
              <HStack space={2} alignItems="center">
                <Icon
                  as={<MaterialIcons name="history" />}
                  size={5}
                  color="gray.400"
                />
                <Text>{item}</Text>
              </HStack>
            </Pressable>
          ))}
          {onClearHistory && (
            <Pressable
              onPress={onClearHistory}
              _hover={{ bg: 'red.100' }}
              p={2}
            >
              <HStack space={2} alignItems="center">
                <Icon
                  as={<MaterialIcons name="delete" />}
                  size={5}
                  color="red.500"
                />
                <Text color="red.500">Clear History</Text>
              </HStack>
            </Pressable>
          )}
        </VStack>
      )}
    </Box>
  );
};

export default SearchBar; 