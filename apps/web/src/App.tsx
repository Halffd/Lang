import React, { useState } from 'react';
import { Platform } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { NativeBaseProvider, Box, useColorModeValue } from 'native-base';
import Navigation from './components/Navigation';
import SearchPage from './pages/SearchPage';
import SettingsPage from './pages/SettingsPage';
import { AppProvider } from './context/AppContext';
import { TokenizerProvider } from './context/TokenizerContext';
import theme from './styles/theme';

export default function App() {
  const [currentPage, setCurrentPage] = useState('search');

  return (
    <NativeBaseProvider theme={theme}>
      <AppProvider>
        <TokenizerProvider>
          <AppContent 
            currentPage={currentPage}
            onNavigate={setCurrentPage}
          />
        </TokenizerProvider>
      </AppProvider>
    </NativeBaseProvider>
  );
}

function AppContent({ currentPage, onNavigate }: { currentPage: string, onNavigate: (page: string) => void }) {
  const bgColor = useColorModeValue('gray.50', 'gray.900');
  const navBgColor = useColorModeValue('white', 'gray.800');
  
  return (
    <Box flex={1} bg={bgColor}>
      <Box 
        bg={navBgColor}
        borderBottomWidth={1}
        borderBottomColor={useColorModeValue('gray.200', 'gray.700')}
        safeAreaTop={Platform.OS !== 'web'}
      >
        <Navigation 
          currentPage={currentPage}
          onNavigate={onNavigate}
        />
      </Box>
      
      <Box 
        flex={1}
        width="100%"
        maxWidth={Platform.OS === 'web' ? "100%" : "95%"}
        alignSelf="center"
        px={Platform.OS === 'web' ? 0 : 4}
      >
        {renderPage()}
      </Box>
      
      <StatusBar style={Platform.OS === 'web' ? 'dark' : 'light'} />
    </Box>
  );
  
  function renderPage() {
    switch (currentPage) {
      case 'search':
        return <SearchPage />;
      case 'settings':
        return <SettingsPage />;
      default:
        return <SearchPage />;
    }
  }
}
