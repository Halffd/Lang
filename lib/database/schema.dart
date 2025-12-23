import 'package:sqflite/sqflite.dart';

const String createEntriesTable = '''
  CREATE TABLE IF NOT EXISTS entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    term TEXT NOT NULL,
    reading TEXT NOT NULL,
    definition_tags TEXT,
    rules TEXT,
    popularity REAL NOT NULL DEFAULT 0,
    definitions TEXT NOT NULL,
    sequence INTEGER,
    term_tags TEXT,
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

// FTS5 virtual table for full-text search on definitions
const String createEntriesFtsTable = '''
  CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
    definitions,
    content='entries',
    content_rowid='id'
  )
''';

const String createEntriesIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_entries_term ON entries(term);
  CREATE INDEX IF NOT EXISTS idx_entries_reading ON entries(reading);
  CREATE INDEX IF NOT EXISTS idx_entries_term_reading ON entries(term, reading);
  CREATE INDEX IF NOT EXISTS idx_entries_popularity ON entries(popularity DESC);
  CREATE INDEX IF NOT EXISTS idx_entries_dictionary ON entries(dictionary_id);
''';

const String createKanjiTable = '''
  CREATE TABLE IF NOT EXISTS kanji (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    character TEXT NOT NULL UNIQUE,
    onyomi TEXT,
    kunyomi TEXT,
    tags TEXT,
    meanings TEXT NOT NULL,
    stats TEXT,
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

const String createKanjiIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_kanji_character ON kanji(character);
  CREATE INDEX IF NOT EXISTS idx_kanji_dictionary ON kanji(dictionary_id);
''';

const String createTagsTable = '''
  CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    notes TEXT,
    popularity REAL NOT NULL DEFAULT 0,
    UNIQUE(dictionary_id, name),
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

const String createTagsIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_tags_name ON tags(name);
  CREATE INDEX IF NOT EXISTS idx_tags_dictionary ON tags(dictionary_id);
''';

const String createPitchesTable = '''
  CREATE TABLE IF NOT EXISTS pitches (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    term TEXT NOT NULL,
    reading TEXT NOT NULL,
    pitches TEXT NOT NULL,
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

const String createPitchesIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_pitches_term ON pitches(term);
  CREATE INDEX IF NOT EXISTS idx_pitches_reading ON pitches(reading);
  CREATE INDEX IF NOT EXISTS idx_pitches_term_reading ON pitches(term, reading);
  -- Compound index for joins with entries table
  CREATE INDEX IF NOT EXISTS idx_pitches_term_reading_dict ON pitches(term, reading, dictionary_id);
''';

const String createFrequenciesTable = '''
  CREATE TABLE IF NOT EXISTS frequencies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    term TEXT NOT NULL,
    reading TEXT NOT NULL,
    frequency_type TEXT NOT NULL,
    value REAL NOT NULL,
    display_value TEXT,
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

const String createFrequenciesIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_frequencies_term ON frequencies(term);
  CREATE INDEX IF NOT EXISTS idx_frequencies_reading ON frequencies(reading);
  CREATE INDEX IF NOT EXISTS idx_frequencies_type ON frequencies(frequency_type);
  -- Compound index for joins with entries table
  CREATE INDEX IF NOT EXISTS idx_frequencies_term_reading_dict ON frequencies(term, reading, dictionary_id);
''';

const String createTonesTable = '''
  CREATE TABLE IF NOT EXISTS tones (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dictionary_id INTEGER NOT NULL,
    term TEXT NOT NULL,
    reading TEXT NOT NULL,
    language TEXT NOT NULL,
    tones TEXT NOT NULL,
    FOREIGN KEY (dictionary_id) REFERENCES dictionaries(id) ON DELETE CASCADE
  )
''';

const String createTonesIndexes = '''
  CREATE INDEX IF NOT EXISTS idx_tones_term ON tones(term);
  CREATE INDEX IF NOT EXISTS idx_tones_reading ON tones(reading);
  CREATE INDEX IF NOT EXISTS idx_tones_language ON tones(language);
  CREATE INDEX IF NOT EXISTS idx_tones_term_reading ON tones(term, reading);
  -- Compound index for joins with entries table
  CREATE INDEX IF NOT EXISTS idx_tones_term_reading_dict ON tones(term, reading, dictionary_id);
''';

const String createDictionariesTable = '''
  CREATE TABLE IF NOT EXISTS dictionaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    revision TEXT,
    format INTEGER NOT NULL DEFAULT 3,
    author TEXT,
    url TEXT,
    description TEXT,
    attribution TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    priority INTEGER NOT NULL DEFAULT 0,
    imported_at INTEGER NOT NULL
  )
''';

const String createMetadataTable = '''
  CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''';

class DatabaseSchema {
  static const int currentVersion = 5;

  static Future<void> onCreate(Database db, int version) async {
    await db.execute(createDictionariesTable);
    await db.execute(createEntriesTable);
    await db.execute(createKanjiTable);
    await db.execute(createTagsTable);
    await db.execute(createPitchesTable);
    await db.execute(createFrequenciesTable);
    await db.execute(createTonesTable); // Add tone table
    await db.execute(createMetadataTable);

    // Create FTS5 table for full-text search
    await db.execute(createEntriesFtsTable);

    await _createIndexes(db);

    // Create FTS5 triggers to keep search table in sync
    await _createFtsTriggers(db);

    // Set schema version
    await db.insert('metadata', {
      'key': 'schema_version',
      'value': currentVersion.toString(),
    });
  }

  static Future<void> _createFtsTriggers(Database db) async {
    // Create triggers to keep FTS table in sync with main table
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
        INSERT INTO entries_fts(rowid, definitions) VALUES (new.id, new.definitions);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
        INSERT INTO entries_fts(entries_fts, rowid, definitions) VALUES('delete', old.id, old.definitions);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
        INSERT INTO entries_fts(entries_fts, rowid, definitions) VALUES('delete', old.id, old.definitions);
        INSERT INTO entries_fts(rowid, definitions) VALUES (new.id, new.definitions);
      END;
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(createEntriesIndexes);
    await db.execute(createKanjiIndexes);
    await db.execute(createTagsIndexes);
    await db.execute(createPitchesIndexes);
    await db.execute(createFrequenciesIndexes);
    await db.execute(createTonesIndexes); // Add tone indexes
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle migrations here
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE entries ADD COLUMN sequence INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute(createFrequenciesTable);
      await db.execute(createFrequenciesIndexes);
    }
    if (oldVersion < 4) {
      await db.execute(createTonesTable);
      await db.execute(createTonesIndexes);
    }
    if (oldVersion < 5) {
      // Add FTS5 table and triggers for version 5
      await db.execute(createEntriesFtsTable);
      await _createFtsTriggers(db);
      // Populate the FTS table with existing data
      await db.execute('INSERT INTO entries_fts(rowid, definitions) SELECT id, definitions FROM entries;');
    }
  }
}