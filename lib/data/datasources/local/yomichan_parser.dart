import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:lang/domain/entities/dictionary.dart';

class YomichanParseException implements Exception {
  final String message;
  final String? file;
  final dynamic originalError;

  YomichanParseException(this.message, {this.file, this.originalError});

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

  /// Extract all media files (images, audio) from the archive into
  /// [targetDir]. Returns a map of archive-relative path -> extracted
  /// absolute file path.
  ///
  /// Yomichan dictionaries reference media by path relative to the
  /// dictionary root (e.g. "img/entry.png" or just "entry.png").
  /// Structured-content {image path: "..."} uses those same paths.
  Future<Map<String, String>> extractMedia(Directory targetDir) async {
    final extracted = <String, String>{};
    final imageExtensions = {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    };
    final audioExtensions = {
      '.mp3',
      '.ogg',
      '.wav',
      '.m4a',
      '.aac',
      '.opus',
      '.flac',
    };

    await targetDir.create(recursive: true);

    for (final file in _archive.files) {
      if (!file.isFile) continue;
      if (_containsPathTraversal(file.name)) continue;

      final lower = file.name.toLowerCase();
      final isMedia =
          imageExtensions.any(lower.endsWith) ||
          audioExtensions.any(lower.endsWith);
      if (!isMedia) continue;

      // keep the archive-relative path structure for lookup
      final safeRel = file.name.replaceAll('\\', '/');
      final targetFile = File('${targetDir.path}/$safeRel');
      await targetFile.parent.create(recursive: true);

      try {
        final data = file.content as List<int>;
        await targetFile.writeAsBytes(data);
        // map both the raw rel path and the basename for flexible
        // lookup (some dictionaries reference just the filename)
        extracted[safeRel] = targetFile.path;
        final base = safeRel.split('/').last;
        extracted.putIfAbsent(base, () => targetFile.path);
      } catch (_) {
        // skip unreadable entries
      }
    }
    return extracted;
  }

  /// Resolve a media path as found in structured content to an
  /// extracted file path, using the [mediaIndex] produced by
  /// [extractMedia].
  static String? resolveMediaPath(String path, Map<String, String> mediaIndex) {
    if (path.isEmpty) return null;
    var p = path.replaceAll('\\', '/').trim();
    // strip leading ./ or / variations
    while (p.startsWith('./')) {
      p = p.substring(2);
    }

    // direct rel-path match
    final direct = mediaIndex[p];
    if (direct != null) return direct;

    // basename match (dictionaries sometimes reference images
    // without the subdirectory)
    final base = p.split('/').last;
    final byBase = mediaIndex[base];
    if (byBase != null) return byBase;

    // case-insensitive basename match as last resort
    for (final e in mediaIndex.entries) {
      if (e.key.split('/').last.toLowerCase() == base.toLowerCase()) {
        return e.value;
      }
    }
    return null;
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
        throw YomichanParseException(
          'index.json missing required field: title',
        );
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

  /// Find file in archive (case-insensitive) with path traversal protection
  ArchiveFile? _findFile(String fileName) {
    // Validate filename for path traversal
    if (_containsPathTraversal(fileName)) {
      throw YomichanParseException(
        'Potential path traversal detected in filename: $fileName',
        file: fileName,
      );
    }

    // Try exact match first
    for (final file in _archive.files) {
      if (file.name == fileName) {
        // Additional check on archive file name
        if (_containsPathTraversal(file.name)) {
          throw YomichanParseException(
            'Potential path traversal detected in archive entry: ${file.name}',
            file: file.name,
          );
        }
        return file;
      }
    }

    // Try case-insensitive match
    final lowerFileName = fileName.toLowerCase();
    for (final file in _archive.files) {
      if (file.name.toLowerCase() == lowerFileName) {
        // Additional check on archive file name
        if (_containsPathTraversal(file.name)) {
          throw YomichanParseException(
            'Potential path traversal detected in archive entry: ${file.name}',
            file: file.name,
          );
        }
        return file;
      }
    }

    return null;
  }

  /// Check for path traversal sequences in filename
  bool _containsPathTraversal(String path) {
    // Check for directory traversal sequences
    if (path.contains('..') || path.contains('~') || path.startsWith('/')) {
      return true;
    }

    // Check for URL encoded traversal
    final lowerPath = path.toLowerCase();
    if (lowerPath.contains('%2e%2e') || // .. encoded
        lowerPath.contains('%2e%2e%2f') || // ../ encoded
        lowerPath.contains('%2e%2e%5c')) {
      // ..\ encoded
      return true;
    }

    // Check for multiple slashes that could indicate traversal
    if (path.contains('//') || path.contains('\\\\')) {
      return true;
    }

    return false;
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
            return jsonEncode({'type': 'image', 'data': definition['content']});
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
    return FrequencyParseResult(value: 0, displayValue: data.toString());
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
