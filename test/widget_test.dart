// Basic Flutter widget test for the Lang app search screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lang/presentation/screens/search_screen.dart';
import 'package:lang/domain/entities/app_state.dart';
import 'package:lang/core/services/storage_service.dart';
import 'package:lang/presentation/providers/analyzer_provider.dart';

void main() {
  testWidgets('Search screen shows properly', (WidgetTester tester) async {
    final mockStorageService = MockStorageService();

    final analyzerProvider = AnalyzerProvider();

    await tester.pumpWidget(
      MaterialApp(
        title: 'Lang Test',
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppState(mockStorageService)),
            ChangeNotifierProvider(create: (_) => analyzerProvider),
          ],
          child: const SearchScreen(),
        ),
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The search screen shows the search input area
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Search for a word...'), findsOneWidget);

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
  String getStringSync(String key) => '';

  @override
  Future<String?> getString(String key) async => '';
}
