import React, { createContext, useContext, useState, ReactNode } from 'react';

interface Settings {
  showFurigana: boolean;
  autoConvert: boolean;
  clipboardMonitor: boolean;
}

interface AppContextType {
  settings: Settings;
  updateSettings: (key: keyof Settings, value: boolean) => void;
}

const defaultSettings: Settings = {
  showFurigana: true,
  autoConvert: true,
  clipboardMonitor: false,
};

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [settings, setSettings] = useState<Settings>(defaultSettings);

  const updateSettings = (key: keyof Settings, value: boolean) => {
    setSettings((prev) => ({
      ...prev,
      [key]: value,
    }));
  };

  return (
    <AppContext.Provider value={{ settings, updateSettings }}>
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}; 