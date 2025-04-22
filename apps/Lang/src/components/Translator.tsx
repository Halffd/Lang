import React, { useState } from 'react';
import {
  Box,
  VStack,
  HStack,
  Select,
  TextArea,
  Button,
  Text,
  useColorModeValue,
  Icon,
  Spinner,
} from 'native-base';
import { MaterialIcons } from '@expo/vector-icons';
import { languageOptions } from './Translator/languageOptions';

export interface TranslatorProps {
  onTranslate: (
    text: string,
    sourceLang: string,
    targetLang: string,
    mode: 'per-word' | 'dictionary' | 'scraping'
  ) => Promise<string>;
}

export const Translator: React.FC<TranslatorProps> = ({ onTranslate }) => {
  const [sourceText, setSourceText] = useState('');
  const [translatedText, setTranslatedText] = useState('');
  const [sourceLanguage, setSourceLanguage] = useState('ja');
  const [targetLanguage, setTargetLanguage] = useState('en');
  const [translationMode, setTranslationMode] = useState<'per-word' | 'dictionary' | 'scraping'>('dictionary');
  const [isTranslating, setIsTranslating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');

  const handleTranslate = async () => {
    if (!sourceText.trim()) {
      setError('Please enter text to translate');
      return;
    }

    setIsTranslating(true);
    setError(null);

    try {
      const result = await onTranslate(
        sourceText,
        sourceLanguage,
        targetLanguage,
        translationMode
      );
      setTranslatedText(result);
    } catch (err) {
      console.error('Translation error:', err);
      setError(err instanceof Error ? err.message : 'An error occurred during translation');
    } finally {
      setIsTranslating(false);
    }
  };

  return (
    <VStack space={4}>
      <HStack space={2}>
        <Select
          flex={1}
          selectedValue={sourceLanguage}
          onValueChange={setSourceLanguage}
        >
          {languageOptions.map((lang) => (
            <Select.Item
              key={lang.value}
              label={lang.label}
              value={lang.value}
            />
          ))}
        </Select>
        <Icon
          as={<MaterialIcons name="swap-horiz" />}
          size={6}
          color="gray.500"
          alignSelf="center"
        />
        <Select
          flex={1}
          selectedValue={targetLanguage}
          onValueChange={setTargetLanguage}
        >
          {languageOptions.map((lang) => (
            <Select.Item
              key={lang.value}
              label={lang.label}
              value={lang.value}
            />
          ))}
        </Select>
      </HStack>

      <Select
        selectedValue={translationMode}
        onValueChange={(value) => setTranslationMode(value as 'per-word' | 'dictionary' | 'scraping')}
      >
        <Select.Item label="Dictionary Mode" value="dictionary" />
        <Select.Item label="Per Word Mode" value="per-word" />
        <Select.Item label="Scraping Mode" value="scraping" />
      </Select>

      <TextArea
        value={sourceText}
        onChangeText={setSourceText}
        placeholder="Enter text to translate..."
        h={100}
        bg={bgColor}
        borderColor={borderColor}
      />

      <Button
        onPress={handleTranslate}
        isLoading={isTranslating}
        leftIcon={<Icon as={<MaterialIcons name="translate" />} size={5} />}
      >
        Translate
      </Button>

      {error && (
        <Text color="red.500">{error}</Text>
      )}

      {isTranslating ? (
        <Box flex={1} justifyContent="center" alignItems="center">
          <Spinner size="lg" color="primary.500" />
        </Box>
      ) : translatedText ? (
        <TextArea
          value={translatedText}
          isReadOnly
          h={100}
          bg={bgColor}
          borderColor={borderColor}
        />
      ) : null}
    </VStack>
  );
};

export default Translator; 