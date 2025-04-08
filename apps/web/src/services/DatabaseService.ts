import sqlite3 from 'sqlite3';
import { open } from 'sqlite';
import { 
  SearchResult, 
  DictionaryEntry, 
  ImportProgress,
  Example,
  TagGroup 
} from '../types';
import { Platform } from 'react-native';
import * as FileSystem from 'expo-file-system';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { tokenizerService, TokenizedWord } from './TokenizerService';

// Declare electron interface for desktop
declare global {
  interface Window {
    electron?: {
      getUserDataPath: () => string;
    };
  }
}

// Type declarations for better type safety
interface YomichanDictionary {
  format: number;
  revision: string;
  sequenced?: boolean;
  title: string;
  entries: Array<{
    type: 'term' | 'kanji';
    expression: string;
    reading?: string;
    definitions: string[];
    tags?: string[];
    rules?: string[];
    score?: number;
    sequence?: number;
  }>;
}

interface DictionaryStatus {
  title: string;
  enabled: boolean;
  format: number;
  revision: string;
  entryCount: number;
}

interface FrequencyEntry {
  word: string;
  rank?: number;
  frequency?: number;
  tags?: string[];
}

interface ExampleSentence {
  japanese: string;
  english: string;
  tags?: string[];
  source?: string;
}

interface DictionaryMetadata {
  title: string;
  format: string | number;
  revision: string;
  sequenced?: boolean;
}

class DatabaseService {
  private db: any;
  private initialized: boolean = false;
  private dbPath: string;

  constructor() {
    this.dbPath = this.getDatabasePath();
  }

  private getDatabasePath(): string {
    if (Platform.OS === 'web') {
      return '/data/dictionary.db'; // Will be stored in IndexedDB
    } else if (Platform.OS === 'ios' || Platform.OS === 'android') {
      return `${FileSystem.documentDirectory}dictionary.db`;
    } else {
      // Desktop (Electron)
      const userDataPath = window.electron?.getUserDataPath() || '.';
      return `${userDataPath}/dictionary.db`;
    }
  }

  async initialize() {
    if (this.initialized) return;

    // Ensure directory exists for non-web platforms
    if (Platform.OS !== 'web') {
      const dir = this.dbPath.substring(0, this.dbPath.lastIndexOf('/'));
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
    }

    this.db = await open({
      filename: this.dbPath,
      driver: sqlite3.Database
    });

    // Create tables if they don't exist
    await this.db.exec(`
      CREATE TABLE IF NOT EXISTS dictionaries (
        title TEXT PRIMARY KEY,
        format INTEGER NOT NULL,
        revision TEXT NOT NULL,
        sequenced BOOLEAN DEFAULT 0,
        enabled BOOLEAN DEFAULT 1,
        priority INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS words (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        reading TEXT,
        pos TEXT,
        frequency REAL,
        frequency_source TEXT,
        dictionary TEXT,
        tags TEXT,
        FOREIGN KEY (dictionary) REFERENCES dictionaries(title)
      );

      CREATE TABLE IF NOT EXISTS definitions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id TEXT,
        definition TEXT NOT NULL,
        tags TEXT,
        FOREIGN KEY (word_id) REFERENCES words(id)
      );

      CREATE TABLE IF NOT EXISTS examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id TEXT,
        japanese TEXT NOT NULL,
        english TEXT NOT NULL,
        tags TEXT,
        complexity_metrics TEXT,
        jlpt_level TEXT,
        grammar_points TEXT,
        FOREIGN KEY (word_id) REFERENCES words(id)
      );

      CREATE TABLE IF NOT EXISTS frequency_lists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        priority INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS word_frequencies (
        word TEXT NOT NULL,
        frequency_list_id TEXT NOT NULL,
        rank INTEGER,
        frequency REAL,
        PRIMARY KEY (word, frequency_list_id),
        FOREIGN KEY (frequency_list_id) REFERENCES frequency_lists(id)
      );

      CREATE VIRTUAL TABLE IF NOT EXISTS word_fts USING fts5(
        word,
        reading,
        definition,
        tags
      );

      CREATE TABLE IF NOT EXISTS tag_groups (
        name TEXT PRIMARY KEY,
        description TEXT,
        priority INTEGER DEFAULT 0
      );

      CREATE TABLE IF NOT EXISTS tag_group_entries (
        group_name TEXT,
        tag TEXT,
        PRIMARY KEY (group_name, tag),
        FOREIGN KEY (group_name) REFERENCES tag_groups(name)
      );

      CREATE TABLE IF NOT EXISTS jlpt_assignments (
        word TEXT PRIMARY KEY,
        level TEXT NOT NULL,
        confidence REAL DEFAULT 1.0,
        source TEXT
      );

      -- Create indexes for better performance
      CREATE INDEX IF NOT EXISTS idx_words_word ON words(word);
      CREATE INDEX IF NOT EXISTS idx_words_reading ON words(reading);
      CREATE INDEX IF NOT EXISTS idx_words_dictionary ON words(dictionary);
      CREATE INDEX IF NOT EXISTS idx_word_frequencies_word ON word_frequencies(word);
      CREATE INDEX IF NOT EXISTS idx_jlpt_assignments_level ON jlpt_assignments(level);
      CREATE INDEX IF NOT EXISTS idx_tag_group_entries_tag ON tag_group_entries(tag);
    `);

    // Initialize default tag groups if they don't exist
    await this.initializeDefaultTagGroups();

    this.initialized = true;
  }

