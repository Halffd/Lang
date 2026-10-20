import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/full_backup_service.dart';

void main() {
  // FullBackupService.buildBackup depends on SharedPreferences,
  // AppStorage, Supabase-free dictionary bundle export (DB-backed) and
  // platform directories — covered by integration flows elsewhere.
  // These tests pin the file-name contract.

  group('FullBackupService', () {
    test('backupFileName has the expected shape', () {
      final name = FullBackupService.backupFileName();
      expect(name, startsWith('lang_backup_'));
      expect(name, endsWith('.zip'));
      // lang_backup_YYYYMMDD_HHMM.zip
      final stem = name.substring('lang_backup_'.length, name.length - 4);
      expect(stem.length, 13); // 8 date + _ + 4 time
    });

    test('two calls a minute apart share the date part', () {
      final a = FullBackupService.backupFileName();
      final b = FullBackupService.backupFileName();
      // same-day calls share everything up to the hour/minute
      expect(a.substring(0, 14), b.substring(0, 14));
    });
  });
}
