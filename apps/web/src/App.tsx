import React, { useState } from 'react';
import { Platform } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { NativeBaseProvider, Box, useColorModeValue, useBreakpointValue } from 'native-base';
import Navigation from './components/Navigation';
import SearchPage from './pages/SearchPage';
import SettingsPage from './pages/SettingsPage';
import { AppProvider } from './context/AppContext';
import theme from './styles/theme';

export default function App() {
  const [currentPage, setCurrentPage] = useState('search');

  return (
    <NativeBaseProvider theme={theme}>
      <AppProvider>
        <AppContent 
          currentPage={currentPage}
          onNavigate={setCurrentPage}
        />
      </AppProvider>
    </NativeBaseProvider>
  );
}

// Separate component to use NativeBase hooks inside
function AppContent({ currentPage, onNavigate }: { currentPage: string, onNavigate: (page: string) => void }) {
  const bgColor = useColorModeValue('background.default', 'gray.900');
  
  // Platform-specific container width
  const containerWidth = Platform.OS === 'web' ? '100%' : '95%';
  
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
    <Box 
      flex={1} 
      bg={bgColor}
      safeArea={Platform.OS !== 'web'} // Only use SafeAreaView on mobile
    >
      <StatusBar style={Platform.OS === 'web' ? 'dark' : 'light'} />
      <Navigation 
        currentPage={currentPage}
        onNavigate={onNavigate}
      />
      <Box 
        flex={1}
        width={containerWidth}
        alignSelf="center"
      >
        {renderPage()}
      </Box>
    </Box>
  );
}
