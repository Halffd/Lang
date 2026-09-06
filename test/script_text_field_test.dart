import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/widgets/script_text_field.dart';

void main() {
  testWidgets('ScriptTextField builds without focus re-parent crash',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptTextField(
            controller: controller,
            language: 'ja',
            enabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    controller.dispose();
  });

  testWidgets('ScriptTextField focus and type converts romaji to kana',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptTextField(
            controller: controller,
            language: 'ja',
            enabled: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // focus and type 'neko'
    await tester.enterText(find.byType(TextField), 'neko');
    await tester.pump();

    // conversion happens per syllable: n..e -> ね...
    // after typing full word the tail should be converted
    expect(controller.text, isNot('neko'));
    controller.dispose();
  });

  testWidgets('ScriptTextField multiple instances share nothing',
      (tester) async {
    // Regression: FocusNode double-attach threw
    // "Tried to make a child into a parent of itself" when the
    // same node was passed to both Focus and TextField.
    final c1 = TextEditingController();
    final c2 = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScriptTextField(
                controller: c1,
                language: 'ja',
                enabled: true,
              ),
              ScriptTextField(
                controller: c2,
                language: 'ru',
                enabled: true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    c1.dispose();
    c2.dispose();
  });

  testWidgets('ScriptTextField with external focus node works',
      (tester) async {
    // The OCR input passes its own focus node
    final controller = TextEditingController();
    final node = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScriptTextField(
            controller: controller,
            language: 'ko',
            enabled: true,
            focusNode: node,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(node.canRequestFocus, isTrue);
    controller.dispose();
    node.dispose();
  });
}