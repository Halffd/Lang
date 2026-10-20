import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:flutter/foundation.dart';
import 'package:lang/data/repositories/dictionary_service.dart';
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/data/repositories/import_service.dart';

/// Multi-dictionary bundles: one zip containing a manifest plus one
/// Yomichan-format zip per installed dictionary — export/import every
/// dictionary at once.
class DictionaryBundleService {
  final DictionaryService _dictionary;
  final ImportService _importService;

  DictionaryBundleService({
    DictionaryService? dictionary,
    ImportService? importService,
  }) : _dictionary = dictionary ?? DictionaryService(),
       _importService = importService ?? ImportService();

  static const String _manifestName = 'manifest.json';

  /// Export every installed dictionary into one bundle zip:
  /// manifest.json + dictionaries/<slug>.zip per dictionary.
  Future<Uint8List> exportAll() async {
    final dicts = await _dictionary.getAllDictionaries();
    final archive = Archive();
    final names = <String>[];

    for (final dict in dicts) {
      final name = dict.name;
      if (names.contains(name)) continue;
      final inner = await _yomichanExport(name);
      final slug = _slug(name, names);
      names.add(name);
      archive.addFile(
        ArchiveFile('dictionaries/$slug.zip', inner.length, inner),
      );
    }

    archive.addFile(
      ArchiveFile.string(
        _manifestName,
        jsonEncode({
          'type': 'lang-dict-bundle',
          'version': 1,
          'exportedAt': DateTime.now().toIso8601String(),
          'dictionaries': [for (final n in names) _slug(n, [])],
        }),
      ),
    );

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Import every dictionary zip inside a bundle. Same-title
  /// dictionaries are replaced. Returns the number imported.
  Future<int> importAll(Uint8List bundleBytes) async {
    final archive = ZipDecoder().decodeBytes(bundleBytes);
    var imported = 0;

    final tempDir = await Directory.systemTemp.createTemp('lang_bundle');
    try {
      for (final file in archive.files) {
        if (!file.name.endsWith('.zip') ||
            !file.name.startsWith('dictionaries/')) {
          continue;
        }
        final innerPath = '${tempDir.path}/${file.name.split('/').last}';
        await File(innerPath).writeAsBytes((file.content as List).cast<int>());
        try {
          await _importService.importDictionary(File(innerPath), replace: true);
          imported++;
        } catch (e) {
          debugPrint('bundle import failed for ${file.name}: $e');
        }
      }
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
    return imported;
  }

  /// Single-dictionary export delegates to YomichanService's archive
  /// builder (entries + kanji + tags from the yomichan database).
  Future<Uint8List> _yomichanExport(String title) {
    return YomichanService().exportDictionaryArchive(title);
  }

  static String _slug(String name, List<String> taken) {
    var s = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    var base = s;
    var n = 2;
    while (taken.contains(s)) {
      s = '${base}_$n';
      n++;
    }
    return s;
  }
}
