import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default screen index rejects negatives', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);

    expect(appState.defaultScreenIndex, 0);

    appState.setDefaultScreenIndex(5);
    expect(appState.defaultScreenIndex, 5);

    appState.setDefaultScreenIndex(-1);
    expect(appState.defaultScreenIndex, 5);
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
