import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/screens/document_reader_screen.dart';

void main() {
  Widget wrap() => const MaterialApp(home: DocumentReaderScreen());

  // The nav overlay adds its own page-number TextField once text mode
  // starts, so target the reading input by its hint.
  Finder textInput() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.hintText == 'Paste or type text to read…',
  );

  group('reader text input', () {
    testWidgets('multiline field is visible on the landing screen', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      final field = textInput();
      expect(field, findsOneWidget);
      // multiline: more than one line allowed
      final tf = tester.widget<TextField>(field);
      expect(tf.maxLines, greaterThan(1));
    });

    testWidgets('there is no "Read" submit button', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Read'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Read'), findsNothing);
      expect(find.text('Paste text'), findsNothing);
    });

    testWidgets('typing switches into text mode without any button press', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      expect(find.text('Open file'), findsOneWidget);

      await tester.enterText(textInput(), 'こんにちは世界');
      await tester.pump();

      // landing replaced by the reader view
      expect(find.text('Open file'), findsNothing);
      expect(find.textContaining('こんにちは'), findsWidgets);
    });

    testWidgets('clearing the text returns to the landing screen', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(textInput(), 'hello');
      await tester.pump();
      expect(find.text('Open file'), findsNothing);

      await tester.enterText(textInput(), '');
      await tester.pump();
      expect(find.text('Open file'), findsOneWidget);
    });

    testWidgets('focusing the field does not toggle the controls away', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.enterText(textInput(), 'abc');
      await tester.pump();
      // the input must survive the tap that focused it
      expect(textInput(), findsOneWidget);
      expect(find.text('Open file'), findsNothing);
    });
  });
}
