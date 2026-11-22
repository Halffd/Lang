// Tests for the live-OCR controller: it must follow the app settings
// while the loop runs, without the app having to restart it.

import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/live_ocr/live_ocr_adapter.dart';
import 'package:lang/core/services/live_ocr/live_ocr_controller.dart';
import 'package:lang/core/services/live_ocr/live_ocr_service.dart';
import 'package:lang/core/services/screenshot_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/data/repositories/translation_service.dart';
import 'package:lang/data/services/ocr_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late StorageService storage;
  late AppState appState;
  late TranslationService translationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    appState = AppState(storage);
    translationService = TranslationService();
  });

  tearDown(() => appState.dispose());

  LiveOcrController buildController() {
    final controller = LiveOcrController();
    controller.attach(
      appState: appState,
      ocrService: OcrService(),
      translationService: translationService,
      adapter: LiveOcrAdapter(
        appState: appState,
        screenshotService: ScreenshotService.instance,
        ocrService: OcrService(),
        translationService: translationService,
      ),
    );
    return controller;
  }

  test('the translation provider follows the app setting', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    appState.setTranslationProvider(TranslationProvider.gemini);

    // the setting is applied on a short debounce so a slider drag
    // does not reconfigure on every pixel
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(translationService.provider, TranslationProvider.gemini);
  });

  test('the capture interval follows the app setting', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    appState.setLiveOcrIntervalSec(7);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(controller.service.interval, const Duration(seconds: 7));
  });

  test('the stability threshold follows the app setting', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    appState.setLiveOcrRequiredRepeats(4);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(controller.service.gate.requiredRepeats, 4);
  });

  test('the capture target follows the fullscreen setting', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    appState.setLiveOcrUseFullscreen(true);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(controller.service.target, LiveOcrCaptureTarget.fullscreen);
  });

  test('disabling live OCR stops a running loop', () async {
    final controller = buildController();
    addTearDown(controller.dispose);

    controller.start();
    expect(controller.isRunning, isTrue);

    appState.setLiveOcrEnabled(false);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(controller.isRunning, isFalse);
  });

  group('on a machine without screen capture', () {
    LiveOcrController buildUnsupportedController() {
      final controller = LiveOcrController(isSupported: () async => false);
      controller.attach(
        appState: appState,
        ocrService: OcrService(),
        translationService: translationService,
        adapter: LiveOcrAdapter(
          appState: appState,
          screenshotService: ScreenshotService.instance,
          ocrService: OcrService(),
          translationService: translationService,
        ),
      );
      return controller;
    }

    test('the controller reports that it cannot run', () async {
      final controller = buildUnsupportedController();
      addTearDown(controller.dispose);

      // the platform probe is async, so give it a turn to land
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.isUnsupported, isTrue);
    });

    test('enabling live OCR does not start the loop', () async {
      final controller = buildUnsupportedController();
      addTearDown(controller.dispose);

      appState.setLiveOcrEnabled(true);

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.isRunning, isFalse);
      expect(controller.isUnsupported, isTrue);
    });
  });

  test('a machine with screen capture is not reported as unsupported', () async {
    final controller = LiveOcrController(isSupported: () async => true);
    addTearDown(controller.dispose);
    controller.attach(
      appState: appState,
      ocrService: OcrService(),
      translationService: translationService,
      adapter: LiveOcrAdapter(
        appState: appState,
        screenshotService: ScreenshotService.instance,
        ocrService: OcrService(),
        translationService: translationService,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.isUnsupported, isFalse);
  });

  group('the adapter resolves a usable engine', () {
    LiveOcrAdapter buildAdapter() => LiveOcrAdapter(
      appState: appState,
      screenshotService: ScreenshotService.instance,
      ocrService: OcrService(),
      translationService: translationService,
    );

    test('a stored mlKit choice does not reach the ML Kit recognizer', () {
      appState.setOcrEngine('mlKit');
      final engine = buildAdapter().resolveEngine();

      // ML Kit has no desktop build, so the adapter must not pick it
      // there: the loop would capture forever and read nothing
      if (OcrService.isMlKitAvailable) {
        expect(engine, OcrEngine.mlKit);
      } else {
        expect(engine, OcrEngine.tesseract);
      }
    });

    test('a stored ai choice falls back to the platform default', () {
      appState.setOcrEngine('ai');
      final engine = buildAdapter().resolveEngine();

      // the ai engine needs the AI provider from the search screen's
      // context, which the live-OCR loop cannot reach
      expect(engine, isNot(OcrEngine.ai));
      expect(engine, OcrService.engineFromName(null));
    });

    test('a stored tesseract choice is kept', () {
      appState.setOcrEngine('tesseract');
      expect(buildAdapter().resolveEngine(), OcrEngine.tesseract);
    });
  });
}
