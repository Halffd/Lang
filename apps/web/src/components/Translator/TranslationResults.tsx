import React from 'react';
import { Box, VStack, HStack, Text, useColorModeValue } from 'native-base';
import { TranslationResult } from './types';

interface TranslationResultsProps {
  result: TranslationResult;
}

export const TranslationResults: React.FC<TranslationResultsProps> = ({ result }) => {
  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'white');
  const secondaryTextColor = useColorModeValue('gray.600', 'gray.400');

  return (
    <Box
      bg={bgColor}
      borderWidth={1}
      borderColor={borderColor}
      borderRadius="lg"
      p={4}
    >
      <VStack space={4}>
        <Box>
          <Text fontSize="lg" fontWeight="bold" color={textColor} mb={2}>
            Full Translation
          </Text>
          <Text color={textColor}>{result.fullTranslation}</Text>
        </Box>

        <Box>
          <Text fontSize="lg" fontWeight="bold" color={textColor} mb={2}>
            Word by Word
          </Text>
          <VStack space={2}>
            {result.wordByWord.map((word, index) => (
              <Box
                key={`${word.source}-${index}`}
                borderWidth={1}
                borderColor={borderColor}
                borderRadius="md"
                p={2}
              >
                <HStack space={2} alignItems="center">
                  <Text fontWeight="bold" color={textColor}>
                    {word.source}
                  </Text>
                  <Text color={secondaryTextColor}>→</Text>
                  <Text color={textColor}>{word.translation}</Text>
                </HStack>
                {word.pronunciation && (
                  <Text fontSize="sm" color={secondaryTextColor} mt={1}>
                    Pronunciation: {word.pronunciation}
                  </Text>
                )}
                {word.partOfSpeech && (
                  <Text fontSize="sm" color={secondaryTextColor} mt={1}>
                    Part of Speech: {word.partOfSpeech}
                  </Text>
                )}
                {word.alternativeTranslations && word.alternativeTranslations.length > 0 && (
                  <Box mt={1}>
                    <Text fontSize="sm" color={secondaryTextColor}>
                      Alternatives: {word.alternativeTranslations.join(', ')}
                    </Text>
                  </Box>
                )}
                {word.examples && word.examples.length > 0 && (
                  <Box mt={1}>
                    <Text fontSize="sm" color={secondaryTextColor}>
                      Examples: {word.examples.join('; ')}
                    </Text>
                  </Box>
                )}
              </Box>
            ))}
          </VStack>
        </Box>

        {result.mode === 'professional' && (
          <Box>
            <Text fontSize="lg" fontWeight="bold" color={textColor} mb={2}>
              Additional Information
            </Text>
            <VStack space={2}>
              {result.confidence && (
                <Text color={textColor}>
                  Confidence: {(result.confidence * 100).toFixed(1)}%
                </Text>
              )}
              {result.formalityLevel && (
                <Text color={textColor}>
                  Formality: {result.formalityLevel}
                </Text>
              )}
            </VStack>
          </Box>
        )}

        {result.mode === 'learning' && (
          <Box>
            <Text fontSize="lg" fontWeight="bold" color={textColor} mb={2}>
              Learning Resources
            </Text>
            <VStack space={2}>
              {result.grammarNotes && result.grammarNotes.length > 0 && (
                <Box>
                  <Text fontWeight="medium" color={textColor} mb={1}>
                    Grammar Notes:
                  </Text>
                  <VStack space={1}>
                    {result.grammarNotes.map((note, index) => (
                      <Text key={index} color={textColor}>
                        • {note}
                      </Text>
                    ))}
                  </VStack>
                </Box>
              )}
              {result.commonPhrases && result.commonPhrases.length > 0 && (
                <Box>
                  <Text fontWeight="medium" color={textColor} mb={1}>
                    Common Phrases:
                  </Text>
                  <VStack space={1}>
                    {result.commonPhrases.map((phrase, index) => (
                      <Text key={index} color={textColor}>
                        • {phrase}
                      </Text>
                    ))}
                  </VStack>
                </Box>
              )}
            </VStack>
          </Box>
        )}
      </VStack>
    </Box>
  );
}; 