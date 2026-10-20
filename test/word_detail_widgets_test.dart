import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/services/dictionary/yomichan_service.dart';
import 'package:lang/domain/entities/analyzed_word.dart';
import 'package:lang/domain/repositories/ai_repository.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/providers/ai_provider.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';
import 'package:lang/presentation/widgets/word_detail_sheet.dart';
import 'package:provider/provider.dart';

void main() {
  // Minimal double for AnalyzerProvider: the real one pulls in the
  // yomichan database + services.
  AnalyzerProvider fakeProvider() {
    final provider = AnalyzerProvider();
    return provider;
  }

  Widget wrap(Widget child, AnalyzerProvider provider, AppState appState) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AnalyzerProvider>.value(value: provider),
        ChangeNotifierProvider<AiProvider>.value(
          value: AiProvider(_FakeAiRepository()),
        ),
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WordDetailView / WordDetailScreen', () {
    Future<AppState> makeAppState() async {
      final storage = StorageService();
      await storage.init();
      final appState = AppState(storage);
      return appState;
    }

    final word = AnalyzedWord(
      word: '読む',
      reading: 'よむ',
      frequency: 500,
      ichiMoeDefinitions: ['to read'],
      sentence: '本を読む',
    );

    testWidgets('detail view renders word and definitions', (tester) async {
      final provider = makeProvider();
      final appState = await makeAppState();
      await tester.pumpWidget(
        wrap(
          WordDetailView(word: word, provider: provider),
          provider,
          appState,
        ),
      );
      await tester.pump();

      expect(find.text('読む'), findsWidgets);
      expect(find.text('to read'), findsOneWidget);
    });

    testWidgets('full-page screen renders with app bar', (tester) async {
      final provider = makeProvider();
      final appState = await makeAppState();
      await tester.pumpWidget(
        wrap(
          WordDetailScreen(word: word, provider: provider),
          provider,
          appState,
        ),
      );
      await tester.pump();

      // app bar title + body content
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('読む'), findsWidgets);
    });

    testWidgets('sheet shows full-page escape hatch button', (tester) async {
      final provider = makeProvider();
      final appState = await makeAppState();
      final wrapAppState = await makeAppState();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AnalyzerProvider>.value(value: provider),
            ChangeNotifierProvider<AiProvider>.value(
              value: AiProvider(_FakeAiRepository()),
            ),
            ChangeNotifierProvider<AppState>.value(value: wrapAppState),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        WordDetailSheet.show(context, provider, word),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(WordDetailSheet), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
    });
  });
}

class _FakeAiRepository implements AiRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) async => null;
}

// AnalyzerProvider double: real provider, no service init
AnalyzerProvider makeProvider() => AnalyzerProvider();
