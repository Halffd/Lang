import '../entities/srs_card.dart';
import '../entities/srs_deck.dart';
import '../entities/srs_review.dart';

abstract class SrsRepository {
  Future<List<SrsDeck>> getDecks();
  Future<SrsDeck> createDeck(String name, {String? description, String? icon, String? color});
  Future<void> updateDeck(SrsDeck deck);
  Future<void> deleteDeck(String deckId);

  Future<List<SrsCard>> getCardsByDeck(String deckId);
  Future<List<SrsCard>> getDueCards({int? limit});
  Future<SrsCard> createCard(SrsCard card);
  Future<void> updateCard(SrsCard card);
  Future<void> deleteCard(String cardId);
  Future<SrsCard> reviewCard(String cardId, int rating, {int? timeTakenMs});

  Future<List<SrsReview>> getReviewHistory({int? limit});
  Future<Map<String, int>> getStats();

  Future<void> sync();
}