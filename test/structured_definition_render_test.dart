import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/domain/entities/dictionary.dart';
import 'package:lang/presentation/widgets/structured_definition.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpDefinition(WidgetTester tester, String definition) async {
    final storage = StorageService();
    await storage.init();
    final appState = AppState(storage);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<AppState>.value(
            value: appState,
            child: SingleChildScrollView(
              child: StructuredDefinition(definition: definition),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Every Text widget's visible string must not contain JSON syntax.
  void expectNoRawJson(WidgetTester tester) {
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final data = w.data;
      if (data == null) continue;
      expect(
        data,
        isNot(contains('"tag"')),
        reason: 'raw structured JSON leaked into the UI: $data',
      );
      expect(data, isNot(contains('[{')));
    }
  }

  group('raw structured JSON never reaches the card', () {
    testWidgets('jmdict-style sense list renders as text, not json', (
      tester,
    ) async {
      const raw =
          '[{"tag":"ul","lang":"ja","content":['
          '{"tag":"li","data":{"content":"sense-note-1"},'
          '"content":["expression with tooth and claw"]},'
          '{"tag":"li","content":["to manifest as a phenomenon"]}'
          ']}]';

      final entry = DictionaryEntry.fromJson({
        'term': 'example',
        'reading': 'example',
        'definitions': raw,
      });

      await pumpDefinition(tester, entry.definitions.first);
      expectNoRawJson(tester);
      expect(find.textContaining('expression with tooth'), findsWidgets);
    });

    testWidgets('invalid json falls back to plain text (never braces of '
        'a half-parsed node)', (tester) async {
      // corruption/cut-off in the middle: not valid json, do not crash
      await pumpDefinition(tester, '[{"tag":"ul" broken');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
