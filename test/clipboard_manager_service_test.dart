import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/clipboard_manager_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // fresh storage per test: without this the shared in-memory
    // fallback (used because path_provider has no mock here) leaks
    // entries between tests
    AppStorage.resetForTest();
    ClipboardSetText.override = null;
  });

  group('ClipboardItem', () {
    test('preview truncates long text', () {
      final item = ClipboardItem(id: '1', text: 'a' * 200, timestamp: 0);
      expect(item.preview().length, lessThan(130));
    });

    test('preview renders image marker', () {
      final item = ClipboardItem(id: '1', imagePath: '/x.png', timestamp: 0);
      expect(item.preview(), contains('image'));
    });

    test('json roundtrip keeps tags and pin', () {
      const item = ClipboardItem(
        id: 'x',
        text: 'hello',
        timestamp: 123,
        pinned: true,
        tags: ['a', 'b'],
        source: 'manual',
      );
      final restored = ClipboardItem.fromJson(item.toJson());
      expect(restored.id, 'x');
      expect(restored.text, 'hello');
      expect(restored.pinned, isTrue);
      expect(restored.tags, ['a', 'b']);
      expect(restored.source, 'manual');
    });
  });

  group('ClipboardPollingConfig', () {
    test('json roundtrip', () {
      const cfg = ClipboardPollingConfig(
        textIntervalMs: 750,
        imageIntervalMs: 9000,
        imagePollingEnabled: false,
        maxItems: 100,
        maxItemBytes: 1024,
      );
      final restored = ClipboardPollingConfig.fromJson(cfg.toJson());
      expect(restored.textIntervalMs, 750);
      expect(restored.imageIntervalMs, 9000);
      expect(restored.imagePollingEnabled, isFalse);
      expect(restored.maxItems, 100);
      expect(restored.maxItemBytes, 1024);
    });

    test('defaults match documented values', () {
      const cfg = ClipboardPollingConfig();
      expect(cfg.textIntervalMs, 500);
      expect(cfg.imageIntervalMs, 4000);
      expect(cfg.imagePollingEnabled, isTrue);
      expect(cfg.maxItems, 500);
    });
  });

  group('ClipboardManagerService', () {
    late ClipboardManagerService mgr;

    setUp(() {
      mgr = ClipboardManagerService();
    });

    test('addText dedupes and moves to top', () async {
      await mgr.addText('first');
      await mgr.addText('second');
      await mgr.addText('first');
      expect(mgr.items.length, 2);
      expect(mgr.items.first.text, 'first');
    });

    test('orderedItems puts pinned first', () async {
      await mgr.addText('a');
      await mgr.addText('b');
      await mgr.addText('c');
      await mgr.togglePin(mgr.items[2].id); // pin 'a'
      final ordered = mgr.orderedItems;
      expect(ordered.first.pinned, isTrue);
      expect(ordered.first.text, 'a');
    });

    test('editItemText updates the entry', () async {
      final item = await mgr.addText('old');
      await mgr.editItemText(item.id, 'new');
      expect(mgr.items.first.text, 'new');
    });

    test('clearUnpinned keeps pinned entries', () async {
      final keep = await mgr.addText('pinned');
      await mgr.togglePin(keep.id);
      await mgr.addText('gone1');
      await mgr.addText('gone2');
      final removed = await mgr.clearUnpinned();
      expect(removed, 2);
      expect(mgr.items.length, 1);
      expect(mgr.items.first.pinned, isTrue);
    });

    test('remove deletes the entry', () async {
      final item = await mgr.addText('bye');
      await mgr.remove(item.id);
      expect(mgr.items, isEmpty);
    });

    test('setTags stores tags', () async {
      final item = await mgr.addText('tagged');
      await mgr.setTags(item.id, ['work', 'ja']);
      expect(mgr.items.first.tags, ['work', 'ja']);
    });

    test('copyItem text routes through the stubbed clipboard', () async {
      final written = <String>[];
      ClipboardSetText.override = (text) async => written.add(text);
      final item = await mgr.addText('clip me');
      final ok = await mgr.copyItem(item, copyImageBytes: null);
      expect(ok, isTrue);
      expect(written, ['clip me']);
    });

    test('copyItem image returns false without an image writer', () async {
      // no addImage here: path_provider has no mock handler in this
      // suite. Construct the item directly — copyItem only needs an
      // imagePath field; a missing file fails the read and returns false.
      const item = ClipboardItem(
        id: 'img',
        imagePath: '/nonexistent/img.png',
        timestamp: 0,
      );
      final ok = await mgr.copyItem(item, copyImageBytes: null);
      expect(ok, isFalse);
    });

    test('move reorders within the unpinned section', () async {
      await mgr.addText('one');
      await mgr.addText('two');
      await mgr.addText('three');
      final ordered0 = mgr.orderedItems.map((e) => e.text).toList();
      expect(ordered0, ['three', 'two', 'one']);

      final idTwo = mgr.orderedItems[1].id;
      await mgr.move(idTwo, ClipboardMoveDir.top);
      expect(mgr.orderedItems.map((e) => e.text).toList(), [
        'two',
        'three',
        'one',
      ]);
    });

    test('entries survive a reload', () async {
      await mgr.addText('persisted');
      final second = ClipboardManagerService();
      await second.load();
      expect(second.items.any((i) => i.text == 'persisted'), isTrue);
    });
  });
}
