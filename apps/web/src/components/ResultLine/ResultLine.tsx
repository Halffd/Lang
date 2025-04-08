import React, { memo } from 'react';
import { Box, HStack, Text, Badge, useColorModeValue, Pressable } from 'native-base';
import { TokenizedWord } from '../../types';
import { StyleSheet, ViewStyle, TextStyle } from 'react-native';

export interface ResultLineProps {
  word: TokenizedWord;
  isSelected?: boolean;
  onSelect: () => void;
}

const styles = StyleSheet.create({
  container: {
    display: 'flex' as const,
  },
  surface: {
    display: 'flex' as const,
  },
  reading: {
    display: 'flex' as const,
  },
  posDetail: {
    display: 'flex' as const,
  },
  frequency: {
    display: 'flex' as const,
  }
});

export const ResultLine = memo(function ResultLine({
  word,
  isSelected = false,
  onSelect,
}: ResultLineProps) {
  const bgColor = useColorModeValue('white', 'gray.800');
  const selectedBgColor = useColorModeValue('blue.50', 'blue.900');
  const borderColor = useColorModeValue('gray.200', 'gray.600');
  const selectedBorderColor = useColorModeValue('blue.200', 'blue.600');
  const textColor = useColorModeValue('gray.800', 'white');
  const subTextColor = useColorModeValue('gray.600', 'gray.400');

  return (
    <Pressable onPress={onSelect}>
      <Box
        _web={{ style: styles.container as ViewStyle }}
        bg={isSelected ? selectedBgColor : bgColor}
        borderWidth={1}
        borderColor={isSelected ? selectedBorderColor : borderColor}
        borderRadius="md"
        p={4}
      >
        <HStack alignItems="center" space={2}>
          <Text
            fontSize="xl"
            fontWeight="bold"
            color={textColor}
            _web={{ style: styles.surface as TextStyle }}
          >
            {word.surface}
          </Text>
          {word.reading && (
            <Text
              fontSize="md"
              color={subTextColor}
              ml={2}
              _web={{ style: styles.reading as TextStyle }}
            >
              {word.reading}
            </Text>
          )}
        </HStack>

        <HStack mt={2} space={2} flexWrap="wrap">
          {word.pos_detail?.map((detail, index) => (
            <Badge
              key={`${detail}-${index}`}
              colorScheme="gray"
              variant="subtle"
              _web={{ style: styles.posDetail as ViewStyle }}
            >
              {detail}
            </Badge>
          ))}

          {word.frequency !== undefined && (
            <Badge
              colorScheme="green"
              variant="solid"
              _web={{ style: styles.frequency as ViewStyle }}
            >
              {`${Math.round(word.frequency * 100)}%`}
            </Badge>
          )}
        </HStack>
      </Box>
    </Pressable>
  );
}); 