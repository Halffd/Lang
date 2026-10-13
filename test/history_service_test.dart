import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/history_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
  });

  group('HistoryItem', () {
    test('json roundtrip', () {
      final item = HistoryItem(
        id: 'search_1',
        category: HistoryCategory.search,
        title: '日本語',
        subtitle: 'ja',
        timestamp: 1700000000000,
      );
      final restored = HistoryItem.fromJson(item.toJson());
      expect(restored.id, item.id);
      expect(restored.category, HistoryCategory.search);
      expect(restored.title, '日本語');
      expect(restored.subtitle, 'ja');
      expect(restored.timestamp, item.timestamp);
    });

    test('unknown category falls back to action', () {
      final json = {
        'id': 'x',
        'category': 'bogus',
        'title': 't',
        'timestamp': 1,
      };
      expect(HistoryItem.fromJson(json).category, HistoryCategory.action);
    });
  });

  group('HistoryService', () {
    test('load with no stored data yields empty list', () async {
      final service = HistoryService.instance;
      await service.load();
      expect(service.items, isEmpty);
      expect(service.isLoaded, true);
    });

    test('record inserts newest first and persists', () async {
      final service = HistoryService.instance;
      await service.load();
      service.record(HistoryCategory.search, '猫', subtitle: 'ja');
      service.record(
        HistoryCategory.visit,
        'example.com',
        subtitle: 'https://example.com',
      );

      expect(service.items.length, 2);
      expect(service.items.first.category, HistoryCategory.visit);
      expect(service.items.first.title, 'example.com');
      expect(service.items.last.title, '猫');

      // persisted: fresh instance reads same storage (AppStorage backend —
      // SQLite or local files per the storage setting; the legacy
      // SharedPreferences key is only a migration source)
      final stored = await AppStorage.instance.read('activity_history');
      expect(stored, isNotNull);
    });

    test('record same category idempotent ids do not collapse', () async {
      final service = HistoryService.instance;
      await service.load();
      service.record(HistoryCategory.word, '犬');
      service.record(HistoryCategory.word, '犬');
      expect(service.items.length, 2);
    });

    test('remove deletes single item by id', () async {
      final service = HistoryService.instance;
      await service.load();
      service.record(HistoryCategory.kanji, '水');
      final id = service.items.first.id;
      service.remove(id);
      expect(service.items, isEmpty);
    });

    test('clear single category leaves others', () async {
      final service = HistoryService.instance;
      await service.load();
      service.record(HistoryCategory.search, 'q1');
      service.record(HistoryCategory.favorite, 'f1');
      service.clear(category: HistoryCategory.search);
      expect(service.items.length, 1);
      expect(service.items.first.category, HistoryCategory.favorite);
    });

    test('clear all empties everything', () async {
      final service = HistoryService.instance;
      await service.load();
      service.record(HistoryCategory.search, 'q1');
      service.record(HistoryCategory.document, 'book.pdf', subtitle: '/x.pdf');
      service.clear();
      expect(service.items, isEmpty);
    });

    test('caps stored items at 500', () async {
      final service = HistoryService.instance;
      await service.load();
      for (var i = 0; i < 505; i++) {
        service.record(HistoryCategory.action, 'w$i', subtitle: 'save_word');
      }
      expect(service.items.length, 500);
      // newest kept: last recorded word is first
      expect(service.items.first.title, 'w504');
    });
  });
}
