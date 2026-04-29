import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/widgets/search/search_responsive_layout.dart';

void main() {
  group('SearchResponsiveLayout', () {
    testWidgets('should show stacked layout on small screens', (WidgetTester tester) async {
      // Arrange
      final searchBar = const Placeholder(key: Key('search-bar'));
      final resultsList = const Placeholder(key: Key('results-list'));
      final detailsPanel = const Placeholder(key: Key('details-panel'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              resultsList: resultsList,
              detailsPanel: detailsPanel,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('search-bar')), findsOneWidget);
      expect(find.byKey(const Key('results-list')), findsOneWidget);
      // On small screens, details panel is not shown (only shown on desktop when not null)
      expect(find.byKey(const Key('details-panel')), findsNothing);
    });

    testWidgets('should show side-by-side layout on large screens', (WidgetTester tester) async {
      // Arrange
      final searchBar = const Placeholder(key: Key('search-bar'));
      final resultsList = const Placeholder(key: Key('results-list'));
      final detailsPanel = const Placeholder(key: Key('details-panel'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 800)), // Large screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              resultsList: resultsList,
              detailsPanel: detailsPanel,
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('search-bar')), findsOneWidget);
      expect(find.byKey(const Key('results-list')), findsOneWidget);
      expect(find.byKey(const Key('details-panel')), findsOneWidget);
      // On large screens with details panel, layout should be side-by-side (Row)
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('should not show details panel when null', (WidgetTester tester) async {
      // Arrange
      final searchBar = const Placeholder(key: Key('search-bar'));
      final resultsList = const Placeholder(key: Key('results-list'));

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              resultsList: resultsList,
              detailsPanel: null, // No details panel
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('search-bar')), findsOneWidget);
      expect(find.byKey(const Key('results-list')), findsOneWidget);
      expect(find.byKey(const Key('details-panel')), findsNothing);
    });

    testWidgets('should arrange widgets in column on small screens', (WidgetTester tester) async {
      // Arrange
      final searchBar = Container(key: const Key('search-bar'), height: 100);
      final resultsList = Container(key: const Key('results-list'), height: 500);

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              resultsList: resultsList,
            ),
          ),
        ),
      );

      // Assert
      final searchBarFinder = find.byKey(const Key('search-bar'));
      final resultsListFinder = find.byKey(const Key('results-list'));

      expect(searchBarFinder, findsOneWidget);
      expect(resultsListFinder, findsOneWidget);

      // Verify they are arranged vertically (Column)
      final searchBarTop = tester.getTopLeft(searchBarFinder).dy;
      final resultsListTop = tester.getTopLeft(resultsListFinder).dy;

      expect(resultsListTop, greaterThan(searchBarTop));
    });
  });
}