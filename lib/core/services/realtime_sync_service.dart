import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

typedef BroadcastCallback = void Function(String table, Map<String, dynamic>? newRow, Map<String, dynamic>? oldRow);

class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  RealtimeChannel? _channel;
  final Map<String, List<BroadcastCallback>> _listeners = {};
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void connect() {
    final userId = _supabaseService.currentUserId;
    if (userId == null) return;
    if (_isConnected) return;

    _channel = _supabaseService.subscribeToUserChannel(userId);
    _channel!.onBroadcast(
      event: 'postgres_changes',
      callback: (payload, [error]) => _handleBroadcast(payload),
    ).subscribe();

    _isConnected = true;
  }

  void disconnect() {
    if (_channel != null) {
      _supabaseService.client.removeChannel(_channel!);
      _channel = null;
    }
    _isConnected = false;
  }

  void _handleBroadcast(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;

    final table = payload['table'] as String?;
    if (table == null) return;

    final newRow = payload['new'] as Map<String, dynamic>?;
    final oldRow = payload['old'] as Map<String, dynamic>?;

    final callbacks = _listeners[table];
    if (callbacks != null) {
      for (final callback in callbacks) {
        callback(table, newRow, oldRow);
      }
    }
  }

  void onTableChange(String table, BroadcastCallback callback) {
    _listeners.putIfAbsent(table, () => []).add(callback);
  }

  void offTableChange(String table, [BroadcastCallback? callback]) {
    if (callback == null) {
      _listeners.remove(table);
    } else {
      _listeners[table]?.remove(callback);
    }
  }

  void onSavedWordsChange(BroadcastCallback callback) {
    onTableChange('saved_words', callback);
  }

  void onSrsCardsChange(BroadcastCallback callback) {
    onTableChange('srs_cards', callback);
  }

  void onSrsDecksChange(BroadcastCallback callback) {
    onTableChange('srs_decks', callback);
  }

  void onFavoritesChange(BroadcastCallback callback) {
    onTableChange('favorites', callback);
  }

  void onChatMessagesChange(BroadcastCallback callback) {
    onTableChange('chat_messages', callback);
  }
}