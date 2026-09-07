import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Registry of extracted dictionary media (images/audio), mapping
/// archive-relative paths from dictionary zips to extracted files.
///
/// Populated at import time; loaded lazily on first lookup when
/// the app starts with already-imported dictionaries.
class DictionaryMediaRegistry {
  static final Map<String, Map<String, String>> _byDictionary = {};
  static bool _scanned = false;

  /// Root directory where media for all dictionaries lives:
  /// <app docs>/dictionary_media/<dictionary name>/
  static Future<Directory> _mediaRoot() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/dictionary_media');
  }

  /// Scan the media root and index every file by both its
  /// dictionary-relative path and basename.
  static Future<void> ensureScanned() async {
    if (_scanned) return;
    _scanned = true;
    try {
      final root = await _mediaRoot();
      if (!root.existsSync()) return;
      await for (final dictDir in root.list()) {
        if (dictDir is! Directory) continue;
        final index = <String, String>{};
        await _indexDir(dictDir, '', index);
        if (index.isNotEmpty) {
          _byDictionary[dictDir.path.split('/').last] = index;
        }
      }
    } catch (_) {
      // media is best-effort
    }
  }

  static Future<void> _indexDir(
    Directory dir,
    String relPrefix,
    Map<String, String> index,
  ) async {
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        await _indexDir(
          entity,
          relPrefix.isEmpty
              ? entity.path.split('/').last
              : '$relPrefix/${entity.path.split('/').last}',
          index,
        );
      } else if (entity is File) {
        final base = entity.path.split('/').last;
        if (relPrefix.isEmpty) {
          index.putIfAbsent(base, () => entity.path);
        } else {
          index.putIfAbsent('$relPrefix/$base', () => entity.path);
          index.putIfAbsent(base, () => entity.path);
        }
      }
    }
  }

  /// Register an extracted media index for a dictionary (import path).
  static void register(String dictionaryName, Map<String, String> index) {
    if (index.isNotEmpty) {
      _byDictionary[dictionaryName] = index;
    }
  }

  /// Resolve a media path found in structured content to an
  /// extracted file path. Searches the given dictionary first,
  /// then all dictionaries.
  static String? resolve(String path, {String? dictionaryName}) {
    if (path.isEmpty) return null;
    var p = path.replaceAll('\\', '/').trim();
    while (p.startsWith('./')) {
      p = p.substring(2);
    }

    if (dictionaryName != null) {
      final d = _byDictionary[dictionaryName];
      if (d != null) {
        final hit = _lookup(p, d);
        if (hit != null) return hit;
      }
    }
    // search all dictionaries (most have unique image names)
    for (final index in _byDictionary.values) {
      final hit = _lookup(p, index);
      if (hit != null) return hit;
    }
    // absolute path on disk
    if (File(path).existsSync()) return path;
    return null;
  }

  static String? _lookup(String p, Map<String, String> index) {
    final direct = index[p];
    if (direct != null) return direct;
    final base = p.split('/').last;
    final byBase = index[base];
    if (byBase != null) return byBase;
    for (final e in index.entries) {
      if (e.key.split('/').last.toLowerCase() == base.toLowerCase()) {
        return e.value;
      }
    }
    return null;
  }

  /// Build a full mediaIndex view (archive path -> file) for the
  /// renderer, optionally scoped to one dictionary.
  static Map<String, String> mediaIndex({String? dictionaryName}) {
    if (dictionaryName != null) {
      return _byDictionary[dictionaryName] ?? const {};
    }
    final merged = <String, String>{};
    for (final index in _byDictionary.values) {
      merged.addAll(index);
    }
    return merged;
  }
}
