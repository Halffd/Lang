import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/srs_card.dart';
import '../services/storage_service.dart';

class SRSService extends ChangeNotifier {
  final StorageService _storageService;
  
  List<SRSCard> _cards = [];
  bool _initialized = false;

  SRSService(this._storageService);

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadCards();
    _initialized = true;
  }

  Future<void> _loadCards() async {
    final cardsJson = _storageService.getStringList('srs_cards') ?? [];
    _cards = cardsJson.map((json) => SRSCard.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> _saveCards() async {
    final cardsJson = _cards.map((card) => jsonEncode(card.toJson())).toList();
    await _storageService.setStringList('srs_cards', cardsJson);
    notifyListeners();
  }

  List<SRSCard> get allCards => _cards;

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
        interval: 0,
        easeFactor: 2.5,
        repetition: 0,
        nextReview: DateTime.now(),
        reviewHistory: [],
      );
      await updateCard(resetCard);
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
    };

    for (final card in _cards) {
      if (card.nextReview.isBefore(now)) {
        stats['due'] = stats['due']! + 1;
      } else {
        stats['upcoming'] = stats['upcoming']! + 1;
      }

      if (card.repetition == 0) {
        stats['new'] = stats['new']! + 1;
      } else if (card.repetition < 3) {
        stats['learning'] = stats['learning']! + 1;
      } else {
        stats['review'] = stats['review']! + 1;
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