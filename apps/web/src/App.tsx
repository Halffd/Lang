import React, { useState } from 'react';
import { StyleSheet, View, Platform } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import Navigation from './components/Navigation';
import SearchPage from './pages/SearchPage';
import SettingsPage from './pages/SettingsPage';
import { AppProvider } from './context/AppContext';

export default function App() {
  const [currentPage, setCurrentPage] = useState('search');

  const renderPage = () => {
    switch (currentPage) {
      case 'search':
        return <SearchPage />;
      case 'settings':
        return <SettingsPage />;
      default:
        return <SearchPage />;
    }
  };

  return (
    <AppProvider>
      <View style={styles.container}>
        <StatusBar style="light" />
        <Navigation 
          currentPage={currentPage}
          onNavigate={setCurrentPage}
        />
        <View style={styles.content}>
          {renderPage()}
        </View>
      </View>
    </AppProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f6fa',
  },
  content: {
    flex: 1,
    maxWidth: Platform.OS === 'web' ? 1200 : '100%',
    width: '100%',
    alignSelf: 'center',
  },
});
