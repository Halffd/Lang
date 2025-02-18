import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';

interface HistoryItem {
  text: string;
  timestamp: number;
}

interface Note {
  id: string;
  word: string;
  content: string;
  timestamp: number;
}

interface AppContextType {
  history: HistoryItem[];
  notes: Note[];
  addToHistory: (text: string) => void;
  clearHistory: () => void;
  addNote: (word: string, content: string) => void;
  updateNote: (id: string, content: string) => void;
  deleteNote: (id: string) => void;
  getNoteForWord: (word: string) => Note | undefined;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export function AppProvider({ children }: { children: ReactNode }) {
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [notes, setNotes] = useState<Note[]>([]);

  // Load history and notes from localStorage on mount
  useEffect(() => {
    try {
      const savedHistory = localStorage.getItem('searchHistory');
      if (savedHistory) {
        setHistory(JSON.parse(savedHistory));
      }

      const savedNotes = localStorage.getItem('notes');
      if (savedNotes) {
        setNotes(JSON.parse(savedNotes));
      }
    } catch (error) {
      console.error('Failed to load data from localStorage:', error);
    }
  }, []);

  // Save history and notes to localStorage when they change
  useEffect(() => {
    try {
      localStorage.setItem('searchHistory', JSON.stringify(history));
    } catch (error) {
      console.error('Failed to save history:', error);
    }
  }, [history]);

  useEffect(() => {
    try {
      localStorage.setItem('notes', JSON.stringify(notes));
    } catch (error) {
      console.error('Failed to save notes:', error);
    }
  }, [notes]);

  const addToHistory = (text: string) => {
    if (!text.trim()) return;
    
    setHistory(prev => {
      const newHistory = [
        { text, timestamp: Date.now() },
        ...prev.filter(item => item.text !== text)
      ].slice(0, 10);
      return newHistory;
    });
  };

  const clearHistory = () => {
    setHistory([]);
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

  const getNoteForWord = (word: string) => {
    return notes.find(note => note.word === word);
  };

  const value = {
    history,
    notes,
    addToHistory,
    clearHistory,
    addNote,
    updateNote,
    deleteNote,
    getNoteForWord,
  };

  return (
    <AppContext.Provider value={value}>
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
} 