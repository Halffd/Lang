import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/srs_service.dart';
import '../../core/services/realtime_sync_service.dart';
import '../../data/datasources/supabase_data_source.dart';
import '../../domain/entities/srs_card.dart';
import '../../domain/entities/srs_deck.dart';
import '../../domain/entities/srs_review.dart';

class SrsProvider with ChangeNotifier {
  final SrsService _srsService;
  final SupabaseDataSource _supabaseDataSource;
  final RealtimeSyncService _syncService;

  List<SrsDeck> _decks = [];
  List<SrsDeck> get decks => _decks;

  List<SrsCard> _cards = [];
  List<SrsCard> get cards => _cards;

  List<SrsCard> _dueCards = [];
  List<SrsCard> get dueCards => _dueCards;

  Map<String, int> _stats = {};
  Map<String, int> get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  SrsCard? _currentReviewCard;
  SrsCard? get currentReviewCard => _currentReviewCard;

  int _reviewIndex = 0;
  int get reviewIndex => _reviewIndex;

  SrsProvider({
    required SrsService srsService,
    required SupabaseDataSource supabaseDataSource,
    required RealtimeSyncService syncService,
  })  : _srsService = srsService,
        _supabaseDataSource = supabaseDataSource,
        _syncService = syncService;

  Future<void> init() async {
    await refreshDecks();
    await refreshCards();
    _setupRealtimeListeners();
  }

  void _setupRealtimeListeners() {
    _syncService.onSrsDecksChange((table, newRow, oldRow) {
      if (newRow != null) {
        _handleDeckUpdate(SrsDeck.fromMap(newRow));
      } else if (oldRow != null) {
        _decks.removeWhere((d) => d.id == oldRow['id']);
        notifyListeners();
      }
    });

    _syncService.onSrsCardsChange((table, newRow, oldRow) {
      if (newRow != null) {
        _handleCardUpdate(SrsCard.fromMap(newRow));
      } else if (oldRow != null) {
        _cards.removeWhere((c) => c.id == oldRow['id']);
        _updateDueCards();
        notifyListeners();
      }
    });
  }

  void _handleDeckUpdate(SrsDeck deck) {
    final index = _decks.indexWhere((d) => d.id == deck.id);
    if (index >= 0) {
      _decks[index] = deck;
    } else {
      _decks.add(deck);
    }
    notifyListeners();
  }

