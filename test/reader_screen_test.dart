import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/history_service.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/reader_screen.dart';
import 'package:lang/presentation/screens/screenshot_tab.dart';

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

  testWidgets('shows three tabs', (tester) async {
    await pumpReader(tester);
    expect(find.text('Reader'), findsWidgets);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Screenshots'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
  });

  testWidgets('screenshot tab is hosted inside reader', (tester) async {
    await pumpReader(tester);
    // documents tab shows first; switch to screenshots
    await tester.tap(find.text('Screenshots'));
    await tester.pumpAndSettle();
    expect(find.byType(ScreenshotTab), findsOneWidget);
    expect(find.text('Full screen'), findsOneWidget);
    expect(find.text('Region'), findsOneWidget);
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
