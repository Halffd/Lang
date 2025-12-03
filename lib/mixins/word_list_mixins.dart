import 'package:flutter/foundation.dart';
import '../models/dictionary_entry.dart';
import '../services/storage_service.dart';

/// Mixin for managing saved words
mixin SavedWordsMixin {
  final StorageService _savedWordsStorage = StorageService();
  final Set<String> _savedWords = {};
  bool _savedWordsLoading = false;

  Set<String> get savedWords => _savedWords;

  Future<void> loadSavedWords() async {
    _savedWordsLoading = true;
    try {
      final words = await _savedWordsStorage.getSavedWords();
      _savedWords.addAll(words);
    } catch (e) {
      debugPrint('Error loading saved words: $e');
    } finally {
      _savedWordsLoading = false;
    }
  }

  Future<void> toggleSavedWord(String word, {required bool isSaved}) async {
    try {
      if (isSaved) {
        await _savedWordsStorage.saveWord(word);
        _savedWords.add(word);
      } else {
        await _savedWordsStorage.removeWord(word);
        _savedWords.remove(word);
      }
    } catch (e) {
      debugPrint('Error toggling saved word: $e');
    }
  }

  bool isWordSaved(String word) => _savedWords.contains(word);
}

/// Mixin for managing deleted words
mixin DeletedWordsMixin {
  final StorageService _deletedWordsStorage = StorageService();
  final Set<String> _deletedWords = {};
  bool _deletedWordsLoading = false;

  Set<String> get deletedWords => _deletedWords;

  Future<void> loadDeletedWords() async {
    _deletedWordsLoading = true;
    try {
      final words = await _deletedWordsStorage.getDeletedWords();
      _deletedWords.addAll(words);
    } catch (e) {
      debugPrint('Error loading deleted words: $e');
    } finally {
      _deletedWordsLoading = false;
    }
  }

  Future<void> deleteWord(String word) async {
    try {
      await _deletedWordsStorage.addToDeletedWords(word);
      _deletedWords.add(word);
    } catch (e) {
      debugPrint('Error deleting word: $e');
    }
  }

  bool isWordDeleted(String word) => _deletedWords.contains(word);
}

/// Mixin for managing Anki words
mixin AnkiWordsMixin {
  final StorageService _ankiWordsStorage = StorageService();
  final Set<String> _ankiWords = {};
  bool _ankiWordsLoading = false;

  Set<String> get ankiWords => _ankiWords;

  Future<void> loadAnkiWords() async {
    _ankiWordsLoading = true;
    try {
      final words = await _ankiWordsStorage.getAnkiWords();
      _ankiWords.addAll(words);
    } catch (e) {
      debugPrint('Error loading Anki words: $e');
    } finally {
      _ankiWordsLoading = false;
    }
  }

  Future<void> toggleAnkiWord(String word, {required bool isAnki}) async {
    try {
      if (isAnki) {
        await _ankiWordsStorage.addToAnkiWords(word);
        _ankiWords.add(word);
      } else {
        await _ankiWordsStorage.removeFromAnkiWords(word);
        _ankiWords.remove(word);
      }
    } catch (e) {
      debugPrint('Error toggling Anki word: $e');
    }
  }

  bool isWordInAnki(String word) => _ankiWords.contains(word);
}

/// Mixin for managing favorite words
mixin FavoriteWordsMixin {
  final StorageService _favoriteWordsStorage = StorageService();
  final Set<String> _favoriteWords = {};
  bool _favoriteWordsLoading = false;

  Set<String> get favoriteWords => _favoriteWords;

  Future<void> loadFavoriteWords() async {
    _favoriteWordsLoading = true;
    try {
      final words = await _favoriteWordsStorage.getFavoriteWords();
      _favoriteWords.addAll(words);
    } catch (e) {
      debugPrint('Error loading favorite words: $e');
    } finally {
      _favoriteWordsLoading = false;
    }
  }

  Future<void> toggleFavoriteWord(String word, {required bool isFavorite}) async {
    try {
      if (isFavorite) {
        await _favoriteWordsStorage.addToFavorites(word);
        _favoriteWords.add(word);
      } else {
        await _favoriteWordsStorage.removeFromFavorites(word);
        _favoriteWords.remove(word);
      }
    } catch (e) {
      debugPrint('Error toggling favorite word: $e');
    }
  }

  bool isWordFavorite(String word) => _favoriteWords.contains(word);
}

/// Combined mixin that includes all word list functionalities
mixin AllWordListsMixin on SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin {

  // You can add combined methods here if needed
  bool isWordInAnyList(String word) {
    return isWordSaved(word) ||
           isWordInAnki(word) ||
           isWordFavorite(word) ||
           isWordDeleted(word);
  }

  Future<void> removeWordFromAllLists(String word) async {
    try {
      await Future.wait([
        if (isWordSaved(word)) toggleSavedWord(word, isSaved: false),
        if (isWordInAnki(word)) toggleAnkiWord(word, isAnki: false),
        if (isWordFavorite(word)) toggleFavoriteWord(word, isFavorite: false),
        if (!isWordDeleted(word)) deleteWord(word),
      ]);
    } catch (e) {
      debugPrint('Error removing word from all lists: $e');
      rethrow;
    }
  }
}
