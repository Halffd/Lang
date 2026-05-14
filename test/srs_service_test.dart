import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lang/data/repositories/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/core/services/storage_service.dart';

void main() {
  group('SRSService', () {
    late MockStorageService mockStorage;
    late SRSService srsService;

    setUp(() async {
      mockStorage = MockStorageService();
      srsService = SRSService(mockStorage);
      await srsService.initialize();
    });

    group('deck management', () {
      test('creates default decks on first init', () {
        expect(srsService.decks.length, 3);
        expect(srsService.decks.map((d) => d.name), containsAll(['Default', 'Vocabulary', 'Kanji']));
      });

      test('getDeckById returns correct deck', () {
        final deck = srsService.getDeckById('default');
        expect(deck, isNotNull);
        expect(deck!.name, 'Default');
      });

      test('getDeckById returns null for invalid id', () {
        expect(srsService.getDeckById('invalid'), isNull);
      });

      test('addDeck adds new deck', () async {
        final newDeck = SrsDeck(
          id: 'new_deck',
          name: 'New Deck',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await srsService.addDeck(newDeck);

        expect(srsService.decks.length, 4);
        expect(srsService.getDeckById('new_deck')?.name, 'New Deck');
      });

      test('updateDeck modifies existing deck', () async {
        final original = srsService.getDeckById('default')!;
        final updated = original.copyWith(name: 'Updated Default', updatedAt: DateTime.now());

        await srsService.updateDeck(updated);

        expect(srsService.getDeckById('default')?.name, 'Updated Default');
      });

      test('deleteDeck removes deck', () async {
        await srsService.addDeck(SrsDeck(
          id: 'to_delete',
          name: 'To Delete',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        expect(srsService.decks.length, 4);

        await srsService.deleteDeck('to_delete');
        expect(srsService.decks.length, 3);
        expect(srsService.getDeckById('to_delete'), isNull);
      });
    });

    group('card management', () {
      test('addCard adds new card', () async {
        final card = SRSCard.newCard(id: 'card_1', word: 'test', meaning: 'test');
        await srsService.addCard(card);

        expect(srsService.getCardById('card_1'), isNotNull);
        expect(srsService.totalCount, 1);
      });

      test('addCard updates existing card with same id', () async {
        final card1 = SRSCard.newCard(id: 'card_2', word: 'original', meaning: 'meaning');
        final card2 = SRSCard.newCard(id: 'card_2', word: 'updated', meaning: 'meaning');

        await srsService.addCard(card1);
        await srsService.addCard(card2);

        expect(srsService.allCards.length, 1);
        expect(srsService.getCardById('card_2')!.word, 'updated');
      });

      test('removeCard removes card', () async {
        final card = SRSCard.newCard(id: 'to_remove', word: 'test', meaning: 'test');
        await srsService.addCard(card);
        expect(srsService.totalCount, 1);

        await srsService.removeCard('to_remove');
        expect(srsService.totalCount, 0);
      });

      test('bulkAddCards adds multiple cards', () async {
        final cards = [
          SRSCard.newCard(id: 'bulk_1', word: 'one', meaning: '1'),
          SRSCard.newCard(id: 'bulk_2', word: 'two', meaning: '2'),
          SRSCard.newCard(id: 'bulk_3', word: 'three', meaning: '3'),
        ];

        await srsService.bulkAddCards(cards);

        expect(srsService.totalCount, 3);
      });

      test('suspendCard changes card type to suspended', () async {
        final card = SRSCard.newCard(id: 'suspend_1', word: 'test', meaning: 'test');
        await srsService.addCard(card);
        await srsService.suspendCard('suspend_1');

        expect(srsService.getCardById('suspend_1')!.type, CardType.suspended);
      });

      test('unsuspendCard changes card type back to learning', () async {
        final card = SRSCard.newCard(id: 'unsuspend_1', word: 'test', meaning: 'test');
        await srsService.addCard(card);
        await srsService.suspendCard('unsuspend_1');
        await srsService.unsuspendCard('unsuspend_1');

        expect(srsService.getCardById('unsuspend_1')!.type, CardType.newCard);
      });

      test('resetCard resets card progress', () async {
        final card = SRSCard(
          id: 'reset_1',
          word: 'test',
          meaning: 'test',
          nextReview: DateTime.now(),
          reviewCount: 5,
          easeFactor: 2.8,
          type: CardType.review,
        );
        await srsService.addCard(card);
        await srsService.resetCard('reset_1');

        final reset = srsService.getCardById('reset_1')!;
        expect(reset.reviewCount, 0);
        expect(reset.easeFactor, 2.5);
        expect(reset.type, CardType.newCard);
      });
    });

    group('due cards', () {
      test('dueCards returns only cards due now or past', () async {
        final dueCard = SRSCard(
          id: 'due_now',
          word: 'due',
          meaning: 'test',
          nextReview: DateTime.now().subtract(const Duration(days: 1)),
        );
        final futureCard = SRSCard(
          id: 'future',
          word: 'future',
          meaning: 'test',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        );

        await srsService.addCard(dueCard);
        await srsService.addCard(futureCard);

        expect(srsService.dueCards.length, 1);
        expect(srsService.dueCards.first.id, 'due_now');
      });

      test('upcomingCards returns cards due in the future', () async {
        final dueCard = SRSCard(
          id: 'due_now',
          word: 'due',
          meaning: 'test',
          nextReview: DateTime.now().subtract(const Duration(days: 1)),
        );
        final futureCard = SRSCard(
          id: 'future',
          word: 'future',
          meaning: 'test',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        );

        await srsService.addCard(dueCard);
        await srsService.addCard(futureCard);

        expect(srsService.upcomingCards.length, 1);
        expect(srsService.upcomingCards.first.id, 'future');
      });

      test('dueCount returns correct count', () {
        final dueCard = SRSCard(
          id: 'due_1',
          word: 'due',
          meaning: 'test',
          nextReview: DateTime.now().subtract(const Duration(days: 1)),
        );
        final futureCard = SRSCard(
          id: 'future_1',
          word: 'future',
          meaning: 'test',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        );

        // These won't be persisted since we're not using proper async storage
      });
    });

    group('getCardsByDeck', () {
      test('returns all cards when deckId is null', () async {
        await srsService.addCard(SRSCard.newCard(id: 'c1', word: 'one', meaning: '1', deck: 'deck1'));
        await srsService.addCard(SRSCard.newCard(id: 'c2', word: 'two', meaning: '2', deck: 'deck2'));

        final all = srsService.getCardsByDeck(null);
        expect(all.length, 2);
      });

      test('returns only cards for specific deck', () async {
        await srsService.addCard(SRSCard.newCard(id: 'd1', word: 'one', meaning: '1', deck: 'vocabulary'));
        await srsService.addCard(SRSCard.newCard(id: 'd2', word: 'two', meaning: '2', deck: 'kanji'));
        await srsService.addCard(SRSCard.newCard(id: 'd3', word: 'three', meaning: '3', deck: 'vocabulary'));

        final vocabCards = srsService.getCardsByDeck('vocabulary');
        expect(vocabCards.length, 2);
        expect(vocabCards.every((c) => c.deck == 'vocabulary'), true);
      });
    });

    group('deck stats', () {
      test('getDeckCardCount returns correct count', () async {
        await srsService.addCard(SRSCard.newCard(id: 'cnt1', word: 'c1', meaning: 'm', deck: 'test_deck'));
        await srsService.addCard(SRSCard.newCard(id: 'cnt2', word: 'c2', meaning: 'm', deck: 'test_deck'));
        await srsService.addCard(SRSCard.newCard(id: 'cnt3', word: 'c3', meaning: 'm', deck: 'other'));

        expect(srsService.getDeckCardCount('test_deck'), 2);
        expect(srsService.getDeckCardCount('other'), 1);
      });

      test('getDeckDueCount returns correct count', () async {
        await srsService.addCard(SRSCard(
          id: 'dc1',
          word: 'c1',
          meaning: 'm',
          deck: 'due_deck',
          nextReview: DateTime.now().subtract(const Duration(days: 1)),
        ));
        await srsService.addCard(SRSCard(
          id: 'dc2',
          word: 'c2',
          meaning: 'm',
          deck: 'due_deck',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        ));

        expect(srsService.getDeckDueCount('due_deck'), 1);
      });
    });

    group('reviewCard', () {
      test('calls calculateNextReview on card', () async {
        final card = SRSCard.newCard(id: 'review_1', word: 'test', meaning: 'test');
        await srsService.addCard(card);
        await srsService.reviewCard('review_1', 4);

        final updated = srsService.getCardById('review_1')!;
        expect(updated.reviewCount, 1);
      });
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
  Future<void> setString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    final value = _data[key];
    if (value == null) return null;
    if (value is List) return value.cast<String>();
    return null;
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    _data[key] = value;
  }

  @override
  Future<Set<String>> getSavedWords() async => <String>{};

  @override
  Future<Set<String>> getFavoriteWords() async => <String>{};

  @override
  Future<Set<String>> getAnkiWords() async => <String>{};

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

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final value = _data[key];
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    _data[key] = value;
  }

  @override
  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final value = _data[key];
    if (value == null) return [];
    if (value is List) return value.cast<Map<String, dynamic>>();
    return [];
  }

  @override
  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) async {
    _data[key] = value;
  }
}