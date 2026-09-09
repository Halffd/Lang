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

  test('setters notify listeners', () {
    final appState = AppState(storage);
    var notified = 0;
    appState.addListener(() => notified++);

    appState.setScreenshotAutoOcr(true);
    appState.setScreenshotAutoIntervalMin(10);
    expect(notified, 2);
  });
}
