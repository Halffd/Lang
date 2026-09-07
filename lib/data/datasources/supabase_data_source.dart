import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDataSource {
  final SupabaseClient _supabase;

  SupabaseDataSource(this._supabase);

  String? get userId => _supabase.auth.currentUser?.id;
  SupabaseClient get _client => _supabase;

  RealtimeChannel subscribeToUserChannel() {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    return _client.channel('user:$uid');
  }

  // --- Profiles ---
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = userId;
    if (uid == null) return null;
    return await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
  }

  Future<void> updateProfile(Map<String, dynamic> profile) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('profiles').upsert({'id': uid, ...profile});
  }

  // --- Saved Words ---
  Future<List<Map<String, dynamic>>> getSavedWords() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('saved_words')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> saveSavedWord(Map<String, dynamic> word) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('saved_words')
        .upsert({
          'user_id': uid,
          'word': word['word'],
          'reading': word['reading'],
          'sentence': word['sentence'],
          'frequency': word['frequency'],
          'context': word['context'],
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  Future<void> deleteSavedWord(String id) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('saved_words').delete().eq('id', id).eq('user_id', uid);
  }

  Future<Map<String, dynamic>?> getSavedWordByWord(String word) async {
    final uid = userId;
    if (uid == null) return null;
    return await _supabase
        .from('saved_words')
        .select()
        .eq('user_id', uid)
        .eq('word', word)
        .maybeSingle();
  }

  // --- Favorites ---
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('favorites')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addFavorite(Map<String, dynamic> favorite) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('favorites')
        .insert({
          'user_id': uid,
          'word_id': favorite['word_id'],
          'word': favorite['word'],
        })
        .select()
        .single();
    return response;
  }

  Future<void> removeFavorite(String id) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('favorites').delete().eq('id', id).eq('user_id', uid);
  }

  // --- Seen Words ---
  Future<List<Map<String, dynamic>>> getSeenWords({int limit = 100}) async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('seen_words')
        .select()
        .eq('user_id', uid)
        .order('seen_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> markWordSeen(String word, {String? wordId}) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('seen_words')
        .insert({
          'user_id': uid,
          'word': word,
          'word_id': wordId,
          'seen_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  // --- Learned Words ---
  Future<List<Map<String, dynamic>>> getLearnedWords() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('learned_words')
        .select()
        .eq('user_id', uid)
        .order('learned_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> markWordLearned(String word, {String? wordId, int? learnedLevel}) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('learned_words')
        .upsert({
          'user_id': uid,
          'word': word,
          'word_id': wordId,
          'learned_level': learnedLevel,
          'learned_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  // --- Chats ---
  Future<List<Map<String, dynamic>>> getChats() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('chats')
        .select()
        .eq('user_id', uid)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createChat({String? title, String chatType = 'default', Map<String, dynamic>? metadata}) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('chats')
        .insert({
          'user_id': uid,
          'title': title,
          'chat_type': chatType,
          'metadata': metadata ?? {},
        })
        .select()
        .single();
    return response;
  }

  Future<void> updateChat(String chatId, {String? title, Map<String, dynamic>? metadata}) async {
    final uid = userId;
    if (uid == null) return;
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (title != null) updates['title'] = title;
    if (metadata != null) updates['metadata'] = metadata;
    await _supabase.from('chats').update(updates).eq('id', chatId).eq('user_id', uid);
  }

  Future<void> deleteChat(String chatId) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('chats').delete().eq('id', chatId).eq('user_id', uid);
  }

  // --- Chat Messages ---
  Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('chat_messages')
        .select()
        .eq('user_id', uid)
        .eq('chat_id', chatId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String chatId,
    required String role,
    required String content,
    int? tokens,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('chat_messages')
        .insert({
          'user_id': uid,
          'chat_id': chatId,
          'role': role,
          'content': content,
          'tokens': tokens,
          'metadata': metadata ?? {},
        })
        .select()
        .single();
    return response;
  }

  // --- App Settings ---
  Future<Map<String, dynamic>> getAppSettings() async {
    final uid = userId;
    if (uid == null) return {};
    final response = await _supabase
        .from('app_settings')
        .select()
        .eq('user_id', uid);
    return {for (var r in response) r['key'] as String: r['value']};
  }

  Future<void> setAppSetting(String key, dynamic value) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('app_settings').upsert({
      'user_id': uid,
      'key': key,
      'value': value,
    }, onConflict: 'user_id,key');
  }

  Future<void> deleteAppSetting(String key) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('app_settings').delete().eq('user_id', uid).eq('key', key);
  }

  // --- SRS Decks ---
  Future<List<Map<String, dynamic>>> getSrsDecks() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('srs_decks')
        .select()
        .eq('user_id', uid);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createSrsDeck({
    required String name,
    String? description,
    String icon = '📚',
    String color = '#3B82F6',
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('srs_decks')
        .insert({
          'user_id': uid,
          'name': name,
          'description': description,
          'icon': icon,
          'color': color,
        })
        .select()
        .single();
    return response;
  }

  Future<void> updateSrsDeck(String deckId, {String? name, String? description, String? icon, String? color}) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('srs_decks').update({
      'name': ?name,
      'description': ?description,
      'icon': ?icon,
      'color': ?color,
    }).eq('id', deckId).eq('user_id', uid);
  }

  Future<void> deleteSrsDeck(String deckId) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('srs_decks').delete().eq('id', deckId).eq('user_id', uid);
  }

  // --- SRS Cards ---
  Future<List<Map<String, dynamic>>> getSrsCards({String? deckId, bool? dueOnly}) async {
    final uid = userId;
    if (uid == null) return [];
    var query = _supabase.from('srs_cards').select().eq('user_id', uid);
    if (deckId != null) {
      query = query.eq('deck_id', deckId);
    }
    if (dueOnly == true) {
      query = query.lte('due_date', DateTime.now().toIso8601String());
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createSrsCard({
    required String front,
    required String back,
    String? deckId,
    String? wordId,
    String? reading,
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('srs_cards')
        .insert({
          'user_id': uid,
          'deck_id': deckId,
          'word_id': wordId,
          'front': front,
          'back': back,
          'reading': reading,
        })
        .select()
        .single();
    return response;
  }

  Future<void> updateSrsCard(String cardId, Map<String, dynamic> updates) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('srs_cards').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cardId).eq('user_id', uid);
  }

  Future<void> deleteSrsCard(String cardId) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('srs_cards').delete().eq('id', cardId).eq('user_id', uid);
  }

  // --- SRS Reviews ---
  Future<List<Map<String, dynamic>>> getSrsReviews({String? cardId, int limit = 50}) async {
    final uid = userId;
    if (uid == null) return [];
    
    var query = _supabase
        .from('srs_reviews')
        .select()
        .eq('user_id', uid);
    
    if (cardId != null) {
      query = query.eq('card_id', cardId) as dynamic;
    }
    
    final response = await query.order('reviewed_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> recordSrsReview({
    required String cardId,
    required int rating,
    int? timeTakenMs,
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('srs_reviews')
        .insert({
          'user_id': uid,
          'card_id': cardId,
          'rating': rating,
          'time_taken_ms': timeTakenMs,
        })
        .select()
        .single();
    return response;
  }

  // --- User Dictionaries ---
  Future<List<Map<String, dynamic>>> getUserDictionaries() async {
    final uid = userId;
    if (uid == null) return [];
    final response = await _supabase
        .from('user_dictionaries')
        .select()
        .eq('user_id', uid)
        .order('installed_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> addUserDictionary(Map<String, dynamic> dict) async {
    final uid = userId;
    if (uid == null) throw Exception('Not authenticated');
    final response = await _supabase
        .from('user_dictionaries')
        .upsert({
          'user_id': uid,
          'title': dict['title'],
          'version': dict['version'],
          'language': dict['language'],
          'entry_count': dict['entry_count'],
          'description': dict['description'],
          'source': dict['source'],
          'language_code': dict['language_code'],
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  Future<void> deleteUserDictionary(String id) async {
    final uid = userId;
    if (uid == null) return;
    await _supabase.from('user_dictionaries').delete().eq('id', id).eq('user_id', uid);
  }

  // --- Sync helpers ---
  Future<void> syncSavedWords(List<Map<String, dynamic>> localWords) async {
    final uid = userId;
    if (uid == null) return;
    final remoteWords = await getSavedWords();
    final remoteWordsMap = {for (var w in remoteWords) w['word'] as String: w};

    for (final local in localWords) {
      final word = local['word'] as String;
      if (!remoteWordsMap.containsKey(word)) {
        await saveSavedWord(local);
      } else {
        final remote = remoteWordsMap[word]!;
        final remoteUpdated = DateTime.parse(remote['updated_at'] as String);
        final localUpdated = local['updated_at'] != null
            ? DateTime.parse(local['updated_at'] as String)
            : DateTime.now();
        if (localUpdated.isAfter(remoteUpdated)) {
          await saveSavedWord(local);
        }
      }
    }
  }

  // --- Realtime Streams ---
  Stream<List<Map<String, dynamic>>> watchSavedWords() {
    final uid = userId;
    if (uid == null) return const Stream.empty();
    return _supabase.from('saved_words').select().eq('user_id', uid).asStream();
  }

  Stream<List<Map<String, dynamic>>> watchSrsCards() {
    final uid = userId;
    if (uid == null) return const Stream.empty();
    return _supabase.from('srs_cards').select().eq('user_id', uid).asStream();
  }

  Stream<List<Map<String, dynamic>>> watchChats() {
    final uid = userId;
    if (uid == null) return const Stream.empty();
    return _supabase.from('chats').select().eq('user_id', uid).order('updated_at', ascending: false).asStream();
  }

  Stream<List<Map<String, dynamic>>> watchChatMessages(String chatId) {
    final uid = userId;
    if (uid == null) return const Stream.empty();
    return _supabase
        .from('chat_messages')
        .select()
        .eq('user_id', uid)
        .eq('chat_id', chatId)
        .order('created_at', ascending: true)
        .asStream();
  }
}