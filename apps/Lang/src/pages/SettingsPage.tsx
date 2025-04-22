import React from 'react';
import { View, StyleSheet } from 'react-native';
import { useApp } from '../context/AppContext';
import { Switch, Text, VStack, HStack } from 'native-base';

export const SettingsPage: React.FC = () => {
  const { settings, updateSettings } = useApp();

  const handleToggleFurigana = (value: boolean) => {
    updateSettings({ ...settings, showFurigana: value });
  };

  return (
    <View style={styles.container}>
      <VStack space={4} p={4}>
        <HStack justifyContent="space-between" alignItems="center">
          <Text fontSize="lg">Show Furigana</Text>
          <Switch
            isChecked={settings.showFurigana}
            onToggle={handleToggleFurigana}
          />
        </HStack>
      </VStack>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
}); 