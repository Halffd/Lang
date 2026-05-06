import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  SupabaseClient get client => _client;

  bool get isInitialized => _client.auth.currentSession != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<void> init({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  Future<AuthResponse> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    await _ensureProfileExists(response.user!.id);
    return response;
  }

  Future<void> _ensureProfileExists(String userId) async {
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('profiles').insert({'id': userId});
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  RealtimeChannel subscribeToUserChannel(String userId) {
    return _client.channel('user:$userId');
  }
}