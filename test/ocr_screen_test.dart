// Widget tests for the OCR / Screenshot bottom-bar screen: the screen
// itself, its tabs, and the screenshot manager it hosts.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/capture_screens.dart';
import 'package:lang/presentation/widgets/screenshot_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ScreenshotService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ocr_screen_test');
    // the screen uses the shared instance
    service = ScreenshotService.instance;
    service.resetForTest();
    service.dirProvider = () async => tempDir;
    service.platformOverride = () async => ScreenshotPlatform.x11;
    service.runCommand = (executable, arguments) async {
      if (executable == 'which') {
        const tools = {'maim', 'slop', 'xdotool', 'xrandr'};
        return (tools.contains(arguments.first) ? 0 : 1, '', '');
      }
      if (executable == 'maim') {
        File(arguments.last).writeAsStringSync('png');
        return (0, '', '');
      }
      if (executable == 'slop') {
        return (0, '100x100+0+0', '');
      }
      if (executable == 'xrandr') {
        return (0, 'HDMI-1 connected primary 1920x1080+0+0', '');
      }
      return (1, '', '');
    };
  });

  tearDown(() async {
    service.resetForTest();
    await tempDir.delete(recursive: true);
  });

  /// The thumbnail shows a progress indicator while the bytes are read,
  /// and that indicator animates forever, so the frame pump has to be
  /// bounded instead of settling.
  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final appState = AppState(StorageService());
    await appState.storageService.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScreenshotScreen(),
        ),
      ),
    );
    await pump(tester);
  }

  Future<void> captureOne(WidgetTester tester) async {
    final item = await service.capture(ScreenshotKind.fullscreen);
    expect(item, isNotNull);
    await pump(tester);
  }

  testWidgets('the screen shows its title and the screenshot tabs', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('OCR / Screenshot'), findsOneWidget);

    // the tabs only appear once there is something to show
    await captureOne(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('Album'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
  });

  testWidgets('the manager tab hosts the screenshot manager', (
    tester,
  ) async {
    await pumpScreen(tester);
    await captureOne(tester);

    // the manager is the third tab; switch to it
    await tester.tap(find.text('Manager'));
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ScreenshotManager), findsOneWidget);
    // the manager's own toolbar
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('the title follows the app language', (tester) async {
    final appState = AppState(StorageService());
    await appState.storageService.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ScreenshotScreen(),
        ),
      ),
    );
    await pump(tester);

    expect(find.text('OCR / スクリーンショット'), findsOneWidget);
  });
}
