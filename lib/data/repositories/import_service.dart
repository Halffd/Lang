import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../database/database_manager.dart';
import '../../domain/entities/dictionary.dart';
import '../datasources/local/yomichan_parser.dart';

enum ImportStatus {
  idle,
  loading,
  parsing,
  importing,
  complete,
  error,
}

class ImportProgress {
  final ImportStatus status;
  final String message;
  final double progress;
  final int? itemsProcessed;
  final int? totalItems;
  
  ImportProgress({
    required this.status,
    required this.message,
    this.progress = 0,
    this.itemsProcessed,
    this.totalItems,
  });
  
  ImportProgress copyWith({
    ImportStatus? status,
    String? message,
    double? progress,
    int? itemsProcessed,
    int? totalItems,
  }) {
    return ImportProgress(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      itemsProcessed: itemsProcessed ?? this.itemsProcessed,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

class ImportService {
  final DatabaseManager _dbManager = DatabaseManager();
  final StreamController<ImportProgress> _progressController = 
      StreamController<ImportProgress>.broadcast();
  
  Stream<ImportProgress> get progressStream => _progressController.stream;
  
  bool _isCancelled = false;
  
  /// Import Yomichan dictionary from ZIP file
  Future<Dictionary> importDictionary(File zipFile) async {
    _isCancelled = false;
    
    try {
      _emitProgress(ImportProgress(
        status: ImportStatus.loading,
        message: 'Loading archive...',
        progress: 0,
      ));
      
      // Initialize parser
      final parser = YomichanParser(zipFile);
      await parser.loadArchive();
      
      _checkCancellation();
      
      // Parse metadata
      _emitProgress(ImportProgress(
        status: ImportStatus.parsing,
        message: 'Reading metadata...',
        progress: 0.05,
      ));
      
      final metadata = await parser.getDictionaryMetadata();
      
      _checkCancellation();
      
      // Check for name collision
      final db = await _dbManager.database;
      final existing = await _getDictionaryByName(db, metadata.name);
      if (existing != null) {
        throw Exception(
          'Dictionary "${metadata.title}" already exists. '
          'Please delete it first or rename the import.'
        );
      }
      
      // Insert dictionary record
      final dictionaryId = await db.insert('dictionaries', metadata.toMap());
      final dictionary = metadata.copyWith(id: dictionaryId);
      
      _checkCancellation();
      
      try {
        // Import tags first (needed for validation)
        await _importTags(db, parser, dictionaryId);
        
        _checkCancellation();
        
        // Import entries
        await _importEntries(db, parser, dictionaryId);
        
        _checkCancellation();
        
        // Import kanji
        await _importKanji(db, parser, dictionaryId);
        
        _checkCancellation();
        
        // Import pitch accents
        await _importPitchAccents(db, parser, dictionaryId);
        
        _checkCancellation();
        
        // Import frequencies
        await _importFrequencies(db, parser, dictionaryId);
        
        _emitProgress(ImportProgress(
          status: ImportStatus.complete,
          message: 'Import complete!',
          progress: 1.0,
        ));
        
        return dictionary;
        
      } catch (e) {
        // Rollback: delete dictionary and all related data
        await db.delete('dictionaries', where: 'id = ?', whereArgs: [dictionaryId]);
        rethrow;
      }
      
    } catch (e) {
      _emitProgress(ImportProgress(
        status: ImportStatus.error,
        message: 'Import failed: ${e.toString()}',
        progress: 0,
      ));
      rethrow;
    }
  }
  
  /// Import tags
  Future<void> _importTags(
    Database db,
    YomichanParser parser,
    int dictionaryId,
  ) async {
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Importing tags...',
      progress: 0.1,
    ));
    
    final tagBanks = await parser.parseTagBanks(
      onProgress: (count) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Parsing tags...',
          progress: 0.1,
          itemsProcessed: count,
        ));
      },
    );
    
    if (tagBanks.isEmpty) return;
    
    _checkCancellation();
    
    final batch = db.batch();
    int processed = 0;
    
    for (final tagData in tagBanks) {
      _checkCancellation();
      
      final tag = DictionaryTag(
        dictionaryId: dictionaryId,
        name: tagData[0] as String,
        category: tagData[1] as String,
        sortOrder: tagData[2] as int,
        notes: (tagData[3] as String).trim().isEmpty ? null : tagData[3] as String,
        popularity: (tagData[4] as num).toDouble(),
      );
      
      batch.insert('tags', tag.toMap());
      processed++;
      
      if (processed % 100 == 0) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Importing tags...',
          progress: 0.1 + (processed / tagBanks.length) * 0.05,
          itemsProcessed: processed,
          totalItems: tagBanks.length,
        ));
      }
    }
    
    await batch.commit(noResult: true);
    
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Tags imported: $processed',
      progress: 0.15,
      itemsProcessed: processed,
      totalItems: tagBanks.length,
    ));
  }
  
  /// Import entries
  Future<void> _importEntries(
    Database db,
    YomichanParser parser,
    int dictionaryId,
  ) async {
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Importing entries...',
      progress: 0.15,
    ));
    
    final termBanks = await parser.parseTermBanks(
      onProgress: (count) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Parsing entries...',
          progress: 0.15,
          itemsProcessed: count,
        ));
      },
    );
    
    if (termBanks.isEmpty) return;
    
    _checkCancellation();
    
    const batchSize = 500;
    int processed = 0;
    
    for (int i = 0; i < termBanks.length; i += batchSize) {
      _checkCancellation();
      
      final batch = db.batch();
      final end = (i + batchSize < termBanks.length) 
          ? i + batchSize 
          : termBanks.length;
      
      for (int j = i; j < end; j++) {
        final termData = termBanks[j];
        
        final term = termData[0] as String;
        final reading = termData[1] as String;
        final definitionTags = (termData[2] as String).trim();
        final rules = (termData[3] as String).trim();
        final popularity = (termData[4] as num).toDouble();
        final rawDefinitions = termData[5] as List<dynamic>;
        final sequence = termData.length > 6 ? termData[6] as int? : null;
        final termTags = termData.length > 7 ? (termData[7] as String).trim() : '';
        
        // Process definitions
        final definitions = <String>[];
        for (final def in rawDefinitions) {
          final processed = YomichanParser.processDefinition(def);
          if (processed != null) {
            definitions.add(processed);
          }
        }
        
        if (definitions.isEmpty) continue; // Skip entries with no valid definitions
        
        final entry = DictionaryEntry(
          dictionaryId: dictionaryId,
          term: term,
          reading: reading,
          definitionTags: definitionTags.isNotEmpty 
              ? definitionTags.split(' ').where((t) => t.isNotEmpty).toList()
              : null,
          rules: rules.isNotEmpty 
              ? rules.split(' ').where((r) => r.isNotEmpty).toList()
              : null,
          popularity: popularity,
          definitions: definitions,
          sequence: sequence,
          termTags: termTags.isNotEmpty 
              ? termTags.split(' ').where((t) => t.isNotEmpty).toList()
              : null,
        );
        
        batch.insert('entries', entry.toMap());
        processed++;
      }
      
      await batch.commit(noResult: true);
      
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'Importing entries...',
        progress: 0.15 + (processed / termBanks.length) * 0.4,
        itemsProcessed: processed,
        totalItems: termBanks.length,
      ));
    }
    
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Entries imported: $processed',
      progress: 0.55,
      itemsProcessed: processed,
      totalItems: termBanks.length,
    ));
  }
  
  /// Import kanji
  Future<void> _importKanji(
    Database db,
    YomichanParser parser,
    int dictionaryId,
  ) async {
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Importing kanji...',
      progress: 0.55,
    ));
    
    final kanjiBanks = await parser.parseKanjiBanks(
      onProgress: (count) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Parsing kanji...',
          progress: 0.55,
          itemsProcessed: count,
        ));
      },
    );
    
    if (kanjiBanks.isEmpty) {
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'No kanji data found',
        progress: 0.65,
      ));
      return;
    }
    
    _checkCancellation();
    
    const batchSize = 500;
    int processed = 0;
    
    for (int i = 0; i < kanjiBanks.length; i += batchSize) {
      _checkCancellation();
      
      final batch = db.batch();
      final end = (i + batchSize < kanjiBanks.length) 
          ? i + batchSize 
          : kanjiBanks.length;
      
      for (int j = i; j < end; j++) {
        final kanjiData = kanjiBanks[j];
        
        final character = kanjiData[0] as String;
        final onyomi = (kanjiData[1] as String).trim();
        final kunyomi = (kanjiData[2] as String).trim();
        final tags = (kanjiData[3] as String).trim();
        final meanings = kanjiData[4] as List<dynamic>;
        final stats = kanjiData.length > 5 ? kanjiData[5] : null;
        
        final kanji = KanjiEntry(
          dictionaryId: dictionaryId,
          character: character,
          onyomi: onyomi.isNotEmpty 
              ? onyomi.split(' ').where((o) => o.isNotEmpty).toList()
              : null,
          kunyomi: kunyomi.isNotEmpty 
              ? kunyomi.split(' ').where((k) => k.isNotEmpty).toList()
              : null,
          tags: tags.isNotEmpty 
              ? tags.split(' ').where((t) => t.isNotEmpty).toList()
              : null,
          meanings: meanings.map((m) => m.toString()).toList(),
          stats: stats is Map ? Map<String, dynamic>.from(stats) : null,
        );
        
        batch.insert(
          'kanji',
          kanji.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        processed++;
      }
      
      await batch.commit(noResult: true);
      
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'Importing kanji...',
        progress: 0.55 + (processed / kanjiBanks.length) * 0.1,
        itemsProcessed: processed,
        totalItems: kanjiBanks.length,
      ));
    }
    
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Kanji imported: $processed',
      progress: 0.65,
      itemsProcessed: processed,
      totalItems: kanjiBanks.length,
    ));
  }
  
  /// Import pitch accents
  Future<void> _importPitchAccents(
    Database db,
    YomichanParser parser,
    int dictionaryId,
  ) async {
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Importing pitch accents...',
      progress: 0.65,
    ));
    
    final metaBanks = await parser.parseTermMetaBanks(
      onProgress: (count) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Parsing meta data...',
          progress: 0.65,
          itemsProcessed: count,
        ));
      },
    );
    
    if (metaBanks.isEmpty) {
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'No pitch accent data found',
        progress: 0.75,
      ));
      return;
    }
    
    _checkCancellation();
    
    const batchSize = 500;
    int processed = 0;
    int pitchCount = 0;
    
    // Filter for pitch data only
    final pitchData = metaBanks.where((meta) => meta[1] == 'pitch').toList();
    
    if (pitchData.isEmpty) {
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'No pitch accent data found',
        progress: 0.75,
      ));
      return;
    }
    
    for (int i = 0; i < pitchData.length; i += batchSize) {
      _checkCancellation();
      
      final batch = db.batch();
      final end = (i + batchSize < pitchData.length) 
          ? i + batchSize 
          : pitchData.length;
      
      for (int j = i; j < end; j++) {
        final meta = pitchData[j];
        
        final term = meta[0] as String;
        final data = meta[2] as Map<String, dynamic>;
        
        final reading = YomichanParser.extractReading(data, fallback: '');
        final pitchesData = data['pitches'] as List<dynamic>?;
        
        if (pitchesData == null || pitchesData.isEmpty) continue;
        
        final pitches = <PitchPattern>[];
        for (final pitchData in pitchesData) {
          if (pitchData is Map<String, dynamic>) {
            final position = pitchData['position'] as int? ?? 0;
            final tags = pitchData['tags'] as List<dynamic>?;
            
            pitches.add(PitchPattern(
              position: position,
              tags: tags?.map((t) => t.toString()).toList(),
            ));
          }
        }
        
        if (pitches.isEmpty) continue;
        
        final pitchAccent = PitchAccent(
          dictionaryId: dictionaryId,
          term: term,
          reading: reading,
          pitches: pitches,
        );
        
        batch.insert('pitches', pitchAccent.toMap());
        processed++;
        pitchCount += pitches.length;
      }
      
      await batch.commit(noResult: true);
      
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'Importing pitch accents...',
        progress: 0.65 + (processed / pitchData.length) * 0.1,
        itemsProcessed: processed,
        totalItems: pitchData.length,
      ));
    }
    
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Pitch accents imported: $pitchCount patterns',
      progress: 0.75,
      itemsProcessed: processed,
      totalItems: pitchData.length,
    ));
  }
  
  /// Import frequencies
  Future<void> _importFrequencies(
    Database db,
    YomichanParser parser,
    int dictionaryId,
  ) async {
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Importing frequencies...',
      progress: 0.75,
    ));
    
    final metaBanks = await parser.parseTermMetaBanks(
      onProgress: (count) {
        _emitProgress(ImportProgress(
          status: ImportStatus.importing,
          message: 'Parsing meta data...',
          progress: 0.75,
          itemsProcessed: count,
        ));
      },
    );
    
    if (metaBanks.isEmpty) {
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'No frequency data found',
        progress: 0.9,
      ));
      return;
    }
    
    _checkCancellation();
    
    const batchSize = 500;
    int processed = 0;
    
    // Filter for frequency data only
    final freqData = metaBanks.where((meta) => meta[1] == 'freq').toList();
    
    if (freqData.isEmpty) {
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'No frequency data found',
        progress: 0.9,
      ));
      return;
    }
    
    for (int i = 0; i < freqData.length; i += batchSize) {
      _checkCancellation();
      
      final batch = db.batch();
      final end = (i + batchSize < freqData.length) 
          ? i + batchSize 
          : freqData.length;
      
      for (int j = i; j < end; j++) {
        final meta = freqData[j];
        
        final term = meta[0] as String;
        final data = meta[2];
        
        final freqResult = YomichanParser.parseFrequency(data);
        final reading = freqResult.reading ?? '';
        
        final frequency = FrequencyData(
          dictionaryId: dictionaryId,
          term: term,
          reading: reading,
          frequencyType: 'freq', // Could be extended for different types
          value: freqResult.value,
          displayValue: freqResult.displayValue,
        );
        
        batch.insert('frequencies', frequency.toMap());
        processed++;
      }
      
      await batch.commit(noResult: true);
      
      _emitProgress(ImportProgress(
        status: ImportStatus.importing,
        message: 'Importing frequencies...',
        progress: 0.75 + (processed / freqData.length) * 0.15,
        itemsProcessed: processed,
        totalItems: freqData.length,
      ));
    }
    
    _emitProgress(ImportProgress(
      status: ImportStatus.importing,
      message: 'Frequencies imported: $processed',
      progress: 0.9,
      itemsProcessed: processed,
      totalItems: freqData.length,
    ));
  }
  
  /// Check if dictionary exists by name
  Future<Dictionary?> _getDictionaryByName(Database db, String name) async {
    final results = await db.query(
      'dictionaries',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    return Dictionary.fromMap(results.first);
  }
  
  /// Emit progress update
  void _emitProgress(ImportProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }
  
  /// Check if import was cancelled
  void _checkCancellation() {
    if (_isCancelled) {
      throw Exception('Import cancelled by user');
    }
  }
  
  /// Cancel ongoing import
  void cancel() {
    _isCancelled = true;
  }
  
  /// Dispose resources
  void dispose() {
    _progressController.close();
  }
}

/// Extension to add copyWith to Dictionary
extension DictionaryCopyWith on Dictionary {
  Dictionary copyWith({
    int? id,
    String? name,
    String? title,
    String? revision,
    int? format,
    String? author,
    String? url,
    String? description,
    String? attribution,
    bool? enabled,
    int? priority,
    DateTime? importedAt,
  }) {
    return Dictionary(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      revision: revision ?? this.revision,
      format: format ?? this.format,
      author: author ?? this.author,
      url: url ?? this.url,
      description: description ?? this.description,
      attribution: attribution ?? this.attribution,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      importedAt: importedAt ?? this.importedAt,
    );
  }
}