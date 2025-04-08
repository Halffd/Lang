import React from 'react';
import { Box, Text, VStack, HStack, Badge, useColorModeValue } from 'native-base';
import { ViewStyle, TextStyle } from 'react-native';
import { TokenizedWord } from '../../types';
import styles from './ResultDetails.module.scss';

export interface ResultDetailsProps {
  result: TokenizedWord;
}

export const ResultDetails: React.FC<ResultDetailsProps> = ({ result }) => {
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'white');
  const subTextColor = useColorModeValue('gray.600', 'gray.400');

  return (
    <Box
      bg={bgColor}
      borderWidth={1}
      borderColor={borderColor}
      borderRadius="lg"
      p={4}
      _web={{ style: styles['container'] as ViewStyle }}
    >
      <VStack space={4}>
        <HStack alignItems="center">
          <Text
            fontSize="2xl"
            fontWeight="bold"
            color={textColor}
            _web={{ style: styles['surface'] as TextStyle }}
          >
            {result.surface}
          </Text>
          {result.reading && (
            <Text
              fontSize="xl"
              color={subTextColor}
              ml={2}
              _web={{ style: styles['reading'] as TextStyle }}
            >
              {result.reading}
            </Text>
          )}
        </HStack>

        <HStack space={2} flexWrap="wrap">
          <Badge colorScheme="blue" variant="solid">
            {result.pos}
          </Badge>
        </HStack>

        {result.definitions && result.definitions.length > 0 && (
          <>
            <Text
              fontSize="lg"
              fontWeight="semibold"
              color={textColor}
            >
              Definitions
            </Text>
            <VStack space={1} _web={{ style: styles['definitions'] as ViewStyle }}>
              {result.definitions.map((def, index) => (
                <Text
                  key={`${def}-${index}`}
                  color={textColor}
                  fontSize="md"
                >
                  {def}
                </Text>
              ))}
            </VStack>
          </>
        )}
      </VStack>
    </Box>
  );
};

export default ResultDetails; 