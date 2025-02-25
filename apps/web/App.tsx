import React from 'react';
import { View } from 'react-native';
import { AppProvider } from './src/context/AppContext';
import SearchPage from './src/pages/SearchPage';

export default function App() {
  return (
    <AppProvider>
      <View style={{ flex: 1 }}>
        <SearchPage />
      </View>
    </AppProvider>
  );
}
