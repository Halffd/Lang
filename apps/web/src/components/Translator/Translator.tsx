import React, { useState } from 'react';
import { Box, VStack, HStack, Text, Select, TextArea, Button, Spinner, useColorModeValue } from 'native-base';
import { TranslationMode, TranslationResult } from './types';
import { TranslationResults } from './TranslationResults';
import { languageOptions } from './languageOptions';
import { TranslationService } from './TranslationService';

export const Translator: React.FC = () => {
  const [sourceText, setSourceText] = useState('');
  const [sourceLanguage, setSourceLanguage] = useState('en');
  const [targetLanguage, setTargetLanguage] = useState('es');
  const [translationMode, setTranslationMode] = useState<TranslationMode>('standard');
  const [isTranslating, setIsTranslating] = useState(false);
  const [translationResult, setTranslationResult] = useState<TranslationResult | null>(null);

  const bgColor = useColorModeValue('white', 'gray.800');
  const borderColor = useColorModeValue('gray.200', 'gray.700');
  const textColor = useColorModeValue('gray.800', 'white');
  const primaryColor = useColorModeValue('blue.500', 'blue.300');

  const handleTranslate = async () => {
    if (!sourceText.trim()) return;

    setIsTranslating(true);
    try {
      const result = await TranslationService.translate(
        sourceText,
        sourceLanguage,
        targetLanguage,
        translationMode
      );
      setTranslationResult(result);
    } catch (error) {
      console.error('Translation error:', error);
    } finally {
      setIsTranslating(false);
    }
  };

  return (
    <VStack space={4} flex={1}>
      <HStack space={4}>
        <Select
          selectedValue={sourceLanguage}
          onValueChange={setSourceLanguage}
          bg={bgColor}
          borderColor={borderColor}
          color={textColor}
        >
          {languageOptions.map((option) => (
            <Select.Item
              key={option.value}
              label={option.label}
              value={option.value}
            />
          ))}
        </Select>

        <Select
          selectedValue={targetLanguage}
          onValueChange={setTargetLanguage}
          bg={bgColor}
          borderColor={borderColor}
          color={textColor}
        >
          {languageOptions.map((option) => (
            <Select.Item
              key={option.value}
              label={option.label}
              value={option.value}
            />
          ))}
        </Select>

        <Select
          selectedValue={translationMode}
          onValueChange={(value) => setTranslationMode(value as TranslationMode)}
          bg={bgColor}
          borderColor={borderColor}
          color={textColor}
        >
          <Select.Item label="Standard" value="standard" />
          <Select.Item label="Learning" value="learning" />
          <Select.Item label="Professional" value="professional" />
        </Select>
      </HStack>

      <TextArea
        value={sourceText}
        onChangeText={setSourceText}
        placeholder="Enter text to translate"
        bg={bgColor}
        borderColor={borderColor}
        color={textColor}
        flex={1}
        autoCompleteType="off"
        onTextInput={() => {}}
        tvParallaxProperties={{}}
      />

      <Button
        onPress={handleTranslate}
        isLoading={isTranslating}
        isDisabled={!sourceText.trim()}
      >
        Translate
      </Button>

      {translationResult && (
        <TranslationResults result={translationResult} />
      )}
    </VStack>
  );
};

// Helper function to translate text using Google Translate API
async function translateText(text: string, fromLang: string, toLang: string): Promise<string> {
  const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${fromLang}&tl=${toLang}&dt=t&q=${encodeURIComponent(text)}`;

  try {
    const response = await fetch(url);

    if (!response.ok) {
      throw new Error(`Translation request failed: ${response.status}`);
    }

    const data = await response.json();

    if (data && data[0] && data[0].length > 0) {
      return data[0]
        .filter((item: any[]) => item[0])
        .map((item: any[]) => item[0])
        .join('');
    } else {
      throw new Error('Unexpected translation response format');
    }
  } catch (error) {
    console.error('Translation error:', error);
    throw error;
  }
}

export default Translator; 