import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  SupabaseClient get client => _client;

  /// Whether the Supabase client exists at all.
  ///
  /// `Supabase.client` is a `late` field and `Supabase.instance`
  /// asserts when the SDK was never initialized, so reading either
  /// before [init] throws. The app ships without Supabase credentials
  /// by default, so every caller has to ask this question before
  /// touching the client.
  bool get isConfigured {
    try {
      // ignore: unnecessary_statements
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isInitialized =>
      isConfigured && _client.auth.currentSession != null;

  String? get currentUserId {
    if (!isConfigured) return null;
    return _client.auth.currentUser?.id;
  }

  Future<void> init({required String url, required String anonKey}) async {
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
