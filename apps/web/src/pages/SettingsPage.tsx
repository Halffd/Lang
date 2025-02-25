import React, { useState } from 'react';
import { 
  Box, 
  VStack, 
  Heading, 
  Text, 
  Switch, 
  HStack, 
  Divider, 
  useColorMode, 
  Button, 
  ScrollView,
  useColorModeValue
} from 'native-base';
import Card from '../components/Card';

export default function SettingsPage() {
  const { colorMode, toggleColorMode } = useColorMode();
  const [autoConvert, setAutoConvert] = useState(true);
  const [clipboardMonitor, setClipboardMonitor] = useState(false);
  const [showFurigana, setShowFurigana] = useState(true);
  
  // Use theme colors
  const textColor = useColorModeValue('gray.800', 'gray.100');
  const subtitleColor = useColorModeValue('gray.600', 'gray.400');
  
  return (
    <ScrollView>
      <Box p={4} flex={1}>
        <VStack space={6} width="100%">
          <Heading size="xl" mb={2}>
            Settings
          </Heading>
          
          <Card title="Display Settings">
            <VStack space={4} mt={2}>
              <HStack justifyContent="space-between" alignItems="center">
                <VStack>
                  <Text color={textColor} fontWeight="medium">Dark Mode</Text>
                  <Text color={subtitleColor} fontSize="sm">
                    Switch between light and dark theme
                  </Text>
                </VStack>
                <Switch
                  isChecked={colorMode === 'dark'}
                  onToggle={toggleColorMode}
                  colorScheme="primary"
                />
              </HStack>
              
              <Divider />
              
              <HStack justifyContent="space-between" alignItems="center">
                <VStack>
                  <Text color={textColor} fontWeight="medium">Show Furigana</Text>
                  <Text color={subtitleColor} fontSize="sm">
                    Display reading above kanji characters
                  </Text>
                </VStack>
                <Switch
                  isChecked={showFurigana}
                  onToggle={() => setShowFurigana(!showFurigana)}
                  colorScheme="primary"
                />
              </HStack>
            </VStack>
          </Card>
          
          <Card title="Input Settings">
            <VStack space={4} mt={2}>
              <HStack justifyContent="space-between" alignItems="center">
                <VStack>
                  <Text color={textColor} fontWeight="medium">Auto-convert Romaji</Text>
                  <Text color={subtitleColor} fontSize="sm">
                    Automatically convert romaji to hiragana
                  </Text>
                </VStack>
                <Switch
                  isChecked={autoConvert}
                  onToggle={() => setAutoConvert(!autoConvert)}
                  colorScheme="primary"
                />
              </HStack>
              
              <Divider />
              
              <HStack justifyContent="space-between" alignItems="center">
                <VStack>
                  <Text color={textColor} fontWeight="medium">Monitor Clipboard</Text>
                  <Text color={subtitleColor} fontSize="sm">
                    Automatically search for copied text
                  </Text>
                </VStack>
                <Switch
                  isChecked={clipboardMonitor}
                  onToggle={() => setClipboardMonitor(!clipboardMonitor)}
                  colorScheme="primary"
                />
              </HStack>
            </VStack>
          </Card>
          
          <Card title="Data Management">
            <VStack space={4} mt={2}>
              <Button 
                colorScheme="primary" 
                variant="outline"
                onPress={() => console.log('Clear history')}
              >
                Clear Search History
              </Button>
              
              <Button 
                colorScheme="danger"
                onPress={() => console.log('Reset all settings')}
              >
                Reset All Settings
              </Button>
            </VStack>
          </Card>
        </VStack>
      </Box>
    </ScrollView>
  );
} 