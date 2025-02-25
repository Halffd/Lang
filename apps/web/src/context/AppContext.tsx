import React, { createContext, useContext, useState, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Note } from '../types';

interface AppContextType {
  history: string[];
  addToHistory: (text: string) => void;
  clearHistory: () => void;
  settings: {
    showFurigana: boolean;
    autoConvert: boolean;
    clipboardMonitor: boolean;
  };
  updateSettings: (key: keyof AppContextType['settings'], value: boolean) => void;
  notes: Note[];
  getNoteForWord: (word: string) => Note | undefined;
  addNote: (word: string, content: string) => void;
  updateNote: (id: string, content: string) => void;
  deleteNote: (id: string) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [history, setHistory] = useState<string[]>([]);
  const [notes, setNotes] = useState<Note[]>([]);
  const [settings, setSettings] = useState({
    showFurigana: true,
    autoConvert: true,
    clipboardMonitor: false,
  });

  // Load data from AsyncStorage on mount
  useEffect(() => {
    const loadHistory = async () => {
      try {
        const savedHistory = await AsyncStorage.getItem('searchHistory');
        if (savedHistory) {
          setHistory(JSON.parse(savedHistory));
        }
      } catch (error) {
        console.error('Failed to load history:', error);
      }
    };

    const loadSettings = async () => {
      try {
        const savedSettings = await AsyncStorage.getItem('appSettings');
        if (savedSettings) {
          setSettings(JSON.parse(savedSettings));
        }
      } catch (error) {
        console.error('Failed to load settings:', error);
      }
    };

    const loadNotes = async () => {
      try {
        const savedNotes = await AsyncStorage.getItem('notes');
        if (savedNotes) {
          setNotes(JSON.parse(savedNotes));
        }
      } catch (error) {
        console.error('Failed to load notes:', error);
      }
    };

    loadHistory();
    loadSettings();
    loadNotes();
  }, []);

  // Save history to AsyncStorage whenever it changes
  useEffect(() => {
    const saveHistory = async () => {
      try {
        await AsyncStorage.setItem('searchHistory', JSON.stringify(history));
      } catch (error) {
        console.error('Failed to save history:', error);
      }
    };

    saveHistory();
  }, [history]);

  // Save settings to AsyncStorage whenever they change
  useEffect(() => {
    const saveSettings = async () => {
      try {
        await AsyncStorage.setItem('appSettings', JSON.stringify(settings));
      } catch (error) {
        console.error('Failed to save settings:', error);
      }
    };

    saveSettings();
  }, [settings]);

  // Save notes to AsyncStorage whenever they change
  useEffect(() => {
    const saveNotes = async () => {
      try {
        await AsyncStorage.setItem('notes', JSON.stringify(notes));
      } catch (error) {
        console.error('Failed to save notes:', error);
      }
    };

    saveNotes();
  }, [notes]);

  const addToHistory = (text: string) => {
    if (!text.trim()) return;
    
    setHistory(prev => {
      // Remove duplicates and add to the beginning
      const newHistory = [text, ...prev.filter(item => item !== text)];
      // Limit to 20 items
      return newHistory.slice(0, 20);
    });
  };

  const clearHistory = () => {
    setHistory([]);
  };

  const updateSettings = (key: keyof typeof settings, value: boolean) => {
    setSettings(prev => ({
      ...prev,
      [key]: value,
    }));
  };

  // Note-related methods
  const getNoteForWord = (word: string) => {
    return notes.find(note => note.word === word);
  };

  const addNote = (word: string, content: string) => {
    const newNote: Note = {
      id: Date.now().toString(),
      word,
      content,
      timestamp: Date.now(),
    };
    
    setNotes(prev => [...prev, newNote]);
  };

  const updateNote = (id: string, content: string) => {
    setNotes(prev => 
      prev.map(note => 
        note.id === id 
          ? { ...note, content, timestamp: Date.now() } 
          : note
      )
    );
  };

  const deleteNote = (id: string) => {
    setNotes(prev => prev.filter(note => note.id !== id));
  };

  return (
    <AppContext.Provider
      value={{
        history,
        addToHistory,
        clearHistory,
        settings,
        updateSettings,
        notes,
        getNoteForWord,
        addNote,
        updateNote,
        deleteNote,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = (): AppContextType => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}; 