// Widget test for the live-OCR settings: on a machine without screen
// capture the section must say so and the controls must be inert.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lang/core/services/live_ocr/live_ocr_adapter.dart';
import 'package:lang/core/services/live_ocr/live_ocr_controller.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/live_ocr_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    appState = AppState(storage);
  });

  tearDown(() => appState.dispose());

  LiveOcrController buildController({required bool supported}) {
    // a screenshot service that reports no backend, so a loop that
    // starts here captures nothing instead of shelling out to the
    // real capture tools
    final screenshotService = ScreenshotService()
      ..platformOverride = () async => ScreenshotPlatform.unsupported;
    final controller = LiveOcrController(
      isSupported: () async => supported,
    );
    controller.attach(
      appState: appState,
      ocrService: OcrService(),
      translationService: TranslationService(),
      adapter: LiveOcrAdapter(
        appState: appState,
        screenshotService: screenshotService,
        ocrService: OcrService(),
        translationService: TranslationService(),
      ),
    );
    return controller;
  }

  Future<void> pumpSettings(
    WidgetTester tester,
    LiveOcrController controller,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<LiveOcrController>.value(
        value: controller,
        child: ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LiveOcrSettings()),
          ),
        ),
      ),
    );
    // the platform probe is async; let it land
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a machine without capture says so and disables the switch', (
    tester,
  ) async {
    final controller = buildController(supported: false);

    await pumpSettings(tester, controller);

    expect(find.textContaining('Screen capture is not available'), findsOneWidget);
    final switchFinder = find.byType(SwitchListTile).first;
    final tile = tester.widget<SwitchListTile>(switchFinder);
    expect(tile.onChanged, isNull);

    // the controller owns timers; dispose it inside the test body so
    // they are cancelled before the tree is torn down
    controller.dispose();
  });

  testWidgets('a machine with capture shows no warning', (tester) async {
    final controller = buildController(supported: true);

    await pumpSettings(tester, controller);

    expect(find.textContaining('Screen capture is not available'), findsNothing);

    controller.dispose();
  });

  testWidgets('the enable switch works on a supported machine', (
    tester,
  ) async {
    final controller = buildController(supported: true);

    await pumpSettings(tester, controller);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pump();

    expect(appState.liveOcrEnabled, isTrue);

    // let the settings debounce fire so the loop starts, then let the
    // teardown check see no pending timers
    await tester.pump(const Duration(milliseconds: 600));
    controller.dispose();
  });
}
