import React, { memo, useState, useEffect } from 'react';
import { StyleSheet, View, Text, ScrollView, TextInput, TouchableOpacity } from 'react-native';
import { useApp } from '../context/AppContext';

interface TokenizedWord {
  word: string;
  reading?: string;
  definitions: string[];
  translations?: string[];
  pos?: string;
  frequency?: number;
}

interface ResultDetailsProps {
  word: TokenizedWord;
}

export const ResultDetails = memo(function ResultDetails({ word }: ResultDetailsProps) {
  const { getNoteForWord, addNote, updateNote } = useApp();
  const [noteContent, setNoteContent] = useState('');
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    const existingNote = getNoteForWord(word.word);
    if (existingNote) {
      setNoteContent(existingNote.content);
    } else {
      setNoteContent('');
    }
  }, [word.word, getNoteForWord]);

  const handleSaveNote = () => {
    const existingNote = getNoteForWord(word.word);
    if (existingNote) {
      updateNote(existingNote.id, noteContent);
    } else {
      addNote(word.word, noteContent);
    }
    setIsEditing(false);
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.wordText}>{word.word}</Text>
        {word.reading && (
          <Text style={styles.readingText}>（{word.reading}）</Text>
        )}
      </View>

      {word.definitions.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Definitions</Text>
          {word.definitions.map((def, index) => (
            <View key={index} style={styles.definitionItem}>
              <Text style={styles.bulletPoint}>•</Text>
              <Text style={styles.definitionText}>{def}</Text>
            </View>
          ))}
        </View>
      )}

      {word.translations && word.translations.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Translations</Text>
          {word.translations.map((trans, index) => (
            <View key={index} style={styles.definitionItem}>
              <Text style={styles.bulletPoint}>•</Text>
              <Text style={styles.definitionText}>{trans}</Text>
            </View>
          ))}
        </View>
      )}

      <View style={styles.metaSection}>
        {word.pos && (
          <View style={styles.metaItem}>
            <Text style={styles.metaLabel}>Part of Speech:</Text>
            <Text style={styles.metaValue}>{word.pos}</Text>
          </View>
        )}
        {word.frequency != null && (
          <View style={styles.metaItem}>
            <Text style={styles.metaLabel}>Frequency:</Text>
            <Text style={styles.metaValue}>{Math.round(word.frequency)}%</Text>
          </View>
        )}
      </View>

      <View style={styles.notesSection}>
        <View style={styles.notesHeader}>
          <Text style={styles.sectionTitle}>Notes</Text>
          <TouchableOpacity
            style={styles.editButton}
            onPress={() => setIsEditing(!isEditing)}
          >
            <Text style={styles.editButtonText}>
              {isEditing ? 'Cancel' : 'Edit'}
            </Text>
          </TouchableOpacity>
        </View>

        {isEditing ? (
          <View style={styles.editContainer}>
            <TextInput
              style={styles.noteInput}
              value={noteContent}
              onChangeText={setNoteContent}
              multiline
              placeholder="Add your notes here..."
              placeholderTextColor="#999"
            />
            <TouchableOpacity
              style={styles.saveButton}
              onPress={handleSaveNote}
            >
              <Text style={styles.saveButtonText}>Save</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <Text style={styles.noteText}>
            {noteContent || 'No notes yet. Click Edit to add notes.'}
          </Text>
        )}
      </View>
    </ScrollView>
  );
});

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    gap: 8,
  },
  wordText: {
    fontSize: 24,
    fontWeight: '700',
    color: '#2c3e50',
  },
  readingText: {
    fontSize: 20,
    color: '#666',
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#2c3e50',
    marginBottom: 8,
  },
  definitionItem: {
    flexDirection: 'row',
    paddingVertical: 4,
    paddingHorizontal: 8,
  },
  bulletPoint: {
    fontSize: 16,
    color: '#666',
    marginRight: 8,
  },
  definitionText: {
    flex: 1,
    fontSize: 16,
    color: '#2c3e50',
    lineHeight: 24,
  },
  metaSection: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 20,
  },
  metaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  metaLabel: {
    fontSize: 14,
    color: '#666',
    width: 120,
  },
  metaValue: {
    fontSize: 14,
    color: '#2c3e50',
    fontWeight: '500',
  },
  notesSection: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 12,
  },
  notesHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  editButton: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
    backgroundColor: '#e3f2fd',
  },
  editButtonText: {
    color: '#1976d2',
    fontSize: 14,
    fontWeight: '500',
  },
  editContainer: {
    gap: 12,
  },
  noteInput: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    minHeight: 100,
    fontSize: 16,
    color: '#2c3e50',
    textAlignVertical: 'top',
    borderWidth: 1,
    borderColor: '#e1e4e8',
  },
  saveButton: {
    backgroundColor: '#4CAF50',
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  saveButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  noteText: {
    fontSize: 16,
    color: '#2c3e50',
    lineHeight: 24,
  },
}); 