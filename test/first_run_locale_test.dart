// First-run UI language: the old default hardcoded 'ja', so anyone on a
// non-Japanese device saw Japanese menus on first startup. The fix maps the
// device locale to a supported translation and falls back to English.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalizeLanguageCode', () {
    test('supported locales pass through', () {
      expect(normalizeLanguageCode('en'), 'en');
      expect(normalizeLanguageCode('en_US'), 'en');
      expect(normalizeLanguageCode('en-GB'), 'en');
      expect(normalizeLanguageCode('ja_JP'), 'ja');
      expect(normalizeLanguageCode('es'), 'es');
      expect(normalizeLanguageCode('zh'), 'zh');
      expect(normalizeLanguageCode('zh_CN'), 'zh');
      expect(normalizeLanguageCode('zh-Hant'), 'zh');
    });

    test('unsupported locales do not become Japanese', () {
      expect(normalizeLanguageCode('de_DE'), isNull);
      expect(normalizeLanguageCode('pt_BR'), isNull);
      expect(normalizeLanguageCode('ko'), isNull);
      expect(normalizeLanguageCode('fr'), isNull);
    });

    test('null and empty input are null', () {
      expect(normalizeLanguageCode(null), isNull);
      expect(normalizeLanguageCode(''), isNull);
    });

    test('case-insensitive', () {
      expect(normalizeLanguageCode('JA_jp'), 'ja');
      expect(normalizeLanguageCode('ZH_hant'), 'zh');
    });
  });

  group('first-run language', () {
    test('no stored preference picks a non-Japanese default', () async {
      // WidgetTester binds a platformDispatcher locale of en_US, so the
      // default _systemLocaleCode() is 'en_US' → 'en'. This drives the real
      // load path with no stored preference and asserts the first-run value.
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      expect(appState.language, isNot('ja'));
      expect(appState.language, anyOf('en', 'zh', 'es'));
    });

    test('no stored preference also seeds learning language from UI', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      expect(appState.learningLanguage, appState.language);
    });

    test('a stored preference is still respected verbatim', () async {
      // A user who explicitly picked Japanese keeps it.
      SharedPreferences.setMockInitialValues({'language': 'ja'});
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      expect(appState.language, 'ja');
    });

    test('English-stored preference stays English across locales', () async {
      SharedPreferences.setMockInitialValues({'language': 'en'});
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      expect(appState.language, 'en');
    });
  });
}
