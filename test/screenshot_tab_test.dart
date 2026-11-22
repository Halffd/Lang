import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/live_ocr/live_ocr_controller.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
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
    // headless CI has no DISPLAY, so force the x11 backend or capture bails
    // out as unsupported before the fakes run
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

    // the options sit in a scrollable area: bring each one into view
    // before tapping it
    Future<void> tapOption(String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    expect(appState.screenshotAutoOcr, isFalse);
    await tapOption('Auto OCR after capture');
    expect(appState.screenshotAutoOcr, isTrue);

    await tapOption('Copy OCR text to clipboard');
    expect(appState.screenshotCopyOcrText, isTrue);

    await tapOption('Copy image to clipboard');
    expect(appState.screenshotCopyImage, isTrue);
  });

  testWidgets('shows the live OCR indicator and the screen search button', (
    tester,
  ) async {
    await pumpTab(tester);

    // the live-OCR state has to be visible on the OCR screen: the
    // toggle itself lives in the settings screen
    expect(find.text('Live OCR'), findsOneWidget);
    expect(find.text('Live OCR is off'), findsOneWidget);

    // the screen-content search button
    expect(find.text('Search screen content'), findsOneWidget);
  });

  testWidgets('the live OCR toggle updates app state', (tester) async {
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    await pumpTab(tester, appState: appState);

    expect(appState.liveOcrEnabled, isFalse);
    await tester.tap(find.byKey(const Key('liveOcrSwitch')));
    await tester.pumpAndSettle();
    expect(appState.liveOcrEnabled, isTrue);
    // the status line reports whether the loop is *running*, not
    // whether the switch is on: without a controller in the tree the
    // loop never starts, so it still says off
    expect(find.text('Live OCR is off'), findsOneWidget);
    expect(find.text('Live OCR is running'), findsNothing);
  });

  testWidgets('the live OCR section reads the controller from the tree', (
    tester,
  ) async {
    // The controller is registered as a non-nullable
    // `LiveOcrController`. Asking provider for `LiveOcrController?`
    // looks up a different scope type, finds nothing and yields null
    // — which is why the live OCR switch did nothing.
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    final controller = LiveOcrController(
      isSupported: () async => false,
    );
    controller.attach(
      appState: appState,
      ocrService: OcrService(),
      translationService: TranslationService(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          ChangeNotifierProvider<LiveOcrController>.value(value: controller),
        ],
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

    // the machine cannot capture, so the section must say so: that
    // only happens when the controller was found
    expect(find.textContaining('Screen capture is not available'), findsOneWidget);
    // and the switch must be disabled
    final sw = tester.widget<Switch>(find.byKey(const Key('liveOcrSwitch')));
    expect(sw.onChanged, isNull);

    controller.dispose();
  });

  testWidgets('the OCR engine dropdown disables engines that cannot run here', (
    tester,
  ) async {
    await pumpTab(tester);

    // the options sit in a scrollable area: bring the dropdown into
    // view before tapping it
    await tester.scrollUntilVisible(
      find.byKey(const Key('ocrEngineDropdown')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // open the engine dropdown
    await tester.tap(find.byKey(const Key('ocrEngineDropdown')));
    await tester.pumpAndSettle();

    // the items live in the dropdown's overlay, and their displayed text
    // differs per platform, so match on the item's value
    DropdownMenuItem<String> itemFor(String value) => tester
        .widgetList<DropdownMenuItem<String>>(
          find.byWidgetPredicate(
            (w) =>
                w is DropdownMenuItem<String> && w.value == value,
          ),
        )
        .first;

    final mlKitItem = itemFor('mlKit');
    final aiItem = itemFor('ai');

    // the ai engine needs the search screen's provider, which this tab
    // cannot reach
    expect(aiItem.enabled, isFalse);

    // mlKit has no desktop build, so it must be off the table there
    expect(mlKitItem.enabled, OcrService.isMlKitAvailable);
  });
}