  private async initializeDefaultTagGroups(): Promise<void> {
    const defaultGroups: Array<{ name: string; description: string; tags: string[] }> = [
      {
        name: 'JLPT',
        description: 'Japanese Language Proficiency Test levels',
        tags: ['jlpt-n5', 'jlpt-n4', 'jlpt-n3', 'jlpt-n2', 'jlpt-n1']
      },
      {
        name: 'Parts of Speech',
        description: 'Grammatical categories',
        tags: ['noun', 'verb', 'adjective', 'adverb', 'particle', 'expression']
      },
      {
        name: 'Usage',
        description: 'Word usage categories',
        tags: ['formal', 'informal', 'written', 'spoken', 'literary', 'slang']
      },
      {
        name: 'Difficulty',
        description: 'Word difficulty levels',
        tags: ['beginner', 'intermediate', 'advanced', 'common', 'rare']
      }
    ];

    await this.db.run('BEGIN TRANSACTION');
    try {
      for (const group of defaultGroups) {
        await this.db.run(
          'INSERT OR IGNORE INTO tag_groups (name, description) VALUES (?, ?)',
          [group.name, group.description]
        );

        for (const tag of group.tags) {
          await this.db.run(
            'INSERT OR IGNORE INTO tag_group_entries (group_name, tag) VALUES (?, ?)',
            [group.name, tag]
          );
        }
      }
      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async createTagGroup(name: string, description: string, tags: string[]): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');

    try {
      await this.db.run(
        'INSERT INTO tag_groups (name, description) VALUES (?, ?)',
        [name, description]
      );

      for (const tag of tags) {
        await this.db.run(
          'INSERT INTO tag_group_entries (group_name, tag) VALUES (?, ?)',
          [name, tag]
        );
      }

      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async getTagGroups(): Promise<TagGroup[]> {
    await this.initialize();

    const groups = await this.db.all('SELECT name, description FROM tag_groups ORDER BY priority DESC');
    const result: TagGroup[] = [];

    for (const group of groups) {
      const tags = await this.db.all(
        'SELECT tag FROM tag_group_entries WHERE group_name = ? ORDER BY tag',
        [group.name]
      ) as Array<{ tag: string }>;
      result.push({
        name: group.name,
        description: group.description,
        tags: tags.map((t: { tag: string }) => t.tag)
      });
    }

    return result;
  }

  async assignJLPTLevel(word: string, level: string, confidence: number = 1.0, source: string = 'auto'): Promise<void> {
    await this.initialize();
    
    await this.db.run(
      'INSERT OR REPLACE INTO jlpt_assignments (word, level, confidence, source) VALUES (?, ?, ?, ?)',
      [word, level, confidence, source]
    );

    // Add JLPT tag to the word
    const wordId = await this.db.get('SELECT id FROM words WHERE word = ?', [word]);
    if (wordId) {
      await this.addTags(wordId.id, [`jlpt-${level.toLowerCase()}`]);
    }
  }

  async autoAssignJLPTLevels(): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');

    try {
      // Get words without JLPT assignments
      const words = await this.db.all(`
        SELECT DISTINCT w.word, w.frequency
        FROM words w
        LEFT JOIN jlpt_assignments ja ON w.word = ja.word
        WHERE ja.word IS NULL
      `);

      for (const word of words) {
        let level: string;
        const freq = word.frequency || 0;

        // Assign JLPT levels based on frequency
        // These thresholds can be adjusted based on your data
        if (freq >= 0.8) level = 'N5';
        else if (freq >= 0.6) level = 'N4';
        else if (freq >= 0.4) level = 'N3';
        else if (freq >= 0.2) level = 'N2';
        else level = 'N1';

        await this.assignJLPTLevel(word.word, level, 0.7, 'frequency-based');
      }

      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async getJLPTLevel(word: string): Promise<{ level: string; confidence: number } | null> {
    await this.initialize();
    
    const result = await this.db.get(
      'SELECT level, confidence FROM jlpt_assignments WHERE word = ?',
      [word]
    );

    return result ? { level: result.level, confidence: result.confidence } : null;
  }

  async importDictionary(
    dictionaryInfo: DictionaryMetadata,
    entries: DictionaryEntry[],
    onProgress?: (progress: ImportProgress) => void
  ): Promise<void> {
    await this.initialize();

    // Start transaction
    await this.db.run('BEGIN TRANSACTION');

    try {
      // Add dictionary info
      await this.db.run(
        'INSERT OR REPLACE INTO dictionaries (title, format, revision, sequenced) VALUES (?, ?, ?, ?)',
        [dictionaryInfo.title, dictionaryInfo.format, dictionaryInfo.revision, dictionaryInfo.sequenced ? 1 : 0]
      );

      const total = entries.length;
      for (let i = 0; i < total; i++) {
        const entry = entries[i];
        if (entry.type === 'term') {
          const wordId = `${dictionaryInfo.title}:${entry.expression}:${entry.reading || ''}`;
          
          // Add word
          await this.db.run(
            'INSERT OR REPLACE INTO words (id, word, reading, dictionary) VALUES (?, ?, ?, ?)',
            [wordId, entry.expression, entry.reading, dictionaryInfo.title]
          );

          // Add definitions
          await Promise.all(entry.definitions.map((def: string) =>
            this.db.run(
              'INSERT INTO definitions (word_id, definition) VALUES (?, ?)',
              [wordId, def]
            )
          ));

          // Update FTS
          await this.db.run(
            'INSERT INTO word_fts (word, reading, definition) VALUES (?, ?, ?)',
            [entry.expression, entry.reading, entry.definitions.join(' ')]
          );
        }

        if (onProgress) {
          onProgress({
            type: 'import',
            percent: Math.round((i + 1) / total * 100),
            processed: i + 1,
            total
          });
        }
      }

      // Commit transaction
      await this.db.run('COMMIT');
    } catch (error) {
      // Rollback on error
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async importFromJson(fileContent: string, onProgress?: (progress: ImportProgress) => void): Promise<void> {
    let dictionary: YomichanDictionary;
    try {
      dictionary = JSON.parse(fileContent);
    } catch (error) {
      throw new Error('Invalid dictionary file format');
    }

    if (!dictionary.format || !dictionary.title || !Array.isArray(dictionary.entries)) {
      throw new Error('Invalid Yomichan dictionary format');
    }

    // Convert entries to ensure reading is always a string
    const convertedEntries: DictionaryEntry[] = dictionary.entries.map(entry => ({
      ...entry,
      reading: entry.reading || entry.expression
    }));

    await this.importDictionary(
      {
        title: dictionary.title,
        format: dictionary.format,
        revision: dictionary.revision,
        sequenced: dictionary.sequenced
      },
      convertedEntries,
      onProgress
    );
  }

  async listDictionaries(): Promise<DictionaryStatus[]> {
    await this.initialize();
    
    const results = await this.db.all(`
      SELECT 
        d.title,
        d.format,
        d.revision,
        d.enabled,
        COUNT(w.id) as entryCount
      FROM dictionaries d
      LEFT JOIN words w ON w.dictionary = d.title
      GROUP BY d.title
    `);

    return results.map((row: any) => ({
      title: row.title,
      enabled: Boolean(row.enabled),
      format: row.format,
      revision: row.revision,
      entryCount: row.entryCount
    }));
  }

  async setDictionaryEnabled(title: string, enabled: boolean): Promise<void> {
    await this.initialize();
    await this.db.run(
      'UPDATE dictionaries SET enabled = ? WHERE title = ?',
      [enabled ? 1 : 0, title]
    );
  }

  async deleteDictionary(title: string): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');
    
    try {
      // Delete all related data first
      await this.db.run('DELETE FROM examples WHERE word_id IN (SELECT id FROM words WHERE dictionary = ?)', [title]);
      await this.db.run('DELETE FROM definitions WHERE word_id IN (SELECT id FROM words WHERE dictionary = ?)', [title]);
      await this.db.run('DELETE FROM words WHERE dictionary = ?', [title]);
      await this.db.run('DELETE FROM dictionaries WHERE title = ?', [title]);
      
      // Rebuild FTS index
      await this.db.run('DELETE FROM word_fts');
      await this.db.run(`
        INSERT INTO word_fts (word, reading, definition)
        SELECT w.word, w.reading, GROUP_CONCAT(d.definition, ' ')
        FROM words w
        LEFT JOIN definitions d ON w.id = d.word_id
        GROUP BY w.id
      `);
      
      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async updateFrequencyData(entries: Array<{ word: string; frequency: number }>): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');
    
    try {
      for (const entry of entries) {
        await this.db.run(
          'UPDATE words SET frequency = ? WHERE word = ?',
          [entry.frequency, entry.word]
        );
      }
      
      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async search(query: string): Promise<SearchResult[]> {
    await this.initialize();

    const results = await this.db.all(`
      SELECT DISTINCT
        w.id,
        w.word,
        w.reading,
        w.pos,
        w.frequency,
        w.dictionary,
        GROUP_CONCAT(DISTINCT d.definition) as definitions,
        json_group_array(json_object('japanese', e.japanese, 'english', e.english)) as examples
      FROM word_fts fts
      JOIN words w ON fts.word = w.word
      JOIN dictionaries dict ON w.dictionary = dict.title
      LEFT JOIN definitions d ON w.id = d.word_id
      LEFT JOIN examples e ON w.id = e.word_id
      WHERE word_fts MATCH ? AND dict.enabled = 1
      GROUP BY w.id
      ORDER BY w.frequency DESC NULLS LAST
      LIMIT 50
    `, query);

    return results.map((row: any) => ({
      id: row.id,
      word: row.word,
      reading: row.reading,
      definitions: row.definitions?.split(',') || [],
      pos: row.pos,
      frequency: row.frequency,
      examples: JSON.parse(row.examples).filter((ex: any) => ex.japanese !== null),
      dictionary: row.dictionary
    }));
  }

  async addWord(word: SearchResult) {
    await this.initialize();

    await this.db.run(
      'INSERT OR REPLACE INTO words (id, word, reading, pos, frequency) VALUES (?, ?, ?, ?, ?)',
      [word.id, word.word, word.reading, word.pos, word.frequency]
    );

    if (word.definitions) {
      await Promise.all(word.definitions.map((def: string) =>
        this.db.run(
          'INSERT INTO definitions (word_id, definition) VALUES (?, ?)',
          [word.id, def]
        )
      ));
    }

    if (word.examples) {
      await Promise.all(word.examples.map((ex: Example) =>
        this.db.run(
          'INSERT INTO examples (word_id, japanese, english) VALUES (?, ?, ?)',
          [word.id, ex.japanese, ex.english]
        )
      ));
    }

    // Update FTS table
    await this.db.run(
      'INSERT INTO word_fts (word, reading, definition) VALUES (?, ?, ?)',
      [
        word.word,
        word.reading,
        word.definitions?.join(' ')
      ]
    );
  }

  async importFrequencyList(
    id: string,
    name: string,
    description: string,
    entries: Array<{ word: string; rank?: number; frequency?: number }>,
    onProgress?: (progress: ImportProgress) => void
  ): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');

    try {
      // Add or update frequency list info
      await this.db.run(
        'INSERT OR REPLACE INTO frequency_lists (id, name, description) VALUES (?, ?, ?)',
        [id, name, description]
      );

      // Delete existing entries for this list
      await this.db.run('DELETE FROM word_frequencies WHERE frequency_list_id = ?', [id]);

      const total = entries.length;
      for (let i = 0; i < total; i++) {
        const { word, rank, frequency } = entries[i];
        
        await this.db.run(
          'INSERT INTO word_frequencies (word, frequency_list_id, rank, frequency) VALUES (?, ?, ?, ?)',
          [word, id, rank || null, frequency || null]
        );

        // Update word frequency in words table if it's higher than existing
        await this.db.run(`
          UPDATE words 
          SET frequency = COALESCE(
            CASE 
              WHEN frequency IS NULL THEN ?
              WHEN ? > frequency THEN ?
              ELSE frequency 
            END,
            ?
          ),
          frequency_source = ?
          WHERE word = ?
        `, [frequency, frequency, frequency, frequency, id, word]);

        if (onProgress) {
          onProgress({
            type: 'frequency-import',
            percent: Math.round((i + 1) / total * 100),
            processed: i + 1,
            total
          });
        }
      }

      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async listFrequencyLists(): Promise<Array<{
    id: string;
    name: string;
    description: string;
    entryCount: number;
  }>> {
    await this.initialize();
    
    const results = await this.db.all(`
      SELECT 
        f.id,
        f.name,
        f.description,
        COUNT(wf.word) as entryCount
      FROM frequency_lists f
      LEFT JOIN word_frequencies wf ON wf.frequency_list_id = f.id
      GROUP BY f.id
    `);

    return results.map((row: any) => ({
      id: row.id,
      name: row.name,
      description: row.description,
      entryCount: row.entryCount
    }));
  }

  async deleteFrequencyList(id: string): Promise<void> {
    await this.initialize();
    await this.db.run('BEGIN TRANSACTION');
    
    try {
      // Reset frequency data for words that use this list as source
      await this.db.run(`
        UPDATE words 
        SET frequency = NULL, frequency_source = NULL 
        WHERE frequency_source = ?
      `, [id]);
      
      // Delete frequency data
      await this.db.run('DELETE FROM word_frequencies WHERE frequency_list_id = ?', [id]);
      await this.db.run('DELETE FROM frequency_lists WHERE id = ?', [id]);
      
      await this.db.run('COMMIT');
    } catch (error) {
      await this.db.run('ROLLBACK');
      throw error;
    }
  }

  async importBCCWJFrequency(fileContent: string, onProgress?: (progress: ImportProgress) => void): Promise<void> {
    const lines = fileContent.split('\n');
    const entries: FrequencyEntry[] = [];
    
    for (const line of lines) {
      const [rank, word, freq] = line.split('\t');
      if (word && !isNaN(Number(freq))) {
        entries.push({
          word,
          rank: Number(rank),
          frequency: Number(freq) / 100,
          tags: ['bccwj']
        });
      }
    }

    await this.importFrequencyList(
      'bccwj',
      'BCCWJ Frequency List',
      'Balanced Corpus of Contemporary Written Japanese',
      entries,
      onProgress
    );
  }

  async importNetflixFrequency(fileContent: string, onProgress?: (progress: ImportProgress) => void): Promise<void> {
    const lines = fileContent.split('\n');
    const entries: FrequencyEntry[] = [];
    
    for (const line of lines) {
      const [word, count] = line.split('\t');
      if (word && !isNaN(Number(count))) {
        entries.push({
          word,
          frequency: Math.log(Number(count)) / 10,
          tags: ['netflix', 'subtitles']
        });
      }
    }

    await this.importFrequencyList(
      'netflix',
      'Netflix Subtitles',
      'Word frequencies from Netflix Japanese subtitles',
      entries,
      onProgress
    );
  }

  async addExampleSentence(japanese: string, english: string, source: string, tags: string[] = []): Promise<void> {
    // Tokenize and analyze the sentence
    const tokens = await tokenizerService.findWords(japanese);
    const words = tokens.map(t => t.basic);
    const analysis = await tokenizerService.analyzeComplexity(japanese);
    
    // Add the example sentence with complexity metrics
    const result = await this.db.run(
      `INSERT INTO examples (
        japanese, 
        english, 
        source, 
        tags, 
        words,
        complexity_metrics,
        jlpt_level,
        grammar_points
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        japanese,
        english,
        source,
        JSON.stringify(tags),
        JSON.stringify(words),
        JSON.stringify({
          uniqueWords: analysis.uniqueWords,
          avgWordLength: analysis.avgWordLength,
          readingComplexity: analysis.readingComplexity,
          grammarComplexity: analysis.grammarComplexity,
          vocabularyLevel: analysis.vocabularyLevel
        }),
        analysis.jlptLevel,
        JSON.stringify(analysis.grammarPoints)
      ]
    );
    
    // Update word-to-example mappings with position information
    const exampleId = result.lastID;
    for (const token of tokens) {
      await this.db.run(
        `INSERT OR IGNORE INTO word_examples (
          word, 
          example_id, 
          position,
          reading,
          pos,
          basic_form
        ) VALUES (?, ?, ?, ?, ?, ?)`,
        [
          token.surface,
          exampleId,
          japanese.indexOf(token.surface),
          token.reading,
          token.pos,
          token.basic
        ]
      );
    }
  }

  async findExamplesForWord(
    word: string,
    options: {
      limit?: number;
      minJlptLevel?: string;
      maxJlptLevel?: string;
      grammarPoints?: string[];
      vocabularyLevel?: string;
    } = {}
  ): Promise<Example[]> {
    const {
      limit = 10,
      minJlptLevel,
      maxJlptLevel,
      grammarPoints,
      vocabularyLevel
    } = options;

    // Get dictionary form of the word
    const tokens = await tokenizerService.tokenize(word);
    const dictionaryForm = tokens[0]?.basic || word;
    
    let query = `
      SELECT e.* FROM examples e
      JOIN word_examples we ON e.id = we.example_id
      WHERE we.word = ? OR we.basic_form = ?
    `;
    
    const params: (string | number)[] = [word, dictionaryForm];
    
    // Add JLPT level filters
    if (minJlptLevel) {
      query += ` AND e.jlpt_level <= ?`;
      params.push(minJlptLevel);
    }
    if (maxJlptLevel) {
      query += ` AND e.jlpt_level >= ?`;
      params.push(maxJlptLevel);
    }
    
    // Add grammar points filter
    if (grammarPoints?.length) {
      query += ` AND EXISTS (
        SELECT 1 FROM json_each(e.grammar_points) gp
        WHERE json_extract(gp.value, '$.name') IN (${grammarPoints.map(() => '?').join(',')})
      )`;
      params.push(...grammarPoints);
    }
    
    // Add vocabulary level filter
    if (vocabularyLevel) {
      query += ` AND json_extract(e.complexity_metrics, '$.vocabularyLevel') = ?`;
      params.push(vocabularyLevel);
    }
    
    query += `
      ORDER BY we.position ASC
      LIMIT ?
    `;
    params.push(limit);
    
    const examples = await this.db.all(
      query,
      params
    ) as Example[];
    
    return examples.map((e: Example) => ({
      ...e,
      tags: typeof e.tags === 'string' ? JSON.parse(e.tags) : e.tags || [],
      words: typeof e.words === 'string' ? JSON.parse(e.words) : e.words || [],
      complexity_metrics: typeof e.complexity_metrics === 'string' 
        ? JSON.parse(e.complexity_metrics) 
        : e.complexity_metrics || {
            uniqueWords: 0,
            avgWordLength: 0,
            readingComplexity: 0,
            grammarComplexity: 0,
            vocabularyLevel: 'unknown'
          },
      grammar_points: typeof e.grammar_points === 'string' 
        ? JSON.parse(e.grammar_points) 
        : e.grammar_points || []
    }));
  }

  async analyzeExampleComplexity(exampleId: number): Promise<{
    uniqueWords: number;
    avgWordLength: number;
    grammarPoints: Array<{ name: string; level: string; description: string }>;
    jlptLevel: string;
    readingComplexity: number;
    grammarComplexity: number;
    vocabularyLevel: string;
  }> {
    const example = await this.db.get(
      'SELECT japanese FROM examples WHERE id = ?',
      [exampleId]
    );
    
    if (!example) {
      throw new Error('Example not found');
    }
    
    const analysis = await tokenizerService.analyzeComplexity(example.japanese);
    
    // Store the analysis results for future reference
    await this.db.run(
      `UPDATE examples SET 
       complexity_metrics = ?,
       jlpt_level = ?,
       grammar_points = ?
       WHERE id = ?`,
      [
        JSON.stringify({
          uniqueWords: analysis.uniqueWords,
          avgWordLength: analysis.avgWordLength,
          readingComplexity: analysis.readingComplexity,
          grammarComplexity: analysis.grammarComplexity,
          vocabularyLevel: analysis.vocabularyLevel
        }),
        analysis.jlptLevel,
        JSON.stringify(analysis.grammarPoints),
        exampleId
      ]
    );
    
    return {
      uniqueWords: analysis.uniqueWords,
      avgWordLength: analysis.avgWordLength,
      grammarPoints: analysis.grammarPoints,
      jlptLevel: analysis.jlptLevel,
      readingComplexity: analysis.readingComplexity,
      grammarComplexity: analysis.grammarComplexity,
      vocabularyLevel: analysis.vocabularyLevel
    };
  }

  async importTatoebaExamples(filePath: string, onProgress?: (progress: ImportProgress) => void): Promise<void> {
    const fileContent = await FileSystem.readAsStringAsync(filePath);
    const lines = fileContent.split('\n');
    let processed = 0;
    const total = lines.length;
    
    for (const line of lines) {
      if (!line.trim()) continue;
      
      const [japanese, english] = line.split('\t');
      if (!japanese || !english) continue;
      
      await this.addExampleSentence(japanese, english, 'tatoeba');
      
      processed++;
      if (onProgress) {
        onProgress({
          type: 'import',
          percent: Math.round((processed / total) * 100),
          processed,
          total,
          status: 'processing'
        });
      }
    }
    
    if (onProgress) {
      onProgress({
        type: 'import',
        percent: 100,
        processed,
        total,
        status: 'complete'
      });
    }
  }

  async addTags(wordId: string, tags: string[]): Promise<void> {
    await this.initialize();
    
    const currentTags = await this.db.get(
      'SELECT tags FROM words WHERE id = ?',
      [wordId]
    );
    
    const newTags = new Set([
      ...(currentTags?.tags?.split(',') || []),
      ...tags
    ]);

    await this.db.run(
      'UPDATE words SET tags = ? WHERE id = ?',
      [Array.from(newTags).join(','), wordId]
    );

    // Update FTS
    await this.db.run(
      'UPDATE word_fts SET tags = ? WHERE word IN (SELECT word FROM words WHERE id = ?)',
      [Array.from(newTags).join(' '), wordId]
    );
  }

  async removeTags(wordId: string, tags: string[]): Promise<void> {
    await this.initialize();
    
    const currentTags = await this.db.get(
      'SELECT tags FROM words WHERE id = ?',
      [wordId]
    );
    
    const tagSet = new Set(currentTags?.tags?.split(',') || []);
    tags.forEach(tag => tagSet.delete(tag));

    await this.db.run(
      'UPDATE words SET tags = ? WHERE id = ?',
      [Array.from(tagSet).join(','), wordId]
    );

    // Update FTS
    await this.db.run(
      'UPDATE word_fts SET tags = ? WHERE word IN (SELECT word FROM words WHERE id = ?)',
      [Array.from(tagSet).join(' '), wordId]
    );
  }

  async searchByTags(tags: string[]): Promise<SearchResult[]> {
    await this.initialize();

    const placeholders = tags.map(() => '?').join(' AND tags LIKE ');
    const params = tags.map(tag => `%${tag}%`);

    const results = await this.db.all(`
      SELECT DISTINCT
        w.id,
        w.word,
        w.reading,
        w.pos,
        w.frequency,
        w.dictionary,
        w.tags,
        GROUP_CONCAT(DISTINCT d.definition) as definitions,
        json_group_array(json_object('japanese', e.japanese, 'english', e.english)) as examples
      FROM words w
      JOIN dictionaries dict ON w.dictionary = dict.title
      LEFT JOIN definitions d ON w.id = d.word_id
      LEFT JOIN examples e ON w.id = e.word_id
      WHERE dict.enabled = 1 AND tags LIKE ${placeholders}
      GROUP BY w.id
      ORDER BY w.frequency DESC NULLS LAST
      LIMIT 50
    `, params);

    return this.mapSearchResults(results);
  }

  private async tokenizeSentence(text: string): Promise<Array<{ id: string; word: string }>> {
    // For now, just split by spaces and look up each word
    // In a real implementation, you'd want to use a proper tokenizer like Kuromoji
    const words = text.split(' ');
    const results = await Promise.all(words.map(word =>
      this.db.get('SELECT id, word FROM words WHERE word = ?', [word])
    ));
    return results.filter(Boolean);
  }

  private mapSearchResults(results: any[]): SearchResult[] {
    return results.map(row => ({
      id: row.id,
      word: row.word,
      reading: row.reading,
      definitions: row.definitions?.split(',') || [],
      pos: row.pos,
      frequency: row.frequency,
      examples: JSON.parse(row.examples).filter((ex: Example) => ex.japanese !== null),
      dictionary: row.dictionary,
      tags: row.tags?.split(',') || []
    }));
  }
}

export const databaseService = new DatabaseService(); 