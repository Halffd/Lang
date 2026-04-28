import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import '../../../domain/entities/dictionary.dart';

class YomichanParseException implements Exception {
  final String message;
  final String? file;
  final dynamic originalError;
  
  YomichanParseException(
    this.message, {
    this.file,
    this.originalError,
  });
  
  @override
  String toString() {
    if (file != null) {
      return 'YomichanParseException in $file: $message';
    }
    return 'YomichanParseException: $message';
  }
}

class YomichanParser {
  final File zipFile;
  late Archive _archive;
  Map<String, dynamic>? _index;
  
  YomichanParser(this.zipFile);
  
  /// Extract archive to memory
  Future<void> loadArchive() async {
    try {
      final bytes = await zipFile.readAsBytes();
      _archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw YomichanParseException(
        'Failed to read ZIP archive',
        originalError: e,
      );
    }
  }
  
  /// Parse index.json
  Future<Map<String, dynamic>> parseIndex() async {
    if (_index != null) return _index!;
    
    final indexFile = _findFile('index.json');
    if (indexFile == null) {
      throw YomichanParseException('index.json not found in archive');
    }
    
    try {
      final content = utf8.decode(indexFile.content as List<int>);
      _index = jsonDecode(content) as Map<String, dynamic>;
      
      // Validate required fields
      if (!_index!.containsKey('title')) {
        throw YomichanParseException('index.json missing required field: title');
      }
      
      return _index!;
    } catch (e) {
      throw YomichanParseException(
        'Failed to parse index.json',
        file: 'index.json',
        originalError: e,
      );
    }
  }
  
  /// Get dictionary metadata
  Future<Dictionary> getDictionaryMetadata() async {
    final index = await parseIndex();
    
    return Dictionary(
      name: _sanitizeName(index['title'] as String),
      title: index['title'] as String,
      revision: index['revision'] as String?,
      format: index['format'] as int? ?? 3,
      author: index['author'] as String?,
      url: index['url'] as String?,
      description: index['description'] as String?,
      attribution: index['attribution'] as String?,
      importedAt: DateTime.now(),
    );
  }
  
  /// Parse all term banks
  Future<List<List<dynamic>>> parseTermBanks({
    Function(int count)? onProgress,
  }) async {
    final List<List<dynamic>> allTerms = [];
    int bankNumber = 1;
    int totalCount = 0;
    
    while (true) {
      final fileName = 'term_bank_$bankNumber.json';
      final file = _findFile(fileName);
      
      if (file == null) break;
      
      try {
        final content = utf8.decode(file.content as List<int>);
        final terms = jsonDecode(content) as List<dynamic>;
        
        // Validate each term
        for (final term in terms) {
          if (term is! List || term.length < 8) {
            throw YomichanParseException(
              'Invalid term format: expected array with 8 elements',
              file: fileName,
            );
          }
        }
        
        allTerms.addAll(terms.cast<List<dynamic>>());
        totalCount += terms.length;
        
        onProgress?.call(totalCount);
      } catch (e) {
        throw YomichanParseException(
          'Failed to parse term bank',
          file: fileName,
          originalError: e,
        );
      }
      
      bankNumber++;
    }
    
    return allTerms;
  }
  
  /// Parse all kanji banks
  Future<List<List<dynamic>>> parseKanjiBanks({
    Function(int count)? onProgress,
  }) async {
    final List<List<dynamic>> allKanji = [];
    int bankNumber = 1;
    int totalCount = 0;
    
    while (true) {
      final fileName = 'kanji_bank_$bankNumber.json';
      final file = _findFile(fileName);
      
      if (file == null) break;
      
      try {
        final content = utf8.decode(file.content as List<int>);
        final kanji = jsonDecode(content) as List<dynamic>;
        
        // Validate each kanji entry
        for (final entry in kanji) {
          if (entry is! List || entry.length < 6) {
            throw YomichanParseException(
              'Invalid kanji format: expected array with 6 elements',
              file: fileName,
            );
          }
        }
        
        allKanji.addAll(kanji.cast<List<dynamic>>());
        totalCount += kanji.length;
        
        onProgress?.call(totalCount);
      } catch (e) {
        throw YomichanParseException(
          'Failed to parse kanji bank',
          file: fileName,
          originalError: e,
        );
      }
      
      bankNumber++;
    }
    
    return allKanji;
  }
  
  /// Parse all tag banks
  Future<List<List<dynamic>>> parseTagBanks({
    Function(int count)? onProgress,
  }) async {
    final List<List<dynamic>> allTags = [];
    int bankNumber = 1;
    int totalCount = 0;
    
    while (true) {
      final fileName = 'tag_bank_$bankNumber.json';
      final file = _findFile(fileName);
      
      if (file == null) break;
      
      try {
        final content = utf8.decode(file.content as List<int>);
        final tags = jsonDecode(content) as List<dynamic>;
        
        // Validate each tag
        for (final tag in tags) {
          if (tag is! List || tag.length < 5) {
            throw YomichanParseException(
              'Invalid tag format: expected array with 5 elements',
              file: fileName,
            );
          }
        }
        
        allTags.addAll(tags.cast<List<dynamic>>());
        totalCount += tags.length;
        
        onProgress?.call(totalCount);
      } catch (e) {
        throw YomichanParseException(
          'Failed to parse tag bank',
          file: fileName,
          originalError: e,
        );
      }
      
      bankNumber++;
    }
    
    return allTags;
  }
  
