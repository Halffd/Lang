import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetForTest();
    LabelService.instance.resetForTest();
  });

  group('ItemLabel', () {
    test('json roundtrip', () {
      const label = ItemLabel(
        name: 'renamed',
        bookmarked: true,
        tags: ['a', 'b'],
        color: 0xFFE53935,
      );
      final restored = ItemLabel.fromJson(
        (jsonDecode(jsonEncode(label.toJson())) as Map).map(
          (k, v) => MapEntry(k.toString(), v),
        ),
      );
      expect(restored.name, 'renamed');
      expect(restored.bookmarked, isTrue);
      expect(restored.tags, ['a', 'b']);
      expect(restored.color, 0xFFE53935);
    });

    test('isEmpty true only for default', () {
      expect(ItemLabel.empty.isEmpty, isTrue);
      const bookmarked = ItemLabel(bookmarked: true);
      expect(bookmarked.isEmpty, isFalse);
    });

    test('copyWith clear flags', () {
      const label = ItemLabel(name: 'x', color: 1, tags: ['t']);
      final cleared = label.copyWith(clearName: true, clearColor: true);
      expect(cleared.name, isNull);
      expect(cleared.color, isNull);
      expect(cleared.tags, ['t']);
    });
  });

  group('LabelService (files backend)', () {
    test('set/get/remove roundtrip', () async {
      final temp = await Directory.systemTemp.createTemp('label_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final service = LabelService.instance;
      expect(service.get('history', 'id1'), isNull);

      await service.set(
        'history',
        'id1',
        const ItemLabel(name: 'renamed', bookmarked: true, tags: ['x']),
      );
      final got = service.get('history', 'id1');
      expect(got, isNotNull);
      expect(got!.name, 'renamed');
      expect(got.bookmarked, isTrue);

      await service.remove('history', 'id1');
      expect(service.get('history', 'id1'), isNull);
    });

    test('toggleBookmark flips', () async {
      final temp = await Directory.systemTemp.createTemp('label_bm_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final service = LabelService.instance;
      await service.toggleBookmark('speech-session', 's1');
      expect(service.get('speech-session', 's1')!.bookmarked, isTrue);
      // toggle off removes the label entirely (back to unlabeled default)
      await service.toggleBookmark('speech-session', 's1');
      expect(service.get('speech-session', 's1'), isNull);
    });

    test('rename moves the label to the new id', () async {
      final temp = await Directory.systemTemp.createTemp('label_ren_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final service = LabelService.instance;
      await service.set(
        'speech-session',
        'old name',
        const ItemLabel(name: 'old name', tags: ['kept'], color: 42),
      );
      await service.rename('speech-session', 'old name', 'new name');

      expect(service.get('speech-session', 'old name'), isNull);
      final moved = service.get('speech-session', 'new name');
      expect(moved, isNotNull);
      expect(moved!.tags, ['kept']);
      expect(moved.color, 42);
    });

    test('domains are isolated', () async {
      final temp = await Directory.systemTemp.createTemp('label_dom_test');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);
      addTearDown(AppStorage.resetForTest);

      final service = LabelService.instance;
      await service.set(
        'history',
        'id1',
        const ItemLabel(name: 'history label'),
      );
      expect(service.get('analyze-sentence', 'id1'), isNull);
      expect(service.get('speech-session', 'id1'), isNull);
    });

    test('labels persist across reloads', () async {
      final temp = await Directory.systemTemp.createTemp('label_persist');
      addTearDown(() => temp.delete(recursive: true));
      await AppStorage.init(StorageBackendKind.files, filesBaseDir: temp);

      final service = LabelService.instance;
      await service.set(
        'analyze-sentence',
        'sentence-1',
        const ItemLabel(bookmarked: true, color: 0xFF43A047),
      );
      AppStorage.resetForTest();

      final fresh = LabelService.instance;
      await fresh.preload('analyze-sentence');
      final got = fresh.get('analyze-sentence', 'sentence-1');
      expect(got, isNotNull);
      expect(got!.bookmarked, isTrue);
      expect(got.color, 0xFF43A047);
    });
  });
}
