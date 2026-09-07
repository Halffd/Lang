import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/clipboard_monitor_service.dart';
import 'package:lang/core/services/history_service.dart';
import 'package:lang/domain/entities/app_state.dart';
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

  test('clipboard change records history item', () async {
    final monitor = ClipboardMonitorService();
    // simulate clipboard content via mock message handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': '今日は良い天気ですね'};
            }
            return null;
          },
        );

    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips, isNotEmpty);
    expect(clips.first.subtitle, '今日は良い天気ですね');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          null,
        );
  });

  test('duplicate clipboard content not re-recorded', () async {
    final monitor = ClipboardMonitorService();
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          (call) async {
            if (call.method == 'Clipboard.getData') {
              callCount++;
              return {'text': 'same text'};
            }
            return null;
          },
        );

    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    monitor.stopMonitoring();

    expect(callCount, greaterThanOrEqualTo(2));
    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips.length, 1);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          null,
        );
  });

  test('callback fires only when monitor setting enabled', () async {
    appState.setClipboardMonitor(true);
    String? received;
    final monitor = ClipboardMonitorService()
      ..onClipboardChanged = (text) => received = text;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': 'callback test'};
            }
            return null;
          },
        );

    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    expect(received, 'callback test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          null,
        );
  });

  test('long clipboard text truncated in title, full in subtitle', () async {
    final monitor = ClipboardMonitorService();
    final longText = '長いテキスト' * 30;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': longText};
            }
            return null;
          },
        );

    monitor.startMonitoring(appState);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    monitor.stopMonitoring();

    final clips = HistoryService.instance.items
        .where((i) => i.category == HistoryCategory.clipboard)
        .toList();
    expect(clips, isNotEmpty);
    expect(clips.first.title.length, lessThanOrEqualTo(61));
    expect(clips.first.subtitle, longText);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter/platform', JSONMethodCodec()),
          null,
        );
  });
}
