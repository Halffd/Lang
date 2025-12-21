// This is a basic Flutter widget test for the Lang app.
// Testing the core functionality without full app initialization.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lang/screens/search_screen.dart';
import 'package:lang/models/app_state.dart';
import 'package:lang/services/storage_service.dart';

void main() {
  testWidgets('Search screen shows properly', (WidgetTester tester) async {
    // Mock the StorageService to avoid actual database calls in tests
    final mockStorageService = MockStorageService();

    // Test the search screen with required providers
    await tester.pumpWidget(
      MaterialApp(
        title: 'Lang Test',
        home: ChangeNotifierProvider(
          create: (_) => AppState(mockStorageService),
          child: const SearchScreen(),
        ),
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
      ),
    );

    // The search screen should show the search input area
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search Japanese/Chinese...'), findsOneWidget);
  });
}

// Mock class for testing
class MockStorageService extends StorageService {
  @override
  Future<void> init() async {}

  @override
  Future<Set<String>> getSavedWords() async => <String>{}.toSet();

  @override
  Future<Set<String>> getFavoriteWords() async => <String>{}.toSet();

  @override
  Future<Set<String>> getAnkiWords() async => <String>{}.toSet();

  @override
  Future<void> addSavedWord(String word, {Map<String, dynamic>? details}) async {}

  @override
  Future<void> removeSavedWord(String word) async {}

  @override
  Future<void> addFavoriteWord(String word) async {}

  @override
  Future<void> removeFavoriteWord(String word) async {}

  @override
  Future<void> addAnkiWord(String word) async {}

  @override
  Future<void> removeAnkiWord(String word) async {}

  @override
  Future<bool> getAutoHideNavigation() async => false;

  @override
  Future<void> setAutoHideNavigation(bool value) async {}

  @override
  Future<String> getLanguage() async => 'ja';

  @override
  Future<void> setLanguage(String language) async {}
}
