import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/reader/browser_tab.dart';
import 'package:lang/presentation/screens/reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HistoryService.instance.resetForTest();
  });

  Future<void> pumpReader(WidgetTester tester) async {
    final storage = StorageService();
    await storage.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(storage),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows reader tabs', (tester) async {
    await pumpReader(tester);
    expect(find.text('Reader'), findsWidgets);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
    // the screenshot/OCR tab lives in its own bottom-bar screen
    expect(find.text('Screenshots'), findsNothing);
  });

  testWidgets('browser tab hosts the browser launcher', (tester) async {
    await pumpReader(tester);
    await tester.tap(find.text('Browser'));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserTab), findsOneWidget);
    expect(find.text('URL or search'), findsOneWidget);
    expect(find.text('NHK Easy News'), findsOneWidget);
    expect(find.textContaining('Visited URLs show up here'), findsOneWidget);
  });

  testWidgets('clipboard tab shows settings and monitoring off state', (
    tester,
  ) async {
    await pumpReader(tester);
    await tester.tap(find.text('Clipboard'));
    await tester.pumpAndSettle();
    // monitor default mode is historyOnly (monitoring on): settings visible
    expect(find.text('Clipboard history'), findsOneWidget);
    // settings radio labels
    expect(find.text('History only'), findsOneWidget);
  });
}
