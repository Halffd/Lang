import React, { useState, useRef } from 'react';
import {
  Box,
  Input,
  IconButton,
  useColorModeValue,
  Text,
  VStack,
  IInputProps,
  Pressable,
} from 'native-base';
import { StyleSheet } from 'react-native';
import { CustomIcon } from '../CustomIcon/CustomIcon';

export interface SearchBarProps {
  query: string;
  onSearch: (query: string) => void;
  placeholder?: string;
  searchHistory?: string[];
  onHistoryItemClick?: (item: string) => void;
  onClearHistory?: () => void;
}

const styles = StyleSheet.create({
  container: {
    position: 'relative',
  },
  historyContainer: {
    position: 'absolute',
    top: '100%',
    left: 0,
    right: 0,
    zIndex: 1,
  },
  historyItem: {
    cursor: 'pointer',
  },
  clearHistory: {
    cursor: 'pointer',
  }
});

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

  const handleKeyPress = (e: any) => {
    if (e.key === 'Enter' || e.nativeEvent?.key === 'Enter') {
      setShowHistory(false);
    }
  };

  const handleHistoryItemClick = (item: string) => {
    onHistoryItemClick?.(item);
    setShowHistory(false);
    inputRef.current?.focus();
  };

  return (
    <Box position="relative" _web={{ style: styles.container }}>
      <Input
        ref={inputRef}
        flex={1}
        value={query}
        onChangeText={onSearch}
        onKeyPress={handleKeyPress}
        onFocus={() => setShowHistory(true)}
        placeholder={placeholder}
        borderWidth={1}
        borderColor={useColorModeValue('gray.200', 'gray.600')}
        bg={useColorModeValue('white', 'gray.800')}
        _focus={{
          borderColor: useColorModeValue('blue.500', 'blue.400'),
        }}
        rightElement={
          <IconButton
            icon={<CustomIcon name="search" />}
            variant="ghost"
            onPress={() => {
              setShowHistory(false);
              inputRef.current?.blur();
            }}
          />
        }
      />

      {showHistory && searchHistory.length > 0 && (
        <Box
          _web={{ style: styles.historyContainer }}
          bg={useColorModeValue('white', 'gray.800')}
          borderWidth={1}
          borderColor={useColorModeValue('gray.200', 'gray.600')}
          borderRadius="md"
          shadow="md"
          mt={1}
          p={2}
        >
          <VStack space={1}>
            {searchHistory.map((item) => (
              <Pressable
                key={item}
                px={2}
                py={1}
                _web={{ style: { cursor: 'pointer' } }}
                bg="transparent"
                onTouchStart={() => handleHistoryItemClick(item)}
                onPress={() => handleHistoryItemClick(item)}
              >
                <Text>{item}</Text>
              </Pressable>
            ))}
            {onClearHistory && (
              <Text
                color="red.500"
                _web={{ style: styles.clearHistory }}
                onPress={onClearHistory}
              >
                Clear History
              </Text>
            )}
          </VStack>
        </Box>
      )}
    </Box>
  );
};

export default SearchBar; 