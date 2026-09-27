import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';
import 'package:lang/domain/entities/popup_dictionary_config.dart';
import 'package:lang/utils/cjk_text_extractor.dart';

/// Item 7: the hover popup should work on any screen, including the reader.
///
/// The popup controller hit-tests the pointer through the render tree and
/// [CjkTextExtractor] only recognises [RenderParagraph]. The reader's text
/// mode renders a SelectableText, so this verifies the extraction path
/// actually reaches reader text rather than silently returning null.
void main() {
  final config = PopupDictionaryConfig();

  Finder readerInput() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText == 'Paste or type text to read…',
  );

  Future<void> pumpReader(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DocumentReaderScreen())),
    );
    await tester.pump();
    await tester.enterText(readerInput(), '日本語を勉強します');
    await tester.pump();
  }

  group('CjkTextExtractor reaches reader text', () {
    testWidgets('finds text under the pointer in a SelectableText', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: SelectableText('日本語を勉強します'))),
        ),
      );
      await tester.pump();

      final extractor = CjkTextExtractor();
      final center = tester.getCenter(find.text('日本語を勉強します'));
      final result = extractor.extractAt(center, config);
      expect(result, isNotNull);
      expect(result!.sentence, contains('日本語'));
    });

    testWidgets('reader text mode exposes extractable text', (tester) async {
      await pumpReader(tester);

      final extractor = CjkTextExtractor();
      // the reader renders SelectableText, whose hit path is a
      // RenderEditable rather than a RenderParagraph
      final selectable = find.byType(SelectableText);
      expect(selectable, findsOneWidget);
      final rect = tester.getRect(selectable);
      String? found;
      for (var dx = rect.left + 4; dx < rect.right && found == null; dx += 6) {
        final result = extractor.extractAt(
          Offset(dx, rect.top + rect.height / 2),
          config,
        );
        if (result != null) found = result.sentence;
      }
      expect(
        found,
        isNotNull,
        reason: 'reader text must be hit-testable for the hover popup',
      );
    });
  });
}