  void _handleCardUpdate(SrsCard card) {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index >= 0) {
      _cards[index] = card;
    } else {
      _cards.add(card);
    }
    _updateDueCards();
    notifyListeners();
  }

  void _updateDueCards() {
    _dueCards = _srsService.getDueCards(_cards);
    _stats = _srsService.getSrsStats(_cards);
  }

  Future<void> refreshDecks() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabaseDataSource.getSrsDecks();
      _decks = data.map((d) => SrsDeck.fromMap(d)).toList();
    } catch (e) {
      debugPrint('Failed to fetch decks: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCards({String? deckId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabaseDataSource.getSrsCards(deckId: deckId);
      _cards = data.map((c) => SrsCard.fromMap(c)).toList();
      _updateDueCards();
    } catch (e) {
      debugPrint('Failed to fetch cards: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<SrsDeck?> createDeck(String name, {String? description, String icon = '📚', String color = '#3B82F6'}) async {
    try {
      final deck = await _supabaseDataSource.createSrsDeck(
        name: name,
        description: description,
        icon: icon,
        color: color,
      );
      _decks.add(SrsDeck.fromMap(deck));
      notifyListeners();
      return SrsDeck.fromMap(deck);
    } catch (e) {
      debugPrint('Failed to create deck: $e');
      return null;
    }
  }

  Future<void> updateDeck(String deckId, {String? name, String? description, String? icon, String? color}) async {
    try {
      await _supabaseDataSource.updateSrsDeck(
        deckId,
        name: name,
        description: description,
        icon: icon,
        color: color,
      );
      final index = _decks.indexWhere((d) => d.id == deckId);
      if (index >= 0) {
        _decks[index] = _decks[index].copyWith(
          name: name,
          description: description,
          icon: icon,
          color: color,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update deck: $e');
    }
  }

  Future<void> deleteDeck(String deckId) async {
    try {
      await _supabaseDataSource.deleteSrsDeck(deckId);
      _decks.removeWhere((d) => d.id == deckId);
      _cards.removeWhere((c) => c.deckId == deckId);
      _updateDueCards();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete deck: $e');
    }
  }

  Future<SrsCard?> createCard({
    required String front,
    required String back,
    String? deckId,
    String? wordId,
    String? reading,
  }) async {
    try {
      final card = await _supabaseDataSource.createSrsCard(
        front: front,
        back: back,
        deckId: deckId,
        wordId: wordId,
        reading: reading,
      );
      _cards.add(SrsCard.fromMap(card));
      _updateDueCards();
      notifyListeners();
      return SrsCard.fromMap(card);
    } catch (e) {
      debugPrint('Failed to create card: $e');
      return null;
    }
  }

  Future<void> updateCard(String cardId, Map<String, dynamic> updates) async {
    try {
      await _supabaseDataSource.updateSrsCard(cardId, updates);
      final index = _cards.indexWhere((c) => c.id == cardId);
      if (index >= 0) {
        final current = _cards[index];
        _cards[index] = current.copyWith(
          front: updates['front'] as String? ?? current.front,
          back: updates['back'] as String? ?? current.back,
          reading: updates['reading'] as String? ?? current.reading,
          deckId: updates['deck_id'] as String? ?? current.deckId,
        );
        _updateDueCards();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update card: $e');
    }
  }

  Future<void> deleteCard(String cardId) async {
    try {
      await _supabaseDataSource.deleteSrsCard(cardId);
      _cards.removeWhere((c) => c.id == cardId);
      _updateDueCards();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to delete card: $e');
    }
  }

  void startReview() {
    _reviewIndex = 0;
    _dueCards = _srsService.getDueCards(_cards);
    if (_dueCards.isNotEmpty) {
      _currentReviewCard = _dueCards[0];
    }
    notifyListeners();
  }

  Future<void> answerCard(int rating) async {
    if (_currentReviewCard == null) return;

    final reviewedCard = _srsService.processReview(_currentReviewCard!, ReviewRating.values.firstWhere((r) => r.value == rating));

    try {
      await _supabaseDataSource.updateSrsCard(reviewedCard.id, {
        'ease_factor': reviewedCard.easeFactor,
        'interval': reviewedCard.interval,
        'repetitions': reviewedCard.repetitions,
        'due_date': reviewedCard.dueDate.toIso8601String(),
        'last_reviewed_at': reviewedCard.lastReviewedAt?.toIso8601String(),
      });

      await _supabaseDataSource.recordSrsReview(
        cardId: reviewedCard.id,
        rating: rating,
      );

      final index = _cards.indexWhere((c) => c.id == reviewedCard.id);
      if (index >= 0) {
        _cards[index] = reviewedCard;
      }
      _updateDueCards();
    } catch (e) {
      debugPrint('Failed to record review: $e');
    }

    _reviewIndex++;
    if (_reviewIndex < _dueCards.length) {
      _currentReviewCard = _dueCards[_reviewIndex];
    } else {
      _currentReviewCard = null;
    }
    notifyListeners();
  }

  void skipCard() {
    if (_reviewIndex < _dueCards.length - 1) {
      _reviewIndex++;
      _currentReviewCard = _dueCards[_reviewIndex];
      notifyListeners();
    }
  }

  List<SrsCard> getCardsByDeck(String deckId) {
    return _cards.where((c) => c.deckId == deckId).toList();
  }

  int getDueCountForDeck(String deckId) {
    return _dueCards.where((c) => c.deckId == deckId).length;
  }

  Future<void> sync() async {
    _isLoading = true;
    notifyListeners();

    try {
      await refreshDecks();
      await refreshCards();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}