import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/app_storage.dart';
import 'package:lang/data/services/dictionary_bundle_service.dart';

/// Full backup / restore: settings (SharedPreferences snapshot) + every
/// AppStorage document (labels, clipboard manager, history, saved words,
/// screenshot registry) + all installed dictionaries — as one zip.
class FullBackupService {
  final DictionaryBundleService _bundle;

  FullBackupService({DictionaryBundleService? bundle})
    : _bundle = bundle ?? DictionaryBundleService();

  static const String _settingsName = 'settings.json';
  static const String _appStorageName = 'appstorage.json';
  static const String _dictsName = 'dictionaries.zip';

  /// Build the backup zip.
  Future<Uint8List> buildBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      final v = prefs.get(key);
      if (v is List) {
        settings[key] = v;
      } else if (v is bool || v is int || v is double || v is String) {
        settings[key] = v;
      }
    }

    final appStorageDocs = <String, String>{};
    try {
      appStorageDocs.addAll(await AppStorage.exportAll());
    } catch (_) {}

    Uint8List? dictsZip;
    try {
      dictsZip = await _bundle.exportAll();
    } catch (_) {}

    final archive = Archive()
      ..addFile(ArchiveFile.string(_settingsName, jsonEncode(settings)))
      ..addFile(
        ArchiveFile.string(_appStorageName, jsonEncode(appStorageDocs)),
      );
    if (dictsZip != null) {
      archive.addFile(ArchiveFile(_dictsName, dictsZip.length, dictsZip));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Restore from a backup zip. Returns counts.
  Future<({int settings, int docs, int dictionaries})> restore(
    Uint8List backupBytes,
  ) async {
    final archive = ZipDecoder().decodeBytes(backupBytes);
    var settingsCount = 0;
    var docsCount = 0;
    var dictsCount = 0;

    final prefs = await SharedPreferences.getInstance();

    for (final file in archive.files) {
      if (file.name == _settingsName) {
        try {
          final decoded =
              jsonDecode(utf8.decode(file.content as List<int>)) as Map;
          for (final e in decoded.entries) {
            final key = e.key.toString();
            final v = e.value;
            if (v is bool) {
              await prefs.setBool(key, v);
            } else if (v is int) {
              await prefs.setInt(key, v);
            } else if (v is double) {
              await prefs.setDouble(key, v);
            } else if (v is List) {
              await prefs.setStringList(
                key,
                v.map((x) => x.toString()).toList(),
              );
            } else {
              await prefs.setString(key, v.toString());
            }
            settingsCount++;
          }
        } catch (_) {}
      } else if (file.name == _appStorageName) {
        try {
          final decoded = jsonDecode(utf8.decode(file.content as List<int>));
          if (decoded is Map) {
            final docs = decoded.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
            await AppStorage.importAll(docs);
            docsCount = docs.length;
          }
        } catch (_) {}
      } else if (file.name == _dictsName) {
        try {
          final bytes = Uint8List.fromList(file.content as List<int>);
          dictsCount = await _bundle.importAll(bytes);
        } catch (_) {}
      }
    }

    return (settings: settingsCount, docs: docsCount, dictionaries: dictsCount);
  }

  /// Default backup file name.
  static String backupFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'lang_backup_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.zip';
  }

  /// Where backups live by default (app documents).
  Future<File> defaultBackupFile() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/${backupFileName()}');
  }
}
