import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default screen index clamps to the 9 nav destinations', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);

    expect(appState.defaultScreenIndex, 0);

    appState.setDefaultScreenIndex(8); // ai
    expect(appState.defaultScreenIndex, 8);

    appState.setDefaultScreenIndex(9); // out of range: ignored
    expect(appState.defaultScreenIndex, 8);

    appState.setDefaultScreenIndex(-1); // out of range: ignored
    expect(appState.defaultScreenIndex, 8);
  });

  test('default screen index persists', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();

    final appState = AppState(storage);
    appState.setDefaultScreenIndex(4); // writer

    final reloaded = AppState(storage);
    expect(reloaded.defaultScreenIndex, 4);
  });
}
