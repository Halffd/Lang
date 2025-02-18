import React, { useState } from 'react';
import { StyleSheet, View, Text, Switch, TouchableOpacity, Platform } from 'react-native';

interface SettingsOption {
  id: string;
  title: string;
  description: string;
  type: 'toggle' | 'button';
  value?: boolean;
  onPress?: () => void;
}

export default function SettingsPage() {
  const [settings, setSettings] = useState({
    darkMode: false,
    autoAnalyze: true,
    saveHistory: true,
  });

  const handleToggle = (key: keyof typeof settings) => {
    setSettings(prev => ({
      ...prev,
      [key]: !prev[key]
    }));
  };

  const settingsOptions: SettingsOption[] = [
    {
      id: 'darkMode',
      title: 'Dark Mode',
      description: 'Enable dark mode for better viewing in low light',
      type: 'toggle',
      value: settings.darkMode,
    },
    {
      id: 'autoAnalyze',
      title: 'Auto Analyze',
      description: 'Automatically analyze text as you type',
      type: 'toggle',
      value: settings.autoAnalyze,
    },
    {
      id: 'saveHistory',
      title: 'Save History',
      description: 'Save your search history',
      type: 'toggle',
      value: settings.saveHistory,
    },
    {
      id: 'clearHistory',
      title: 'Clear History',
      description: 'Clear all your search history',
      type: 'button',
      onPress: () => {
        // TODO: Implement clear history functionality
        console.log('Clearing history...');
      },
    },
  ];

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Settings</Text>
      
      <View style={styles.settingsList}>
        {settingsOptions.map((option) => (
          <View key={option.id} style={styles.settingItem}>
            <View style={styles.settingInfo}>
              <Text style={styles.settingTitle}>{option.title}</Text>
              <Text style={styles.settingDescription}>{option.description}</Text>
            </View>
            
            {option.type === 'toggle' ? (
              <Switch
                value={option.value}
                onValueChange={() => handleToggle(option.id as keyof typeof settings)}
                trackColor={{ false: '#ddd', true: '#4a90e2' }}
                thumbColor={Platform.OS === 'ios' ? undefined : '#fff'}
              />
            ) : (
              <TouchableOpacity
                style={styles.button}
                onPress={option.onPress}
              >
                <Text style={styles.buttonText}>Clear</Text>
              </TouchableOpacity>
            )}
          </View>
        ))}
      </View>

      <View style={styles.footer}>
        <Text style={styles.version}>Version 1.0.0</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#f5f6fa',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 24,
    color: '#2c3e50',
  },
  settingsList: {
    backgroundColor: '#fff',
    borderRadius: 12,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: '#eee',
  },
  settingItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  settingInfo: {
    flex: 1,
    marginRight: 16,
  },
  settingTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#2c3e50',
    marginBottom: 4,
  },
  settingDescription: {
    fontSize: 14,
    color: '#666',
  },
  button: {
    backgroundColor: '#ff6b6b',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
  footer: {
    marginTop: 24,
    alignItems: 'center',
  },
  version: {
    fontSize: 14,
    color: '#666',
  },
}); 