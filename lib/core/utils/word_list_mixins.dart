import 'package:flutter/foundation.dart';
import '../../domain/entities/dictionary_entry.dart';
import '../services/storage_service.dart';

/// Mixin for managing saved words
mixin SavedWordsMixin {
  late StorageService _savedWordsStorage;
  bool _savedWordsStorageInitialized = false;
  final Set<String> _savedWords = {};
  bool _savedWordsLoading = false;

  void setStorageService(StorageService storageService) {
    _savedWordsStorage = storageService;
    _savedWordsStorageInitialized = true;
  }

  Set<String> get savedWords => _savedWords;

  Future<void> loadSavedWords() async {
    if (!_savedWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for saved words');
      return;
    }
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
    if (!_savedWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for saved words');
      return;
    }
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
  late StorageService _deletedWordsStorage;
  bool _deletedWordsStorageInitialized = false;
  final Set<String> _deletedWords = {};
  bool _deletedWordsLoading = false;

  void setStorageService(StorageService storageService) {
    _deletedWordsStorage = storageService;
    _deletedWordsStorageInitialized = true;
  }

  Set<String> get deletedWords => _deletedWords;

  Future<void> loadDeletedWords() async {
    if (!_deletedWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for deleted words');
      return;
    }
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
    if (!_deletedWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for deleted words');
      return;
    }
    try {
      await _deletedWordsStorage.addToDeletedWords(word);
      _deletedWords.add(word);
    } catch (e) {
      debugPrint('Error deleting word: $e');
    }
  }

  Future<void> undeleteWord(String word) async {
    if (!_deletedWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for deleted words');
      return;
    }
    try {
      await _deletedWordsStorage.removeFromDeletedWords(word);
      _deletedWords.remove(word);
    } catch (e) {
      debugPrint('Error undeleting word: $e');
    }
  }

  bool isWordDeleted(String word) => _deletedWords.contains(word);
}

/// Mixin for managing Anki words
mixin AnkiWordsMixin {
  late StorageService _ankiWordsStorage;
  bool _ankiWordsStorageInitialized = false;
  final Set<String> _ankiWords = {};
  bool _ankiWordsLoading = false;

  void setStorageService(StorageService storageService) {
    _ankiWordsStorage = storageService;
    _ankiWordsStorageInitialized = true;
  }

  Set<String> get ankiWords => _ankiWords;

  Future<void> loadAnkiWords() async {
    if (!_ankiWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for Anki words');
      return;
    }
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
    if (!_ankiWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for Anki words');
      return;
    }
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
  late StorageService _favoriteWordsStorage;
  bool _favoriteWordsStorageInitialized = false;
  final Set<String> _favoriteWords = {};
  bool _favoriteWordsLoading = false;

  void setStorageService(StorageService storageService) {
    _favoriteWordsStorage = storageService;
    _favoriteWordsStorageInitialized = true;
  }

  Set<String> get favoriteWords => _favoriteWords;

  Future<void> loadFavoriteWords() async {
    if (!_favoriteWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for favorite words');
      return;
    }
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
    if (!_favoriteWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for favorite words');
      return;
    }
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

/// Mixin for managing SRS words
mixin SRSWordsMixin {
  late StorageService _srsWordsStorage;
  bool _srsWordsStorageInitialized = false;
  final Set<String> _srsWords = {};
  bool _srsWordsLoading = false;

  void setStorageService(StorageService storageService) {
    _srsWordsStorage = storageService;
    _srsWordsStorageInitialized = true;
  }

  Set<String> get srsWords => _srsWords;

  Future<void> loadSRSWords() async {
    if (!_srsWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for SRS words');
      return;
    }
    _srsWordsLoading = true;
    try {
      final words = await _srsWordsStorage.getSRSWords();
      _srsWords.addAll(words);
    } catch (e) {
      debugPrint('Error loading SRS words: $e');
    } finally {
      _srsWordsLoading = false;
    }
  }

  Future<void> toggleSRSWord(String word, {required bool isInSRS}) async {
    if (!_srsWordsStorageInitialized) {
      debugPrint('Warning: Storage service not initialized for SRS words');
      return;
    }
    try {
      if (isInSRS) {
        await _srsWordsStorage.addToSRSWords(word);
        _srsWords.add(word);
      } else {
        await _srsWordsStorage.removeFromSRSWords(word);
        _srsWords.remove(word);
      }
    } catch (e) {
      debugPrint('Error toggling SRS word: $e');
    }
  }

  bool isWordInSRS(String word) => _srsWords.contains(word);
}

/// Combined mixin that includes all word list functionalities
mixin AllWordListsMixin on SavedWordsMixin, DeletedWordsMixin, AnkiWordsMixin, FavoriteWordsMixin, SRSWordsMixin {

  // You can add combined methods here if needed
  bool isWordInAnyList(String word) {
    return isWordSaved(word) ||
           isWordInAnki(word) ||
           isWordFavorite(word) ||
           isWordDeleted(word) ||
           isWordInSRS(word);
  }

  Future<void> removeWordFromAllLists(String word) async {
    try {
      await Future.wait([
        if (isWordSaved(word)) toggleSavedWord(word, isSaved: false),
        if (isWordInAnki(word)) toggleAnkiWord(word, isAnki: false),
        if (isWordFavorite(word)) toggleFavoriteWord(word, isFavorite: false),
        if (isWordInSRS(word)) toggleSRSWord(word, isInSRS: false),
        if (!isWordDeleted(word)) deleteWord(word),
      ]);
    } catch (e) {
      debugPrint('Error removing word from all lists: $e');
      rethrow;
    }
  }
}
