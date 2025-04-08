import React from 'react';
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
import { Card } from '../components/Card';
import { useApp } from '../context/AppContext';

export default function SettingsPage() {
  const { colorMode, toggleColorMode } = useColorMode();
  const { settings, updateSettings } = useApp();
  const [autoConvert, setAutoConvert] = React.useState(true);
  const [clipboardMonitor, setClipboardMonitor] = React.useState(false);
  const [showFurigana, setShowFurigana] = React.useState(true);
  
  // Use theme colors
  const textColor = useColorModeValue('gray.700', 'gray.200');
  const subtitleColor = useColorModeValue('gray.600', 'gray.400');
  
  return (
    <ScrollView>
      <Box p={4} flex={1}>
        <VStack space={6} width="100%">
          <Heading size="xl" mb={2}>
            Settings
          </Heading>
          
          <Card title="Display Settings">
            <Text color={textColor} fontSize="xl" fontWeight="bold">
              Display Settings
            </Text>
            <VStack space={4} mt={4}>
              <HStack justifyContent="space-between" alignItems="center">
                <Text color={textColor}>Dark Mode</Text>
                <Switch
                  isChecked={colorMode === 'dark'}
                  onToggle={toggleColorMode}
                />
              </HStack>
              <HStack justifyContent="space-between" alignItems="center">
                <Text color={textColor}>Show Furigana</Text>
                <Switch
                  isChecked={settings.showFurigana}
                  onToggle={() => updateSettings('showFurigana', !settings.showFurigana)}
                />
              </HStack>
            </VStack>
          </Card>
          
          <Card title="Search Settings">
            <Text color={textColor} fontSize="xl" fontWeight="bold">
              Search Settings
            </Text>
            <VStack space={4} mt={4}>
              <HStack justifyContent="space-between" alignItems="center">
                <Text color={textColor}>Auto-convert to Hiragana</Text>
                <Switch
                  isChecked={settings.autoConvert}
                  onToggle={() => updateSettings('autoConvert', !settings.autoConvert)}
                />
              </HStack>
              <HStack justifyContent="space-between" alignItems="center">
                <Text color={textColor}>Monitor Clipboard</Text>
                <Switch
                  isChecked={settings.clipboardMonitor}
                  onToggle={() => updateSettings('clipboardMonitor', !settings.clipboardMonitor)}
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