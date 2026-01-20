import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:lang/utils/html_renderer.dart';

void main() {
  group('HtmlRenderer Tests', () {
    testWidgets('renderHtml returns SizedBox.shrink for empty content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtml(''),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renderHtmlSafe returns SizedBox.shrink for empty content', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(''),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renderHtmlSafe handles JSON-encoded HTML', (WidgetTester tester) async {
      final jsonString = '"<p>Test paragraph</p>"';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(jsonString),
          ),
        ),
      );

      // Should render the HTML content inside the JSON string
      expect(find.text('Test paragraph'), findsOneWidget);
    });

    testWidgets('renderHtmlSafe handles invalid JSON gracefully', (WidgetTester tester) async {
      final invalidJson = '{invalid json}';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(invalidJson),
          ),
        ),
      );

      // Should render as plain text when JSON is invalid
      expect(find.text(invalidJson), findsOneWidget);
    });

    testWidgets('renderHtmlSafe handles non-string JSON', (WidgetTester tester) async {
      final jsonNumber = '123';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(jsonNumber),
          ),
        ),
      );

      // Should render the string representation of the non-string JSON
      expect(find.text('123'), findsOneWidget);
    });

    testWidgets('renderHtml renders basic HTML tags', (WidgetTester tester) async {
      final htmlContent = '<p>This is a paragraph</p><div>This is a div</div>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtml(htmlContent),
          ),
        ),
      );

      // Should render the HTML content
      expect(find.text('This is a paragraph'), findsOneWidget);
      expect(find.text('This is a div'), findsOneWidget);
    });

    testWidgets('renderHtmlSafe renders basic HTML tags', (WidgetTester tester) async {
      final htmlContent = '<p>This is a paragraph</p><div>This is a div</div>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(htmlContent),
          ),
        ),
      );

      // Should render the HTML content
      expect(find.text('This is a paragraph'), findsOneWidget);
      expect(find.text('This is a div'), findsOneWidget);
    });

    testWidgets('renderHtml renders formatted text', (WidgetTester tester) async {
      final htmlContent = '<b>Bold text</b> and <i>italic text</i>';

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtml(htmlContent),
          ),
        ),
      );

      // The Html widget should be present
      expect(find.byType(Html), findsOneWidget);
    });

    testWidgets('renderHtmlSafe renders formatted text', (WidgetTester tester) async {
      final htmlContent = '<b>Bold text</b> and <i>italic text</i>';

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(htmlContent),
          ),
        ),
      );

      // The Html widget should be present
      expect(find.byType(Html), findsOneWidget);
    });

    testWidgets('renderHtml handles headings', (WidgetTester tester) async {
      final htmlContent = '<h1>Heading 1</h1><h2>Heading 2</h2><h3>Heading 3</h3>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtml(htmlContent),
          ),
        ),
      );

      // Should render the headings
      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
    });

    testWidgets('renderHtmlSafe handles headings', (WidgetTester tester) async {
      final htmlContent = '<h1>Heading 1</h1><h2>Heading 2</h2><h3>Heading 3</h3>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(htmlContent),
          ),
        ),
      );

      // Should render the headings
      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
    });

    testWidgets('renderHtml handles lists', (WidgetTester tester) async {
      final htmlContent = '<ul><li>Item 1</li><li>Item 2</li></ul><ol><li>Ordered 1</li><li>Ordered 2</li></ol>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtml(htmlContent),
          ),
        ),
      );

      // Should render the list items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Ordered 1'), findsOneWidget);
      expect(find.text('Ordered 2'), findsOneWidget);
    });

    testWidgets('renderHtmlSafe handles lists', (WidgetTester tester) async {
      final htmlContent = '<ul><li>Item 1</li><li>Item 2</li></ul><ol><li>Ordered 1</li><li>Ordered 2</li></ol>';
      
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: HtmlRenderer.renderHtmlSafe(htmlContent),
          ),
        ),
      );

      // Should render the list items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Ordered 1'), findsOneWidget);
      expect(find.text('Ordered 2'), findsOneWidget);
    });
  });
}