  /// Parse all term meta banks (pitch & frequency)
  Future<List<List<dynamic>>> parseTermMetaBanks({
    Function(int count)? onProgress,
  }) async {
    final List<List<dynamic>> allMeta = [];
    int bankNumber = 1;
    int totalCount = 0;
    
    while (true) {
      final fileName = 'term_meta_bank_$bankNumber.json';
      final file = _findFile(fileName);
      
      if (file == null) break;
      
      try {
        final content = utf8.decode(file.content as List<int>);
        final meta = jsonDecode(content) as List<dynamic>;
        
        // Validate each meta entry
        for (final entry in meta) {
          if (entry is! List || entry.length < 3) {
            throw YomichanParseException(
              'Invalid meta format: expected array with 3 elements',
              file: fileName,
            );
          }
        }
        
        allMeta.addAll(meta.cast<List<dynamic>>());
        totalCount += meta.length;
        
        onProgress?.call(totalCount);
      } catch (e) {
        throw YomichanParseException(
          'Failed to parse term meta bank',
          file: fileName,
          originalError: e,
        );
      }
      
      bankNumber++;
    }
    
    return allMeta;
  }
  
  /// Find file in archive (case-insensitive)
  ArchiveFile? _findFile(String fileName) {
    // Try exact match first
    for (final file in _archive.files) {
      if (file.name == fileName) {
        return file;
      }
    }
    
    // Try case-insensitive match
    final lowerFileName = fileName.toLowerCase();
    for (final file in _archive.files) {
      if (file.name.toLowerCase() == lowerFileName) {
        return file;
      }
    }
    
    return null;
  }
  
  /// Sanitize dictionary name for use as identifier
  String _sanitizeName(String name) {
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }
  
  /// Process definition (handle structured content)
  static String? processDefinition(dynamic definition) {
    if (definition is String) {
      return definition.trim().isEmpty ? null : definition;
    }
    
    if (definition is Map) {
      final type = definition['type'];
      
      switch (type) {
        case 'text':
          final text = definition['text'] as String?;
          return text?.trim().isEmpty == true ? null : text;
          
        case 'structured-content':
          // Return as JSON for later HTML rendering
          try {
            return jsonEncode(definition['content']);
          } catch (e) {
            return null;
          }
          
        case 'image':
          // Store image reference
          try {
            return jsonEncode({
              'type': 'image',
              'data': definition['content'],
            });
          } catch (e) {
            return null;
          }
          
        default:
          return null;
      }
    }
    
    return null;
  }
  
  /// Extract reading from term meta data
  static String extractReading(dynamic data, {String fallback = ''}) {
    if (data is Map<String, dynamic>) {
      return data['reading'] as String? ?? fallback;
    }
    return fallback;
  }
  
  /// Parse frequency value from various formats
  static FrequencyParseResult parseFrequency(dynamic data) {
    // Direct number
    if (data is num) {
      return FrequencyParseResult(
        value: data.toDouble(),
        displayValue: data is int ? data.toString() : data.toStringAsFixed(1),
      );
    }
    
    // Complex object
    if (data is Map<String, dynamic>) {
      // Format 1: {reading: "...", frequency: {value: 123, displayValue: "..."}}
      if (data.containsKey('frequency') && data['frequency'] is Map) {
        final freq = data['frequency'] as Map<String, dynamic>;
        final value = (freq['value'] as num?)?.toDouble() ?? 0;
        final display = freq['displayValue'] as String?;
        
        return FrequencyParseResult(
          value: value,
          displayValue: display ?? value.toInt().toString(),
          reading: data['reading'] as String?,
        );
      }
      
      // Format 2: {reading: "...", value: 123, displayValue: "..."}
      if (data.containsKey('value')) {
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        final display = data['displayValue'] as String?;
        
        return FrequencyParseResult(
          value: value,
          displayValue: display ?? value.toInt().toString(),
          reading: data['reading'] as String?,
        );
      }
      
      // Format 3: {reading: "...", frequency: 123}
      if (data.containsKey('frequency') && data['frequency'] is num) {
        final value = (data['frequency'] as num).toDouble();
        
        return FrequencyParseResult(
          value: value,
          displayValue: value % 1 == 0 
              ? value.toInt().toString() 
              : value.toStringAsFixed(1),
          reading: data['reading'] as String?,
        );
      }
    }
    
    // Fallback: convert to string
    return FrequencyParseResult(
      value: 0,
      displayValue: data.toString(),
    );
  }
}

class FrequencyParseResult {
  final double value;
  final String displayValue;
  final String? reading;
  
  FrequencyParseResult({
    required this.value,
    required this.displayValue,
    this.reading,
  });
}