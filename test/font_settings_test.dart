import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/domain/entities/font_settings.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FontSettings', () {
    test('defaults all 1.0', () {
      const s = FontSettings();
      expect(s.headers, 1.0);
      expect(s.sentences, 1.0);
      expect(s.translations, 1.0);
      expect(s.words, 1.0);
      expect(s.kanji, 1.0);
      expect(s.ui, 1.0);
    });

    test('json roundtrip', () {
      const s = FontSettings(
        headers: 1.2,
        sentences: 1.5,
        translations: 0.9,
        words: 1.1,
        kanji: 1.8,
        ui: 0.8,
      );
      final restored = FontSettings.deserialize(s.serialize());
      expect(restored.headers, 1.2);
      expect(restored.sentences, 1.5);
      expect(restored.translations, 0.9);
      expect(restored.words, 1.1);
      expect(restored.kanji, 1.8);
      expect(restored.ui, 0.8);
    });

    test('copyWith only touches given group', () {
      const s = FontSettings(kanji: 2.0);
      final s2 = s.copyWith(sentences: 1.4);
      expect(s2.kanji, 2.0);
      expect(s2.sentences, 1.4);
      expect(s2.headers, 1.0);
    });

    test('out-of-range values clamped on parse', () {
      final s = FontSettings.fromJson({
        'headers': 99.0,
        'sentences': 0.01,
        'kanji': 'bogus',
      });
      expect(s.headers, 3.0);
      expect(s.sentences, 0.5);
      expect(s.kanji, 1.0); // non-num falls back to 1.0
    });

    test('deserialize garbage returns defaults', () {
      expect(FontSettings.deserialize('not json'), const FontSettings());
      expect(FontSettings.deserialize(null), const FontSettings());
      expect(FontSettings.deserialize(''), const FontSettings());
    });
  });

  group('AppState font settings', () {
    late StorageService storage;
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      appState = AppState(storage);
    });

    test('setFontSettings persists and roundtrips', () async {
      appState.setFontSettings(const FontSettings(kanji: 2.5, sentences: 1.3));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('font_settings'), isNotNull);

      final storage2 = StorageService();
      await storage2.init();
      final appState2 = AppState(storage2);
      expect(appState2.fontSettings.kanji, 2.5);
      expect(appState2.fontSettings.sentences, 1.3);
      expect(appState2.fontSettings.headers, 1.0);
    });

    test('setFontGroup updates one group only', () {
      appState.setFontSettings(const FontSettings(words: 1.7));
      appState.setFontGroup('kanji', 2.2);
      expect(appState.fontSettings.kanji, 2.2);
      expect(appState.fontSettings.words, 1.7);
      expect(appState.fontSettings.ui, 1.0);
    });

    test('global multiplier separate from groups', () {
      appState.setFontSizeMultiplier(1.5);
      appState.setFontGroup('kanji', 2.0);
      expect(appState.fontSizeMultiplier, 1.5);
      expect(appState.fontSettings.kanji, 2.0);
      // combined size for kanji base 16: 16 * 1.5 * 2.0 = 48
      expect(
        16 * appState.fontSizeMultiplier * appState.fontSettings.kanji,
        48.0,
      );
    });
  });
}
