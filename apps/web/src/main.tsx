import React from 'react';
import { createRoot } from 'react-dom/client';
import { registerRootComponent } from 'expo';
import { Platform } from 'react-native';
import App from './App';
import './index.css';

// Register the app for mobile platforms
if (Platform.OS !== 'web') {
  registerRootComponent(App);
}

// For web platform, use standard React DOM rendering
if (Platform.OS === 'web') {
  const rootElement = document.getElementById('root');
  if (rootElement) {
    const root = createRoot(rootElement);
    root.render(
      <React.StrictMode>
        <App />
      </React.StrictMode>
    );
  }
} 