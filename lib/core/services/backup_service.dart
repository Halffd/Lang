import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

class BackupService {
  static const String _backupsFolder = 'backups';
  static const String _logsFolder = 'logs';

  Future<Directory> get _appDir async => await getApplicationDocumentsDirectory();
  Future<Directory> get _backupsDir async {
    final dir = Directory('${(await _appDir).path}/$_backupsFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _logsDir async {
    final dir = Directory('${(await _appDir).path}/$_logsFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _getLogFile() async {
    final dir = await _logsDir;
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return File('${dir.path}/app_$date.log');
  }

  Future<void> log(String level, String message, [Object? error, StackTrace? stackTrace]) async {
    try {
      final file = await _getLogFile();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final buffer = StringBuffer('$timestamp [$level] $message');
      if (error != null) buffer.write('\nError: $error');
      if (stackTrace != null) buffer.write('\nStackTrace: $stackTrace');
      buffer.writeln();
      await file.writeAsString(buffer.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  void info(String message) => log('INFO', message);
  void warning(String message) => log('WARN', message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log('ERROR', message, error, stackTrace);
  void debug(String message) => log('DEBUG', message);

  Future<String> createBackup({
    required Map<String, dynamic> appState,
    required Map<String, dynamic> srsData,
    List<String>? savedWords,
    List<String>? favoriteWords,
    List<String>? srsWords,
    List<String>? ankiWords,
    List<String>? searchHistory,
    Map<String, dynamic>? settings,
  }) async {
    final archive = Archive();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupName = 'backup_$timestamp';

    final manifest = {
      'version': '1.0',
      'created_at': DateTime.now().toIso8601String(),
      'app': 'LangApp',
    };

    archive.addFile(ArchiveFile(
      'manifest.json',
      manifest.toString().length,
      utf8.encode(json.encode(manifest)),
    ));

    if (appState.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'app_state.json',
        appState.toString().length,
        utf8.encode(json.encode(appState)),
      ));
    }

    if (srsData.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'srs_data.json',
        srsData.toString().length,
        utf8.encode(json.encode(srsData)),
      ));
    }

    if (savedWords != null && savedWords.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'saved_words.txt',
        savedWords.join('\n').length,
        utf8.encode(savedWords.join('\n')),
      ));
    }

    if (favoriteWords != null && favoriteWords.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'favorite_words.txt',
        favoriteWords.join('\n').length,
        utf8.encode(favoriteWords.join('\n')),
      ));
    }

    if (srsWords != null && srsWords.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'srs_words.txt',
        srsWords.join('\n').length,
        utf8.encode(srsWords.join('\n')),
      ));
    }

    if (ankiWords != null && ankiWords.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'anki_words.txt',
        ankiWords.join('\n').length,
        utf8.encode(ankiWords.join('\n')),
      ));
    }

    if (searchHistory != null && searchHistory.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'search_history.txt',
        searchHistory.join('\n').length,
        utf8.encode(searchHistory.join('\n')),
      ));
    }

    if (settings != null && settings.isNotEmpty) {
      archive.addFile(ArchiveFile(
        'settings.json',
        settings.toString().length,
        utf8.encode(json.encode(settings)),
      ));
    }

    final zipData = ZipEncoder().encode(archive);

    final backupsDir = await _backupsDir;
    final backupFile = File('${backupsDir.path}/$backupName.zip');
    await backupFile.writeAsBytes(zipData);

    info('Created backup: $backupName');
    return backupFile.path;
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final dir = await _backupsDir;
    final files = await dir.list().toList();
    final backups = <Map<String, dynamic>>[];

    for (final file in files) {
      if (file is File && file.path.endsWith('.zip')) {
        final name = file.path.split('/').last;
        final stat = await file.stat();
        backups.add({
          'name': name,
          'path': file.path,
          'size': stat.size,
          'modified': stat.modified,
        });
      }
    }

    backups.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
    return backups;
  }

  Future<Map<String, dynamic>?> restoreBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) throw Exception('Backup file not found');

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      Map<String, dynamic>? extractedData;

      for (final file in archive) {
        if (file.isFile) {
          final content = utf8.decode(file.content as List<int>);
          if (file.name == 'manifest.json') continue;
          if (file.name == 'app_state.json') {
            extractedData = json.decode(content) as Map<String, dynamic>;
          }
        }
      }

      info('Restored backup from: $backupPath');
      return extractedData;
    } catch (e, st) {
      error('Failed to restore backup', e, st);
      return null;
    }
  }

  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        info('Deleted backup: $backupPath');
        return true;
      }
      return false;
    } catch (e, st) {
      error('Failed to delete backup', e, st);
      return false;
    }
  }

  Future<int> getLogsSize() async {
    final dir = await _logsDir;
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<List<String>> getRecentLogs({int lines = 100}) async {
    final file = await _getLogFile();
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final allLines = content.split('\n');
    return allLines.length <= lines ? allLines : allLines.sublist(allLines.length - lines);
  }

  Future<void> clearOldLogs({int daysToKeep = 7}) async {
    final dir = await _logsDir;
    if (!await dir.exists()) return;

    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    await for (final entity in dir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
  }
}