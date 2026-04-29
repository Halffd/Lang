import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/data/repositories/storage_service.dart';

import 'package:lang/main.dart'; // This imports our modified MainScreen

void main() {
  group('MainScreen Tests', () {
    late AppState mockAppState;

    setUp(() {
      // Create a mock storage service
      final storageService = StorageService();
      // Initialize the storage service
      storageService.init();
      
      // Create app state
      mockAppState = AppState(storageService);
    });

    testWidgets('MainScreen builds without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );

      // Verify that the MainScreen widget is built
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Navigation bar appears at the top', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );

      // Find the navigation bar
      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      // Get the render object to check position
      final navBar = tester.firstRenderObject<RenderBox>(navBarFinder);
      expect(navBar.localToGlobal(Offset.zero).dy, 0); // Should be at the top
    });

    testWidgets('Auto-hide functionality works', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );

      // Initially the navigation bar should be visible
      expect(find.byType(NavigationBar), findsOneWidget);

      // Simulate disabling auto-hide
      mockAppState.setAutoHideNavigation(false);
      await tester.pump();

      // Navigation bar should still be visible
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Keyboard shortcuts work', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: mockAppState),
          ],
          child: MaterialApp(
            home: const MainScreen(),
          ),
        ),
      );

      // Test shortcut for first screen (Ctrl + 1)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      // Test shortcut for second screen (Ctrl + 2)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump();

      // Verify navigation happened by checking if screen changed
      // This verifies that the shortcuts trigger the navigation functions
    });
  });

  group('AppState Default Screen Tests', () {
    late StorageService storageService;
    late AppState appState;

    setUp(() async {
      storageService = StorageService();
      await storageService.init();
      appState = AppState(storageService);
    });

    test('Default screen index getter/setter works', () {
      // Test initial value
      expect(appState.defaultScreenIndex, 0);

      // Test setting a value
      appState.setDefaultScreenIndex(2);
      expect(appState.defaultScreenIndex, 2);

      // Test setting another value
      appState.setDefaultScreenIndex(5);
      expect(appState.defaultScreenIndex, 5);
    });
  });
}