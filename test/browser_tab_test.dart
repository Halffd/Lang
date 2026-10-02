import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/reader/browser_tab.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeBrowserUrl', () {
    test('passes full urls through', () {
      expect(
        normalizeBrowserUrl('https://www3.nhk.or.jp/news/easy/'),
        'https://www3.nhk.or.jp/news/easy/',
      );
      expect(
        normalizeBrowserUrl('http://example.com/a?b=c'),
        'http://example.com/a?b=c',
      );
    });

    test('adds https to bare hosts', () {
      expect(normalizeBrowserUrl('example.com'), 'https://example.com');
      expect(normalizeBrowserUrl('tatoeba.org/en'), 'https://tatoeba.org/en');
    });

    test('bare words become a wikipedia search', () {
      expect(
        normalizeBrowserUrl('暗算'),
        'https://www.wikipedia.org/wiki/Special:Search?search=%E6%9A%97%E7%AE%97',
      );
      expect(
        normalizeBrowserUrl('Nihongo lesson 3'),
        'https://www.wikipedia.org/wiki/Special:Search'
        '?search=Nihongo%20lesson%203',
      );
    });

    test('trims whitespace and rejects empty input', () {
      expect(normalizeBrowserUrl('  example.com  '), 'https://example.com');
      expect(normalizeBrowserUrl('   '), isNull);
      expect(normalizeBrowserUrl(''), isNull);
    });
  });

  group('browserOpenModeFor', () {
    test('linux always uses the system browser', () {
      // there is no webkit2gtk binding, so the embedded webview must never
      // be selected on linux or the app fails to start on clean hosts
      for (final mobile in [true, false]) {
        expect(
          browserOpenModeFor(isLinux: true, isMobile: mobile),
          BrowserOpenMode.external,
          reason: 'mobile=$mobile',
        );
      }
    });

    test('android and ios get the embedded webview', () {
      expect(
        browserOpenModeFor(isLinux: false, isMobile: true),
        BrowserOpenMode.embedded,
      );
    });

    test('windows and macos get a native window', () {
      expect(
        browserOpenModeFor(isLinux: false, isMobile: false),
        BrowserOpenMode.nativeWindow,
      );
    });
  });

  // The linux build of this app must never link webkit2gtk: the plugin is
  // registered as windows/macos only, so touching its channel on linux would
  // throw MissingPluginException instead of opening a browser.
  testWidgets('on linux it opens the system browser, not the webview plugin', (
    tester,
  ) async {
    if (!Platform.isLinux) return;

    var webviewCalls = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('webview_window'), (
      call,
    ) async {
      webviewCalls++;
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        const MethodChannel('webview_window'),
        null,
      ),
    );

    final launched = <String>[];
    UrlLauncherPlatform.instance = _RecordingLauncher(launched);
    addTearDown(() => UrlLauncherPlatform.instance = _RecordingLauncher(null));

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrowserTab())),
    );
    await tester.enterText(find.byType(TextField), 'example.com');
    await tester.tap(find.text('Open'));
    // explicit pumps: the focused text field keeps a blinking cursor, so
    // pumpAndSettle would never return
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(webviewCalls, 0, reason: 'webkit2gtk channel must stay untouched');
    expect(launched, ['https://example.com']);
  });
}

class _RecordingLauncher extends UrlLauncherPlatform {
  _RecordingLauncher(this.launched);

  final List<String>? launched;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched?.add(url);
    return true;
  }
}
