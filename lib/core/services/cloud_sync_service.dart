import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:lang/core/services/full_backup_service.dart';
import 'package:lang/core/services/supabase_service.dart';

/// Cross-device sync of settings + AppStorage documents + dictionaries
/// through a Supabase `lang_sync` table:
///
///   create table lang_sync (
///     user_id text not null,
///     key text not null,
///     payload text not null,
///     updated_at timestamptz not null default now(),
///     primary key (user_id, key)
///   );
///   alter table lang_sync enable row level security;
///   create policy "own rows" on lang_sync
///     for all using (auth.uid() = user_id);
///
/// `pushAll` uploads the current state; `pullAll` downloads and applies
/// it (replacing local). Requires Supabase auth (anonymous sign-in
/// counts).
class CloudSyncService {
  final SupabaseService _supabase;
  final FullBackupService _backup;

  CloudSyncService({SupabaseService? supabase, FullBackupService? backup})
    : _supabase = supabase ?? SupabaseService(),
      _backup = backup ?? FullBackupService();

  static const String _table = 'lang_sync';
  static const String _payloadKey = 'full_backup_v1';

  bool get isAvailable =>
      _supabase.isInitialized && _supabase.currentUserId != null;

  String get _userId => _supabase.currentUserId ?? '';

  /// Upload the current state. Returns the backup size in bytes.
  Future<int> pushAll() async {
    if (!isAvailable) throw Exception('cloud sync requires Supabase sign-in');
    final zip = await _backup.buildBackup();
    final payload = base64Encode(zip);
    await _supabase.client.from(_table).upsert({
      'user_id': _userId,
      'key': _payloadKey,
      'payload': payload,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return zip.length;
  }

  /// Download the remote state and apply it locally (replaces settings,
  /// documents and dictionaries with the uploaded versions). Returns the
  /// restored counts.
  Future<({int settings, int docs, int dictionaries})> pullAll() async {
    if (!isAvailable) throw Exception('cloud sync requires Supabase sign-in');
    final rows = await _supabase.client
        .from(_table)
        .select('payload')
        .eq('user_id', _userId)
        .eq('key', _payloadKey)
        .limit(1);
    if (rows.isEmpty) {
      throw Exception('nothing uploaded from another device yet');
    }
    final payload = rows.first['payload']?.toString() ?? '';
    if (payload.isEmpty) throw Exception('empty cloud backup');
    final zip = base64Decode(payload);
    return _backup.restore(zip);
  }

  /// True when the cloud has a backup newer than nothing (i.e. any row).
  Future<bool> hasRemoteBackup() async {
    if (!isAvailable) return false;
    final rows = await _supabase.client
        .from(_table)
        .select('updated_at')
        .eq('user_id', _userId)
        .eq('key', _payloadKey)
        .limit(1);
    return rows.isNotEmpty;
  }
}
