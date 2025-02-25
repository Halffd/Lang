import { useCallback, useEffect, useRef, useState, useDebugValue } from 'react';
import { useApp } from '../context/AppContext';

interface NoteState {
  mined: [number, number, string[], string[]];
  vars: Record<string, any>;
  isDebugMode: boolean;
}

interface SavedNote {
  word: string;
  reading?: string;
  sentence: string;
  definition: string;
  frequency: string;
  type: "keep" | "words";
  learning: number;
  clipboard: string;
  status: number;
  time: string;
  params: string;
}

export function useNote(initialDebugMode = false) {
  const { addToHistory } = useApp();
  const [state, setState] = useState<NoteState>({
    mined: [0, 0, [], []],
    vars: {},
    isDebugMode: initialDebugMode
  });

  const abortControllerRef = useRef<AbortController | null>(null);

  // Debug value to show current mining stats
  useDebugValue(
    state.mined,
    (mined) => `Mined: ${mined[0]}, Words: ${mined[1]}, Unique: ${mined[2].length}`
  );

  const debug = useCallback((message: string, data?: any) => {
    if (state.isDebugMode) {
      console.log(`[Note Debug] ${message}`, data);
    }
  }, [state.isDebugMode]);

  const setDebugMode = useCallback((enabled: boolean) => {
    setState(prev => ({ ...prev, isDebugMode: enabled }));
    debug(`Debug mode ${enabled ? 'enabled' : 'disabled'}`);
  }, [debug]);

  const getter = useCallback(async (key: string): Promise<string | null> => {
    debug('Getting value for key', key);
    try {
      const value = localStorage.getItem(key);
      if (value === '[object Object]') {
        return '{}';
      }
      return value;
    } catch (error) {
      debug('Error getting value', error);
      return null;
    }
  }, [debug]);

  const setter = useCallback(async (key: string, value: string): Promise<void> => {
    debug('Setting value for key', { key, value });
    try {
      localStorage.setItem(key, value);
      setState(prev => ({
        ...prev,
        vars: { ...prev.vars, [key]: value }
      }));
    } catch (error) {
      debug('Error setting value', error);
    }
  }, [debug]);

  const saveNote = useCallback(async (
    word: string,
    sentence: string,
    definition = '',
    frequencies: number[] = [],
    tags: string[] = [],
    html = '',
    isMoe = false,
    audio: string[] = [],
    image: string[] = [],
    clipboard = '',
    isYomikata = false,
    reading = '',
    element: HTMLElement | null = null,
    keys: [boolean, boolean] = [false, false]
  ) => {
    debug('Saving note', { word, sentence });

    try {
      const timestamp = Math.floor(Date.now() / 1000);
      const dateString = new Date().toLocaleString('pt-BR', {
        year: 'numeric',
        month: 'numeric',
        day: 'numeric',
        weekday: 'short',
        hour: 'numeric',
        minute: 'numeric',
        second: 'numeric',
        timeZone: 'America/Sao_Paulo',
        timeZoneName: 'short'
      }).replaceAll(',', '');

      const frequencyMedian = frequencies.length > 0 
        ? frequencies.reduce((a, b) => a + b, 0) / frequencies.length 
        : 0;

      const note: SavedNote = {
        word,
        reading,
        sentence,
        definition,
        frequency: frequencies.join(' '),
        type: keys[0] ? "keep" : "words",
        learning: 0,
        clipboard: clipboard?.substring(0, 5) === sentence.substring(0, 5) 
          ? '' 
          : clipboard?.substring(0, 80),
        status: 1,
        time: dateString,
        params: `Yc:${isYomikata} Keys:${keys.join(',')}`
      };

      const savedNotes = await getter('save');
      const notes = savedNotes ? JSON.parse(savedNotes) : {};
      
      const updatedNotes = {
        ...notes,
        [timestamp]: note
      };

      await setter('save', JSON.stringify(updatedNotes));
      
      if (element) {
        element.style.borderColor = keys[0] ? 'aqua' : 'lime';
      }

      // Update mining stats
      setState(prev => {
        const newMined = [...prev.mined] as NoteState['mined'];
        if (!newMined[2].includes(word)) {
          newMined[0]++;
          newMined[2].push(word);
        }
        return { ...prev, mined: newMined };
      });

      debug('Note saved successfully', note);
      return true;
    } catch (error) {
      debug('Error saving note', error);
      return false;
    }
  }, [debug, getter, setter]);

  const findNotes = useCallback(async (
    query = '',
    property: keyof SavedNote = 'word',
    comparison = '='
  ) => {
    debug('Finding notes', { query, property, comparison });
    
    try {
      const savedNotes = await getter('save');
      if (!savedNotes) return null;

      const notes = JSON.parse(savedNotes);
      const results: SavedNote[] = [];
      const indices: string[] = [];

      for (const [index, note] of Object.entries(notes)) {
        const item = note as SavedNote;
        let match = false;

        if (!query) {
          match = true;
        } else if (property in item) {
          const value = item[property];
          if (typeof value === 'string' && comparison === 'search') {
            match = value.includes(query);
          } else {
            match = value === query;
          }
        }

        if (match) {
          indices.push(index);
          results.push(item);
        }
      }

      debug('Found notes', { count: results.length });
      return results.length ? [results, indices] : null;
    } catch (error) {
      debug('Error finding notes', error);
      return null;
    }
  }, [debug, getter]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (abortControllerRef.current) {
        abortControllerRef.current.abort();
      }
    };
  }, []);

  return {
    saveNote,
    findNotes,
    getter,
    setter,
    mined: state.mined,
    isDebugMode: state.isDebugMode,
    setDebugMode,
    debug
  };
} 