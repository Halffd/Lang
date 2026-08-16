import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/presentation/widgets/search/search_responsive_layout.dart';

void main() {
  group('SearchResponsiveLayout', () {
    testWidgets('should show stacked layout on small screens', (
      WidgetTester tester,
    ) async {
      // Arrange
      final searchBar = Container(key: const Key('search-bar'), height: 100);
      final resultsList = Container(
        key: const Key('results-list'),
        height: 500,
      );
      final detailsPanel = Container(
        key: const Key('details-panel'),
        height: 500,
        color: Colors.blue,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              results: resultsList,
              sidePanel: detailsPanel,
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

    testWidgets('should show side-by-side layout on large screens', (
      WidgetTester tester,
    ) async {
      // Arrange
      final searchBar = Container(key: const Key('search-bar'), height: 100);
      final resultsList = Container(
        key: const Key('results-list'),
        height: 500,
      );
      final detailsPanel = Container(
        key: const Key('details-panel'),
        height: 500,
        color: Colors.blue,
      );

      // Act - use SizedBox to provide explicit constraints
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1200,
            height: 800,
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              results: resultsList,
              sidePanel: detailsPanel,
              showSidePanel: true,
            ),
          ),
        ),
      );

      // Debug: print all widgets
      print(tester.allWidgets.toString());

      // Assert - check that Row is used (side-by-side layout)
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('should not show details panel when null', (
      WidgetTester tester,
    ) async {
      // Arrange
      final searchBar = Container(key: const Key('search-bar'), height: 100);
      final resultsList = Container(
        key: const Key('results-list'),
        height: 500,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              results: resultsList,
              sidePanel: null, // No details panel
            ),
          ),
        ),
      );

      // Assert
      expect(find.byKey(const Key('search-bar')), findsOneWidget);
      expect(find.byKey(const Key('results-list')), findsOneWidget);
      expect(find.byKey(const Key('details-panel')), findsNothing);
    });

    testWidgets('should arrange widgets in column on small screens', (
      WidgetTester tester,
    ) async {
      // Arrange
      final searchBar = Container(key: const Key('search-bar'), height: 100);
      final resultsList = Container(
        key: const Key('results-list'),
        height: 500,
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)), // Small screen
            child: SearchResponsiveLayout(
              searchBar: searchBar,
              results: resultsList,
            ),
          ),
        ),
      );

      // Assert
      final searchBarFinder = find.byKey(const Key('search-bar'));
      final resultsListFinder = find.byKey(const Key('results-list'));

      expect(searchBarFinder, findsOneWidget);
      expect(resultsListFinder, findsOneWidget);

      // On small screens, layout should be column
      expect(find.byType(Column), findsOneWidget);
    });
  });
}
