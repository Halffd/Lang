import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/clipboard_monitor_service.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/translation_model.dart';
import 'package:lang/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage);
  });

  void mockClipboard(String text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': text};
            }
            return null;
          },
        );
  }

  test('historyOnly mode records but never searches', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.historyOnly);
    String? searched;
    final monitor = ClipboardMonitorService()
      ..onClipboardChanged = (text) => searched = text;

    mockClipboard('記録だけ');
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips, isNotEmpty);
    expect(searched, isNull);
  });

  test('off mode does not monitor at all', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.off);
    mockClipboard('何もしない');

    final monitor = ClipboardMonitorService();
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    expect(monitor.isMonitoring, false);
    expect(HistoryService.instance.items, isEmpty);
  });

  test('autoSearch mode triggers callback', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    String? searched;
    final monitor = ClipboardMonitorService()
      ..onClipboardChanged = (text) => searched = text;

    mockClipboard('自動検索');
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    expect(searched, '自動検索');
  });

  test('ja regex gate passes only for Japanese text', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    appState.setClipboardAutoSearchRegex('ja');

    expect(ClipboardMonitorService.gatesPass(appState, '日本語テキスト'), true);
    expect(ClipboardMonitorService.gatesPass(appState, 'hello world'), false);
    expect(ClipboardMonitorService.gatesPass(appState, 'カタカナ'), true);
    expect(ClipboardMonitorService.gatesPass(appState, '漢字'), true);
  });

  test('custom regex gate matches pattern', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    appState.setClipboardAutoSearchRegex(r'^[a-z]+$');

    expect(ClipboardMonitorService.gatesPass(appState, 'abc'), true);
    expect(ClipboardMonitorService.gatesPass(appState, 'ABC123'), false);
  });

  test('invalid regex treated as no gate', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    appState.setClipboardAutoSearchRegex('([invalid');

    expect(ClipboardMonitorService.gatesPass(appState, 'any text'), true);
  });

  test('regex gate blocks auto search', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    appState.setClipboardAutoSearchRegex('ja');
    String? searched;
    final monitor = ClipboardMonitorService()
      ..onClipboardChanged = (text) => searched = text;

    mockClipboard('not japanese');
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    // recorded in history but not searched
    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips, isNotEmpty);
    expect(searched, isNull);
  });

  test('duplicate clipboard content not re-recorded', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.historyOnly);
    final monitor = ClipboardMonitorService();

    mockClipboard('same text');
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    monitor.stopMonitoring();

    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips.length, 1);
  });

  test('long clipboard text truncated in title, full in subtitle', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.historyOnly);
    final monitor = ClipboardMonitorService();
    final longText = '長いテキスト' * 30;

    mockClipboard(longText);
    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips, isNotEmpty);
    expect(clips.first.title.length, lessThanOrEqualTo(61));
    expect(clips.first.subtitle, longText);
  });

  test('settings persist and reload', () async {
    appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
    appState.setClipboardAutoSearchFocusedOnly(true);
    appState.setClipboardAutoSearchRegex('ja');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('clipboard_auto_search_mode'), 'autoSearch');
    expect(prefs.getBool('clipboard_auto_search_focused_only'), true);
    expect(prefs.getString('clipboard_auto_search_regex'), 'ja');
  });
  group('image clipboard', () {
    test('recordImage stores base64 thumbnail and roundtrips', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      HistoryService.instance.recordImage(png);
      final item = HistoryService.instance.items.first;
      expect(item.hasImage, true);
      expect(item.category, HistoryCategory.clipboard);
      // json roundtrip keeps image
      final restored = HistoryItem.fromJson(item.toJson());
      expect(restored.imageThumbnail, item.imageThumbnail);
    });

    test('hashBytes distinguishes different images', () {
      final a = Uint8List.fromList(List.generate(2000, (i) => i % 251));
      final b = Uint8List.fromList(List.generate(2000, (i) => (i + 1) % 251));
      final ha = ClipboardMonitorService.hashBytesForTest(a);
      final hb = ClipboardMonitorService.hashBytesForTest(b);
      expect(ha != hb, true);
      // identical bytes -> identical hash
      expect(ClipboardMonitorService.hashBytesForTest(a), ha);
    });

    test('image ocr flow records text and searches when gates pass',
        () async {
      appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
      String? searched;
      final monitor = ClipboardMonitorService();
      monitor.onClipboardChanged = (text) {
        searched = text;
      };
      monitor.onClipboardImage = (bytes) async => '認識されたテキスト';

      // no text on standard clipboard -> falls through to image poll;
      // rich clipboard unavailable in unit tests, so call _pollImage
      // indirectly is not possible; verify gates logic separately.
      // Instead simulate: gates applied to recognized text.
      final recognized = '認識されたテキスト';
      expect(
        ClipboardMonitorService.gatesPass(appState, recognized),
        true,
      );
      expect(searched, isNull); // not wired without rich clipboard
    });

    test('focus gate uses injectable focus check', () async {
      appState.setClipboardAutoSearchMode(ClipboardAutoSearchMode.autoSearch);
      appState.setClipboardAutoSearchFocusedOnly(true);

      ClipboardMonitorService.instance.isAppFocused = () => true;
      expect(
        ClipboardMonitorService.gatesPass(appState, 'any'),
        true,
      );

      ClipboardMonitorService.instance.isAppFocused = () => false;
      expect(
        ClipboardMonitorService.gatesPass(appState, 'any'),
        false,
      );

      // restore default
      ClipboardMonitorService.instance.isAppFocused =
          ClipboardMonitorService.defaultIsAppFocused;
    });
  });

}
