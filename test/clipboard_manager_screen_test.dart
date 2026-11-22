// Widget tests for the clipboard manager screen: the toolbar actions
// (append, sort), the per-item menu and the Ctrl+digit shortcuts that
// copy the nth entry.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/app_storage.dart';
import 'package:lang/core/services/clipboard_manager_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/screens/clipboard_manager_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;
  late ClipboardManagerService manager;
  late List<String> written;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppStorage.resetForTest();
    written = [];
    ClipboardSetText.override = (text) async => written.add(text);
    final storage = StorageService();
    await storage.init();
    appState = AppState(storage);
    manager = ClipboardManagerService();
  });

  tearDown(() {
    ClipboardSetText.override = null;
  });


  /// The image thumbnail shows a progress indicator while the bytes are
  /// read, and that indicator animates forever, so the frame pump has
  /// to be bounded instead of settling. The window is long enough for
  /// the popup menu route to finish animating.
  Future<void> pump(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: ChangeNotifierProvider<ClipboardManagerService>.value(
          value: manager,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ClipboardManagerScreen()),
          ),
        ),
      ),
    );
    await pump(tester);
  }

  testWidgets('shows the empty state and the toolbar actions', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.textContaining('Clipboard is empty'), findsOneWidget);
    expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
  });

  testWidgets('append text extends the newest entry', (tester) async {
    await pumpScreen(tester);
    await manager.addText('first');

    await tester.tap(find.byIcon(Icons.note_add_outlined));
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 600));

    // the search field is a TextField too, so the dialog's own field
    // has to be picked explicitly
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'more',
    );
    await tester.tap(find.text('Append'));
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 600));

    expect(manager.items.length, 1);
    expect(manager.items.first.text, 'first\nmore');
  });

  testWidgets('sort orders the entries by text', (tester) async {
    await pumpScreen(tester);
    await manager.addText('charlie');
    await manager.addText('alpha');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.sort));
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Sort: by text'));
    await pump(tester);
    // the action runs after the menu's own rebuild
    await tester.pump(const Duration(milliseconds: 600));

    expect(manager.orderedItems.map((e) => e.text).toList(), [
      'alpha',
      'charlie',
    ]);
  });

  testWidgets('the item menu offers the management actions', (
    tester,
  ) async {
    await pumpScreen(tester);
    await manager.addText('entry');
    await pump(tester);

    await tester.tap(find.byIcon(Icons.more_horiz).last);
    await pump(tester);
    // the menu route animates in over a second; let it finish before
    // the item is picked
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Tags…'), findsOneWidget);
    expect(find.text('Pin to top'), findsOneWidget);
    expect(find.text('Move to top'), findsOneWidget);
    expect(find.text('Move to bottom'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('Ctrl+1 copies the first entry', (tester) async {
    await pumpScreen(tester);
    await manager.addText('first');
    await manager.addText('second');
    await pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pump(tester);

    // the ordered list is newest first, so the first entry is 'second'
    expect(written, ['second']);
  });

  testWidgets('Ctrl+2 copies the second entry', (tester) async {
    await pumpScreen(tester);
    await manager.addText('first');
    await manager.addText('second');
    await pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pump(tester);

    expect(written, ['first']);
  });

  testWidgets('Ctrl+3 does nothing when the list is shorter', (
    tester,
  ) async {
    await pumpScreen(tester);
    await manager.addText('only');
    await pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await pump(tester);

    expect(written, isEmpty);
  });
}
