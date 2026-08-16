import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lang/core/services/supabase_service.dart';
import 'package:lang/core/services/realtime_sync_service.dart';
import 'package:lang/data/datasources/supabase_data_source.dart';

class SupabaseProvider with ChangeNotifier {
  final SupabaseService _supabaseService;
  final RealtimeSyncService _syncService;
  final SupabaseDataSource _dataSource;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _userId;
  String? get userId => _userId;

  String? _error;

  SupabaseProvider({
    required SupabaseService supabaseService,
    required RealtimeSyncService syncService,
    required SupabaseDataSource dataSource,
  })  : _supabaseService = supabaseService,
        _syncService = syncService,
        _dataSource = dataSource;

  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    if (_isInitialized) return;

    try {
      await _supabaseService.init(url: url, anonKey: anonKey);
      _isInitialized = true;
      _userId = _supabaseService.currentUserId;
      _isAuthenticated = _userId != null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Supabase init failed: $e');
      notifyListeners();
    }
  }

  Future<void> signInAnonymously() async {
    if (!_isInitialized) return;

    try {
      await _supabaseService.signInAnonymously();
      _userId = _supabaseService.currentUserId;
      _isAuthenticated = _userId != null;
      
      if (_isAuthenticated) {
        _syncService.connect();
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Anonymous sign in failed: $e');
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _syncService.disconnect();
    await _supabaseService.signOut();
    _userId = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void listenToAuthChanges() {
    _supabaseService.authStateChanges.listen((state) {
      _userId = _supabaseService.currentUserId;
      _isAuthenticated = _userId != null;
      
      if (_isAuthenticated) {
        _syncService.connect();
      } else {
        _syncService.disconnect();
      }
      
      notifyListeners();
    });
  }
}