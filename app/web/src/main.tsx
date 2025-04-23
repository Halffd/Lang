import { registerRootComponent } from 'expo';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { Platform } from 'react-native';

// Import CSS for web only
import './index.css';

import App from './App';

// Use the appropriate entry point based on platform
if (Platform.OS === 'web') {
  const rootElement = document.getElementById('root');
  if (!rootElement) throw new Error('Failed to find the root element');
  
  const root = createRoot(rootElement);
  
  root.render(
    <StrictMode>
      <App />
    </StrictMode>
  );
} else {
  // For mobile platforms, use Expo's registerRootComponent
  registerRootComponent(App);
} 