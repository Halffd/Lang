import React from 'react';
import { AppProvider } from './src/context/AppContext';
import App from './src/App';

export default function WebPage(): React.ReactElement {
  return (
    <AppProvider>
      <App />
    </AppProvider>
  );
}
