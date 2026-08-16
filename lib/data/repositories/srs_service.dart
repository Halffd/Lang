import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/core/services/storage_service.dart';

class SRSService extends ChangeNotifier {
  final StorageService _storageService;

  List<SRSCard> _cards = [];
  List<SrsDeck> _decks = [];
  bool _initialized = false;

  SRSService(this._storageService);

  Future<void> initialize() async {
    if (_initialized) return;

    await _loadCards();
    await _loadDecks();
    _initialized = true;
  }

  Future<void> _loadCards() async {
    final cardsJson = _storageService.getStringList('srs_cards') ?? [];
    _cards = cardsJson.map((json) => SRSCard.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> _loadDecks() async {
    final decksJson = _storageService.getStringList('srs_decks') ?? [];
    _decks = decksJson.map((json) => SrsDeck.fromJson(jsonDecode(json))).toList();
    if (_decks.isEmpty) {
      final now = DateTime.now();
      _decks = [
        SrsDeck(id: 'default', name: 'Default', createdAt: now, updatedAt: now),
        SrsDeck(id: 'vocabulary', name: 'Vocabulary', createdAt: now, updatedAt: now),
        SrsDeck(id: 'kanji', name: 'Kanji', createdAt: now, updatedAt: now),
      ];
      await _saveDecks();
    }
    notifyListeners();
  }

  Future<void> _saveCards() async {
    final cardsJson = _cards.map((card) => jsonEncode(card.toJson())).toList();
    await _storageService.setStringList('srs_cards', cardsJson);
    notifyListeners();
  }

  Future<void> _saveDecks() async {
    final decksJson = _decks.map((deck) => jsonEncode(deck.toJson())).toList();
    await _storageService.setStringList('srs_decks', decksJson);
    notifyListeners();
  }

  List<SRSCard> get allCards => _cards;
  List<SrsDeck> get decks => _decks;

  int getDeckCardCount(String deckId) => _cards.where((c) => c.deck == deckId).length;
  int getDeckDueCount(String deckId) {
    final now = DateTime.now();
    return _cards.where((c) => c.deck == deckId && c.nextReview.isBefore(now)).length;
  }
  SrsDeck? getDeckById(String id) {
    try {
      return _decks.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  List<SRSCard> getCardsByDeck(String? deckId) {
    if (deckId == null) return _cards;
    return _cards.where((c) => c.deck == deckId).toList();
  }

  List<SRSCard> getDueCardsByDeck(String? deckId) {
    final now = DateTime.now();
    return getCardsByDeck(deckId).where((c) => c.nextReview.isBefore(now)).toList()
      ..sort((a, b) => a.nextReview.compareTo(b.nextReview));
  }

  Future<void> addDeck(SrsDeck deck) async {
    _decks.add(deck);
    await _saveDecks();
  }

  Future<void> updateDeck(SrsDeck deck) async {
    final idx = _decks.indexWhere((d) => d.id == deck.id);
    if (idx >= 0) {
      _decks[idx] = deck;
      await _saveDecks();
    }
  }

  Future<void> deleteDeck(String deckId) async {
    _decks.removeWhere((d) => d.id == deckId);
    for (var card in _cards.where((c) => c.deck == deckId)) {
      await updateCard(card.copyWith(deck: null));
    }
    await _saveDecks();
  }

  List<SRSCard> get dueCards {
    final now = DateTime.now();
    return _cards.where((card) => card.nextReview.isBefore(now)).toList()
      ..sort((a, b) => a.nextReview.compareTo(b.nextReview));
  }

  List<SRSCard> get upcomingCards {
    final now = DateTime.now();
    return _cards.where((card) => !card.nextReview.isBefore(now)).toList()
      ..sort((a, b) => a.nextReview.compareTo(b.nextReview));
  }

  int get dueCount => dueCards.length;

  int get totalCount => _cards.length;

  SRSCard? getCardById(String id) {
    try {
      return _cards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addCard(SRSCard card) async {
    // Check if card already exists
    final existingIndex = _cards.indexWhere((c) => c.id == card.id);
    if (existingIndex != -1) {
      _cards[existingIndex] = card;
    } else {
      _cards.add(card);
    }
    await _saveCards();
  }

  Future<void> removeCard(String id) async {
    _cards.removeWhere((card) => card.id == id);
    await _saveCards();
  }

  Future<void> updateCard(SRSCard updatedCard) async {
    final index = _cards.indexWhere((card) => card.id == updatedCard.id);
    if (index != -1) {
      _cards[index] = updatedCard;
      await _saveCards();
    }
  }

  Future<void> reviewCard(String id, int quality) async {
    final card = getCardById(id);
    if (card != null) {
      final updatedCard = card.calculateNextReview(quality);
      await updateCard(updatedCard);
    }
  }

  Future<void> bulkAddCards(List<SRSCard> cards) async {
    for (final card in cards) {
      final existingIndex = _cards.indexWhere((c) => c.id == card.id);
      if (existingIndex != -1) {
        _cards[existingIndex] = card;
      } else {
        _cards.add(card);
      }
    }
    await _saveCards();
  }

  Future<void> resetCard(String id) async {
    final card = getCardById(id);
    if (card != null) {
      final resetCard = card.copyWith(
        easeFactor: 2.5,
        reviewCount: 0,
        nextReview: DateTime.now(),
        type: CardType.newCard,
      );
      await updateCard(resetCard);
    }
  }

  Future<void> suspendCard(String id) async {
    final card = getCardById(id);
    if (card != null) {
      await updateCard(card.suspend());
    }
  }

  Future<void> unsuspendCard(String id) async {
    final card = getCardById(id);
    if (card != null) {
      await updateCard(card.unsuspend());
    }
  }

  // Statistics
  Map<String, int> getReviewStats() {
    final now = DateTime.now();
    final stats = {
      'due': 0,
      'upcoming': 0,
      'total': _cards.length,
      'new': 0,
      'learning': 0,
      'review': 0,
      'suspended': 0,
    };

    for (final card in _cards) {
      if (card.type == CardType.suspended) {
        stats['suspended'] = stats['suspended']! + 1;
        continue;
      }

      if (card.nextReview.isBefore(now)) {
        stats['due'] = stats['due']! + 1;
      } else {
        stats['upcoming'] = stats['upcoming']! + 1;
      }

      switch (card.type) {
        case CardType.newCard:
          stats['new'] = stats['new']! + 1;
          break;
        case CardType.learning:
          stats['learning'] = stats['learning']! + 1;
          break;
        case CardType.review:
          stats['review'] = stats['review']! + 1;
          break;
        case CardType.suspended:
          break;
      }
    }

    return stats;
  }

  List<SRSCard> getCardsByPriority() {
    return _cards..sort((a, b) => b.priority.compareTo(a.priority));
  }

  List<SRSCard> getCardsByDifficulty() {
    return _cards..sort((a, b) => b.languageLevel.compareTo(a.languageLevel));
  }

  List<SRSCard> getCardsByDueDate() {
    return _cards..sort((a, b) => a.nextReview.compareTo(b.nextReview));
  }
}