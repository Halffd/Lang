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
}
