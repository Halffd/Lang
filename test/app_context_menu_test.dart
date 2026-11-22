// Integration: the app's right-click context menu.
//
// Verifies that
//   * a secondary click on plain text outside a text field opens the
//     app menu (look up / copy the word under the cursor),
//   * the menu is suppressed inside an editable field (Flutter shows
//     its own toolbar there),
//   * the popup dictionary's right-click trigger keeps ownership of
//     the press when it is explicitly armed.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lang/core/services/popup_dictionary_controller.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/app_context_menu.dart';
import 'package:lang/presentation/widgets/app_context_menu_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PopupDictionaryController controller;
  late List<String> lookedUp;
  late List<String> copied;

  setUp(() {
    controller = PopupDictionaryController.instance;
    controller.config = PopupDictionaryConfig(
      trigger: PopupTrigger.shift,
      scanLength: 16,
      scanDepth: 0,
    );
    controller.currentRouteName = 'analyze';
    lookedUp = <String>[];
    copied = <String>[];
  });

  tearDown(() {
    controller.config = PopupDictionaryConfig();
    controller.currentRouteName = '';
    controller.hide();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    bool withField = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppContextMenuScope(
          onLookUp: (term, sentence) => lookedUp.add(term),
          onCopy: (text) => copied.add(text),
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('日本語のテスト'),
                  if (withField) const TextField(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Send a secondary (right) mouse press at [position].
  Future<void> rightClick(WidgetTester tester, Offset position) async {
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.down(position);
    await gesture.up();
  }

  testWidgets('right click on plain text opens the app menu', (tester) async {
    await pumpApp(tester);

    await rightClick(tester, tester.getCenter(find.text('日本語のテスト')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Look up'), findsOneWidget);
    expect(find.textContaining('Copy'), findsOneWidget);
  });

  testWidgets('choosing look up reports the word under the cursor', (
    tester,
  ) async {
    await pumpApp(tester);

    await rightClick(tester, tester.getCenter(find.text('日本語のテスト')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Look up'));
    await tester.pumpAndSettle();

    expect(lookedUp, contains('日本語のテスト'));
  });

  testWidgets('choosing copy puts the word on the clipboard list', (
    tester,
  ) async {
    await pumpApp(tester);

    await rightClick(tester, tester.getCenter(find.text('日本語のテスト')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Copy 日本語'));
    await tester.pumpAndSettle();

    expect(copied, contains('日本語のテスト'));
  });

  testWidgets('right click inside a text field does not open the app menu', (
    tester,
  ) async {
    await pumpApp(tester, withField: true);

    await rightClick(tester, tester.getCenter(find.byType(TextField)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Look up'), findsNothing);
  });

  testWidgets('popup dictionary right-click trigger keeps ownership', (
    tester,
  ) async {
    controller.config = PopupDictionaryConfig(
      trigger: PopupTrigger.rightClick,
      scanLength: 16,
      scanDepth: 0,
    );
    await pumpApp(tester);

    await rightClick(tester, tester.getCenter(find.text('日本語のテスト')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Look up'), findsNothing);
  });

  group('editable field context menu', () {
    Future<void> pumpField(
      WidgetTester tester, {
      String? initialText,
      bool readOnly = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: TextField(
                contextMenuBuilder: AppContextMenu.editable,
                controller: TextEditingController(text: initialText),
                readOnly: readOnly,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an empty field still offers every action', (tester) async {
      await pumpField(tester);

      await rightClick(tester, tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();

      // The default Flutter toolbar collapses to a lone "Paste" button
      // when the field is empty and nothing is selected.
      expect(find.byType(DesktopTextSelectionToolbar), findsOneWidget);
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
    });

    testWidgets('a selected word offers look up', (tester) async {
      await pumpField(tester, initialText: '日本語');

      final state = tester.state<EditableTextState>(find.byType(EditableText));
      state.updateEditingValue(
        const TextEditingValue(
          text: '日本語',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
        ),
      );
      await tester.pumpAndSettle();

      await rightClick(tester, tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Look up'), findsOneWidget);
    });

    testWidgets('a read-only field drops cut and paste', (tester) async {
      await pumpField(tester, initialText: '日本語', readOnly: true);

      final state = tester.state<EditableTextState>(find.byType(EditableText));
      state.updateEditingValue(
        const TextEditingValue(
          text: '日本語',
          selection: TextSelection(baseOffset: 0, extentOffset: 3),
        ),
      );
      await tester.pumpAndSettle();

      await rightClick(tester, tester.getCenter(find.byType(TextField)));
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Select all'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Paste'), findsNothing);
    });
  });
}
