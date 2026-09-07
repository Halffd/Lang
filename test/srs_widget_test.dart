import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/core/services/storage_service.dart';

void main() {
  group('SRSService Mock', () {
    test('SRSService can be created with mock storage', () async {
      final mockStorage = MockStorageService();
      final service = SRSService(mockStorage);
      await service.initialize();

      expect(service.totalCount, 0);
      expect(service.dueCount, 0);
    });

    test('SRSService persists cards', () async {
      final mockStorage = MockStorageService();
      final service = SRSService(mockStorage);
      await service.initialize();

      await service.addCard(
        SRSCard.newCard(id: 'persist_1', word: 'test', meaning: 'test'),
      );
      expect(service.totalCount, 1);

      await service.addCard(
        SRSCard.newCard(id: 'persist_2', word: 'test2', meaning: 'test2'),
      );
      expect(service.totalCount, 2);
    });
  });

  group('SRSCard display', () {
    testWidgets('Card shows word and meaning', (WidgetTester tester) async {
      final card = SRSCard.newCard(
        id: 'display_1',
        word: '日本語',
        meaning: 'Japanese language',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Text(card.word),
                subtitle: Text(card.meaning),
              ),
            ),
          ),
        ),
      );

      expect(find.text('日本語'), findsOneWidget);
      expect(find.text('Japanese language'), findsOneWidget);
    });

    testWidgets('Due badge shows for past due cards', (
      WidgetTester tester,
    ) async {
      final dueCard = SRSCard(
        id: 'due_card',
        word: 'test',
        meaning: 'test',
        nextReview: DateTime.now().subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                title: Text(dueCard.word),
                trailing: dueCard.isDue
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Due',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      )
                    : Text('${dueCard.interval}d'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Due'), findsOneWidget);
    });

    testWidgets('Tags display correctly', (WidgetTester tester) async {
      final card = SRSCard.newCard(
        id: 'tags_1',
        word: 'test',
        meaning: 'test',
        tags: ['jlpt-n5', 'noun', 'beginner'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: card.tags.map((t) => Chip(label: Text(t))).toList(),
            ),
          ),
        ),
      );

      expect(find.text('jlpt-n5'), findsOneWidget);
      expect(find.text('noun'), findsOneWidget);
      expect(find.text('beginner'), findsOneWidget);
    });
  });

  group('Deck display', () {
    testWidgets('Deck shows name and stats', (WidgetTester tester) async {
      final deck = SrsDeck(
        id: 'display_deck',
        name: 'JLPT N5',
        description: 'Japanese vocabulary for N5',
        icon: '🎯',
        color: '#EF4444',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(
                  int.parse(deck.color.replaceFirst('#', '0xFF')),
                ).withValues(alpha: 0.2),
                child: Text(deck.icon),
              ),
              title: Text(deck.name),
              subtitle: Text(deck.description ?? ''),
            ),
          ),
        ),
      );

      expect(find.text('JLPT N5'), findsOneWidget);
      expect(find.text('Japanese vocabulary for N5'), findsOneWidget);
      expect(find.text('🎯'), findsOneWidget);
    });
  });
}

class MockStorageService extends StorageService {
  final Map<String, dynamic> _data = {};

  @override
  Future<void> init() async {}

  @override
  Future<String?> getString(String key) async => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  List<String>? getStringList(String key) {
    final value = _data[key];
    if (value == null) return null;
    if (value is List) return value.cast<String>();
    return null;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<Set<String>> getSavedWords() async => <String>{};

  @override
  Future<Set<String>> getFavoriteWords() async => <String>{};

  @override
  Future<Set<String>> getAnkiWords() async => <String>{};
}
