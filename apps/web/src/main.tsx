import { registerRootComponent } from 'expo';
import { Platform } from 'react-native';
import App from './App';

// Register the app for mobile platforms
if (Platform.OS !== 'web') {
  registerRootComponent(App);
}

// For web platform, use standard React DOM rendering
if (Platform.OS === 'web') {
  const root = document.getElementById('root');
  if (root) {
    // @ts-ignore - Expo's web support
    const { createRoot } = require('react-dom/client');
    const appRoot = createRoot(root);
    appRoot.render(<App />);
  }
} 