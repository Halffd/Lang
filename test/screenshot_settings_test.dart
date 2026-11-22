import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  test('screenshot settings default to off', () {
    final appState = AppState(storage);
    expect(appState.screenshotAutoOcr, isFalse);
    expect(appState.screenshotCopyOcrText, isFalse);
    expect(appState.screenshotCopyImage, isFalse);
    expect(appState.screenshotAutoIntervalMin, 0);
  });

  test('screenshot settings persist and reload', () async {
    final appState = AppState(storage);
    appState.setScreenshotAutoOcr(true);
    appState.setScreenshotCopyOcrText(true);
    appState.setScreenshotCopyImage(true);
    appState.setScreenshotAutoIntervalMin(5);

    // new instance reads the same persisted values
    final reloaded = AppState(storage);
    expect(reloaded.screenshotAutoOcr, isTrue);
    expect(reloaded.screenshotCopyOcrText, isTrue);
    expect(reloaded.screenshotCopyImage, isTrue);
    expect(reloaded.screenshotAutoIntervalMin, 5);
  });

  test('ocr api key and endpoint persist and reload', () async {
    final appState = AppState(storage);
    appState.setOcrApiKey('mykey');
    appState.setOcrApiEndpoint('http://localhost:8080/parse');

    final reloaded = AppState(storage);
    expect(reloaded.ocrApiKey, 'mykey');
    expect(reloaded.ocrApiEndpoint, 'http://localhost:8080/parse');
  });

  test('setters notify listeners', () {
    final appState = AppState(storage);
    var notified = 0;
    appState.addListener(() => notified++);

    appState.setScreenshotAutoOcr(true);
    appState.setScreenshotAutoIntervalMin(10);
    expect(notified, 2);
  });

  test('live OCR settings default to off', () {
    final appState = AppState(storage);
    expect(appState.liveOcrEnabled, isFalse);
    expect(appState.liveOcrIntervalSec, 2);
    expect(appState.liveOcrRequiredRepeats, 2);
    expect(appState.liveOcrShowTranslation, isTrue);
    expect(appState.liveOcrUseFullscreen, isFalse);
  });

  test('live OCR settings persist and reload', () {
    final appState = AppState(storage);
    appState.setLiveOcrEnabled(true);
    appState.setLiveOcrIntervalSec(5);
    appState.setLiveOcrRequiredRepeats(3);
    appState.setLiveOcrShowTranslation(false);
    appState.setLiveOcrUseFullscreen(true);

    final reloaded = AppState(storage);
    expect(reloaded.liveOcrEnabled, isTrue);
    expect(reloaded.liveOcrIntervalSec, 5);
    expect(reloaded.liveOcrRequiredRepeats, 3);
    expect(reloaded.liveOcrShowTranslation, isFalse);
    expect(reloaded.liveOcrUseFullscreen, isTrue);
  });

  test('live OCR settings are clamped to their usable range', () {
    final appState = AppState(storage);
    appState.setLiveOcrIntervalSec(0);
    expect(appState.liveOcrIntervalSec, 1);
    appState.setLiveOcrIntervalSec(999);
    expect(appState.liveOcrIntervalSec, 60);

    appState.setLiveOcrRequiredRepeats(0);
    expect(appState.liveOcrRequiredRepeats, 1);
    appState.setLiveOcrRequiredRepeats(999);
    expect(appState.liveOcrRequiredRepeats, 10);
  });
}
