import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lang/core/services/srs_service.dart';
import 'package:lang/domain/entities/srs_card.dart';
import 'package:lang/domain/entities/srs_deck.dart';
import 'package:lang/domain/entities/srs_review.dart';
import 'package:lang/domain/repositories/srs_repository.dart';

class SrsRepositoryImpl implements SrsRepository {
  final SrsService _srsService;
  final SupabaseClient _supabase;

  static const String _decksKey = 'srs_decks';
  static const String _cardsKey = 'srs_cards';
  static const String _reviewsKey = 'srs_reviews';

  List<SrsDeck> _decks = [];
  List<SrsCard> _cards = [];
  List<SrsReview> _reviews = [];

  SrsRepositoryImpl({
    required SrsService srsService,
    required SupabaseClient supabase,
  }) : _srsService = srsService,
       _supabase = supabase;

  Future<void> init() async {
    await _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final decksJson = prefs.getString(_decksKey);
    if (decksJson != null) {
      final List<dynamic> decksList = json.decode(decksJson);
      _decks = decksList
          .map((d) => SrsDeck.fromMap(d as Map<String, dynamic>))
          .toList();
    }

    final cardsJson = prefs.getString(_cardsKey);
    if (cardsJson != null) {
      final List<dynamic> cardsList = json.decode(cardsJson);
      _cards = cardsList
          .map((c) => SrsCard.fromMap(c as Map<String, dynamic>))
          .toList();
    }

    final reviewsJson = prefs.getString(_reviewsKey);
    if (reviewsJson != null) {
      final List<dynamic> reviewsList = json.decode(reviewsJson);
      _reviews = reviewsList
          .map((r) => SrsReview.fromMap(r as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _decksKey,
      json.encode(_decks.map((d) => d.toMap()).toList()),
    );
    await prefs.setString(
      _cardsKey,
      json.encode(_cards.map((c) => c.toMap()).toList()),
    );
    await prefs.setString(
      _reviewsKey,
      json.encode(_reviews.map((r) => r.toMap()).toList()),
    );
  }

  String? get _userId => _supabase.auth.currentUser?.id;

  @override
  Future<List<SrsDeck>> getDecks() async {
    return _decks;
  }

  @override
  Future<SrsDeck> createDeck(
    String name, {
    String? description,
    String? icon,
    String? color,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final deck = SrsDeck(
      id: SrsService.generateId(),
      name: name,
      description: description,
      icon: icon ?? '📚',
      color: color ?? '#3B82F6',
      createdAt: now,
      updatedAt: now,
    );

    _decks.add(deck);
    await _saveToLocal();
    return deck;
  }

  @override
  Future<void> updateDeck(SrsDeck deck) async {
    final index = _decks.indexWhere((d) => d.id == deck.id);
    if (index != -1) {
      _decks[index] = deck;
      await _saveToLocal();
    }
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    _decks.removeWhere((d) => d.id == deckId);
    _cards.removeWhere((c) => c.deckId == deckId);
    await _saveToLocal();
  }

  @override
  Future<List<SrsCard>> getCardsByDeck(String deckId) async {
    return _cards.where((c) => c.deckId == deckId).toList();
  }

  @override
  Future<List<SrsCard>> getDueCards({int? limit}) async {
    final dueCards = _srsService.getDueCards(_cards);
    if (limit != null) return dueCards.take(limit).toList();
    return dueCards;
  }

  @override
  Future<SrsCard> createCard(SrsCard card) async {
    final newCard = card.copyWith(userId: _userId ?? card.userId);
    _cards.add(newCard);
    await _saveToLocal();
    return newCard;
  }

  @override
  Future<void> updateCard(SrsCard card) async {
    final index = _cards.indexWhere((c) => c.id == card.id);
    if (index != -1) {
      _cards[index] = card;
      await _saveToLocal();
    }
  }

  @override
  Future<void> deleteCard(String cardId) async {
    _cards.removeWhere((c) => c.id == cardId);
    _reviews.removeWhere((r) => r.cardId == cardId);
    await _saveToLocal();
  }

  @override
  Future<SrsCard> reviewCard(
    String cardId,
    int rating, {
    int? timeTakenMs,
  }) async {
    final cardIndex = _cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) throw Exception('Card not found');

    final card = _cards[cardIndex];
    final reviewedCard = _srsService.processReview(
      card,
      ReviewRating.values.firstWhere((r) => r.value == rating),
    );

    _cards[cardIndex] = reviewedCard;

    if (_userId != null && timeTakenMs != null) {
      final reviewLog = _srsService.createReviewLog(
        userId: _userId!,
        cardId: cardId,
        rating: rating,
        timeTakenMs: timeTakenMs,
      );
      _reviews.add(reviewLog);
    }

    await _saveToLocal();
    return reviewedCard;
  }

  @override
  Future<List<SrsReview>> getReviewHistory({int? limit}) async {
    final sorted = List<SrsReview>.from(_reviews)
      ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    if (limit != null) return sorted.take(limit).toList();
    return sorted;
  }

  @override
  Future<Map<String, int>> getStats() async {
    return _srsService.getSrsStats(_cards);
  }

  // ----------------------------------------------------------
  // supabase sync: pull remote rows, merge by updatedAt
  // (last write wins), push local-only rows up
  // ----------------------------------------------------------

  @override
  Future<void> sync() async {
    final uid = _userId;
    if (uid == null) return;

    await _syncDecks(uid);
    await _syncCards(uid);
    await _syncReviews(uid);
    await _saveToLocal();
  }

  Future<void> _syncDecks(String uid) async {
    final remoteMaps = await _selectUserRows('srs_decks', uid);
    final remote = <String, SrsDeck>{};
    for (final m in remoteMaps) {
      try {
        final deck = SrsDeck.fromMap(m);
        remote[deck.id] = deck;
      } catch (_) {
        // malformed remote row: skip
      }
    }

    _decks = mergeByUpdatedAt(
      local: _decks,
      remote: remote,
      idOf: (d) => d.id,
      updatedAtOf: (d) => d.updatedAt,
    );

    // push every local deck: upsert covers both new and merged
    if (_decks.isNotEmpty) {
      await _supabase
          .from('srs_decks')
          .upsert(
            _decks.map((d) => {...d.toMap(), 'user_id': uid}).toList(),
            onConflict: 'id',
          );
    }
  }

  Future<void> _syncCards(String uid) async {
    final remoteMaps = await _selectUserRows('srs_cards', uid);
    final remote = <String, SrsCard>{};
    for (final m in remoteMaps) {
      try {
        final card = SrsCard.fromMap(m);
        remote[card.id] = card;
      } catch (_) {}
    }

    _cards = mergeByUpdatedAt(
      local: _cards,
      remote: remote,
      idOf: (c) => c.id,
      updatedAtOf: (c) => c.updatedAt,
    );

    if (_cards.isNotEmpty) {
      await _supabase
          .from('srs_cards')
          .upsert(_cards.map((c) => c.toMap()).toList(), onConflict: 'id');
    }
  }

  Future<void> _syncReviews(String uid) async {
    final remoteMaps = await _selectUserRows('srs_reviews', uid);
    final remote = <String, SrsReview>{};
    for (final m in remoteMaps) {
      try {
        final review = SrsReview.fromMap(m);
        remote[review.id] = review;
      } catch (_) {}
    }

    // reviews are append-only log entries: union by id
    final seen = _reviews.map((r) => r.id).toSet();
    for (final r in remote.values) {
      if (!seen.contains(r.id)) _reviews.add(r);
    }

    if (_reviews.isNotEmpty) {
      await _supabase
          .from('srs_reviews')
          .upsert(_reviews.map((r) => r.toMap()).toList(), onConflict: 'id');
    }
  }

  Future<List<Map<String, dynamic>>> _selectUserRows(
    String table,
    String uid,
  ) async {
    final response = await _supabase.from(table).select().eq('user_id', uid);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Merge local + remote rows by [updatedAt]; remote wins ties
  /// (server is the coordination point).
  List<T> mergeByUpdatedAt<T>({
    required List<T> local,
    required Map<String, T> remote,
    required String Function(T) idOf,
    required DateTime Function(T) updatedAtOf,
  }) {
    return mergeRowsByUpdatedAt<T>(
      local: local,
      remote: remote,
      idOf: idOf,
      updatedAtOf: updatedAtOf,
    );
  }
}

/// Pure last-write-wins row merge shared by the sync paths.
/// Remote rows newer than local replace them; local-only rows are
/// kept; remote-only rows are appended.
List<T> mergeRowsByUpdatedAt<T>({
  required List<T> local,
  required Map<String, T> remote,
  required String Function(T) idOf,
  required DateTime Function(T) updatedAtOf,
}) {
  final out = <T>[];
  final seenRemote = <String>{};
  for (final item in local) {
    final id = idOf(item);
    final r = remote[id];
    if (r == null) {
      out.add(item);
      continue;
    }
    seenRemote.add(id);
    out.add(updatedAtOf(r).isAfter(updatedAtOf(item)) ? r : item);
  }
  for (final entry in remote.entries) {
    if (!seenRemote.contains(entry.key)) out.add(entry.value);
  }
  return out;
}
