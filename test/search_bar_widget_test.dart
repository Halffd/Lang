import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/widgets/search/search_bar_widget.dart';

void main() {
  group('SearchBarWidget', () {
    testWidgets('should display search bar with correct properties', (WidgetTester tester) async {
      // Arrange
      final controller = TextEditingController();
      bool submitted = false;
      bool cleared = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: controller,
              onSubmitted: (value) => submitted = true,
              hintText: 'Test Hint',
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Test Hint'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should call onSubmitted when text is submitted', (WidgetTester tester) async {
      // Arrange
      final controller = TextEditingController(text: 'test input');
      bool submitted = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: controller,
              onSubmitted: (value) => submitted = true,
              hintText: 'Test Hint',
            ),
          ),
        ),
      );

      // Submit the text
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      // Assert
      expect(submitted, true);
    });

    testWidgets('should show clear button when text is present', (WidgetTester tester) async {
      // Arrange
      final controller = TextEditingController(text: 'test input');

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: controller,
              onSubmitted: (value) {},
              hintText: 'Test Hint',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('should call onClear when clear button is pressed', (WidgetTester tester) async {
      // Arrange
      final controller = TextEditingController(text: 'test input');
      bool cleared = false;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: controller,
              onSubmitted: (value) {},
              hintText: 'Test Hint',
              onClear: () => cleared = true,
            ),
          ),
        ),
      );

      // Tap the clear button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      // Assert
      expect(cleared, true);
    });

    testWidgets('should hide clear button when text is empty', (WidgetTester tester) async {
      // Arrange
      final controller = TextEditingController();

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchBarWidget(
              controller: controller,
              onSubmitted: (value) {},
              hintText: 'Test Hint',
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}