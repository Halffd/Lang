import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AnalyzerProvider translation state', () {
    late AnalyzerProvider provider;

    setUp(() {
      provider = AnalyzerProvider();
    });

    test('initial translation state empty', () {
      expect(provider.getSentenceTranslation('x'), '');
      expect(provider.getFullTranslation(), '');
      expect(provider.isTranslating, false);
    });

    test('translateSentences without sentences is a no-op', () async {
      await provider.translateSentences();
      expect(provider.isTranslating, false);
      expect(provider.getFullTranslation(), '');
    });

    test('translateSentences handles service failure gracefully', () async {
      // provider.appState null -> google provider -> network call
      // fails in test env -> caught -> state stays empty
      provider.testSetSentences({'s1': 'こんにちは'});
      await provider.translateSentences();
      expect(provider.isTranslating, false);
      // no crash; translation may stay empty (offline test env)
    });
  });
}
