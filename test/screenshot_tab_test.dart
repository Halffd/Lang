import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/screenshot_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ScreenshotService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('screenshot_tab_test');
    service = ScreenshotService();
    service.dirProvider = () async => tempDir;
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
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpTab(WidgetTester tester, {AppState? appState}) async {
    final state = appState ?? AppState(StorageService());
    await state.storageService.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ScreenshotTab(service: service)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows capture buttons and empty state', (tester) async {
    await pumpTab(tester);
    expect(find.text('Full screen'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('Previous region'), findsOneWidget);
    expect(find.text('No screenshots yet'), findsOneWidget);
  });

  testWidgets('fullscreen capture records item into history list', (
    tester,
  ) async {
    await pumpTab(tester);

    await tester.tap(find.text('Full screen'));
    await tester.pumpAndSettle();

    // history now has one entry with the capture time
    expect(service.items, isNotEmpty);
    expect(find.byIcon(Icons.image), findsOneWidget);
  });

  testWidgets('options toggles update app state', (tester) async {
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    await pumpTab(tester, appState: appState);

    expect(appState.screenshotAutoOcr, isFalse);
    await tester.tap(find.text('Auto OCR after capture'));
    await tester.pumpAndSettle();
    expect(appState.screenshotAutoOcr, isTrue);

    await tester.tap(find.text('Copy OCR text to clipboard'));
    await tester.pumpAndSettle();
    expect(appState.screenshotCopyOcrText, isTrue);

    await tester.tap(find.text('Copy image to clipboard'));
    await tester.pumpAndSettle();
    expect(appState.screenshotCopyImage, isTrue);
  });
}
