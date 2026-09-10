import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/l10n/app_localizations.dart';
import 'package:lang/presentation/widgets/structured_definition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpDef(WidgetTester tester, String def) async {
    SharedPreferences.setMockInitialValues({});
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
          home: Scaffold(body: StructuredDefinition(definition: def)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('plain text renders as text', (tester) async {
    await pumpDef(tester, 'question marker');
    expect(find.text('question marker'), findsOneWidget);
  });

  testWidgets('structured json renders, not raw json', (tester) async {
    await pumpDef(
      tester,
      '[{"tag":"ul","lang":"ja","content":[{"tag":"li","content":"question marker"}]}]',
    );
    // the definition text is rendered, not the raw json
    expect(find.textContaining('question marker'), findsWidgets);
    expect(find.textContaining('"tag"'), findsNothing);
  });

  testWidgets('ruby json renders base with furigana reading',
      (tester) async {
    await pumpDef(
      tester,
      '[{"tag": "ruby", "content": ["\u5b66\u6821", {"tag": "rt", "content": "\u304c\u3063\u3053\u3046"}]}]',
    );
    // rich rendering keeps the base text and the furigana reading
    expect(find.textContaining('学校'), findsWidgets);
    expect(find.textContaining('がっこう'), findsWidgets);
    expect(find.textContaining('"tag"'), findsNothing);
  });

  test('flatten returns readable text for structured json', () {
    final flat = StructuredDefinition.flatten(
      '[{"tag": "ul", "content": [{"tag": "li", "content": "sense one"}, {"tag": "li", "content": "sense two"}]}]',
    );
    expect(flat, contains('sense one'));
    expect(flat, contains('sense two'));
  });

  test('flatten passes plain text through', () {
    expect(StructuredDefinition.flatten('hello'), 'hello');
  });
}
