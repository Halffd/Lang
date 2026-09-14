// Backup service end-to-end: create a backup, list it, restore
// its content, delete it. Runs against a temp directory via a
// PathProviderPlatform override, so no real app data is touched.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:lang/core/services/backup_service.dart';

class _TempPathProvider extends PathProviderPlatform {
  final Directory dir;
  _TempPathProvider(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

void main() {
  late Directory tempDir;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lang_backup_test');
    PathProviderPlatform.instance = _TempPathProvider(tempDir);
    service = BackupService();
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('create -> list -> restore round trip keeps all payload', () async {
    final path = await service.createBackup(
      appState: {'theme': 'dark', 'language': 'ja'},
      srsData: {
        'decks': ['core'],
      },
      savedWords: ['読む', '書く'],
      favoriteWords: ['猫'],
      srsWords: ['犬'],
      ankiWords: ['水'],
      searchHistory: ['日本語'],
      settings: {'fontSize': 14},
    );

    // backup file exists under backups/
    expect(File(path).existsSync(), isTrue);
    expect(path, contains('backups'));

    // list sees it
    final backups = await service.listBackups();
    expect(backups, isNotEmpty);
    expect(backups.first['path'], path);

    // restore returns the full payload, not just app state
    final restored = await service.restoreBackup(path);
    expect(restored, isNotNull);
    expect(restored!['app_state'], {'theme': 'dark', 'language': 'ja'});
    expect(restored['srs_data'], isNotNull);
    expect(restored['saved_words'], isNotNull);
    expect(restored['settings'], isNotNull);
  });

  test(
    'manifest content decodes and payload matches what was written',
    () async {
      final path = await service.createBackup(
        appState: {'learningLanguage': 'zh'},
        srsData: {},
        savedWords: ['谢谢', '你好'],
      );
      final restored = await service.restoreBackup(path);
      expect(restored!['app_state']['learningLanguage'], 'zh');
      // multi-byte words survive the utf8 encode/decode round trip
      expect((restored['saved_words'] as List), contains('谢谢'));
    },
  );

  test('delete removes the backup', () async {
    final path = await service.createBackup(appState: {'a': 1}, srsData: {});
    expect(await service.deleteBackup(path), isTrue);
    expect(File(path).existsSync(), isFalse);
    expect(await service.listBackups(), isEmpty);
  });

  test('restore of missing file returns null', () async {
    expect(await service.restoreBackup('/nonexistent/x.zip'), isNull);
  });

  test('log writes lines and recent logs read back', () async {
    await service.log('INFO', 'hello log');
    final logs = await service.getRecentLogs();
    expect(logs.join('\n'), contains('hello log'));
    expect(logs.join('\n'), contains('[INFO]'));
  });
}
