import 'package:flutter/material.dart';
import 'package:lang/data/datasources/supabase_data_source.dart';
import 'package:lang/core/services/history_service.dart';

/// Syncs non-SRS user data (saved words, history) with Supabase when
/// authenticated. Pull-then-push merge on last-write-wins (updated_at).
///
/// Deletions are local-only in this version: rows removed on one device stay
/// on the other device and reappear after its next push. Tombstones need a
/// server-side column; documented behavior, not a bug.
class UserDataProvider with ChangeNotifier {
  final SupabaseDataSource? _dataSource;

  bool _syncing = false;
  bool get syncing => _syncing;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  String? _error;
  String? get error => _error;

  List<Map<String, dynamic>> _lastPulledWords = const [];
  List<Map<String, dynamic>> get lastPulledWords => _lastPulledWords;

  UserDataProvider({SupabaseDataSource? dataSource}) : _dataSource = dataSource;

  bool get available => _dataSource != null;

  /// Push new local saved words to the cloud; pull words that are not local.
  /// Handles the merge via [SupabaseDataSource.syncSavedWords] for writes and
  /// returns the words that exist remotely but not locally so callers can
  /// add them.
  Future<List<Map<String, dynamic>>> syncSavedWords(
    List<Map<String, dynamic>> localWords,
  ) async {
    final ds = _dataSource;
    if (ds == null) return [];

    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      await ds.syncSavedWords(localWords);
      final localSet = {for (final w in localWords) w['word'] as String};
      final remote = await ds.getSavedWords();
      final missingLocal = [
        for (final r in remote)
          if (!localSet.contains(r['word'])) r,
      ];
      _lastPulledWords = missingLocal;
      _lastSync = DateTime.now();
      return missingLocal;
    } catch (e) {
      _error = e.toString();
      debugPrint('Saved words sync failed: $e');
      return [];
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Push local history items as seen-words; history is append-only and
  /// merges naturally by id. Remote idempotent: duplicated inserts are
  /// server-side deduped only if a unique index exists, so we skip rows whose
  /// word and timestamp already exist remotely.
  Future<void> syncHistory(List<HistoryItem> localItems) async {
    final ds = _dataSource;
    if (ds == null) return;

    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final remoteSeen = await ds.getSeenWords(limit: 1000);
      final seenKeys = {
        for (final r in remoteSeen) '${r['word']}@${r['seen_at']}',
      };
      for (final item in localItems) {
        if (item.title.isEmpty) continue;
        final seenAt = DateTime.fromMillisecondsSinceEpoch(
          item.timestamp,
        ).toIso8601String();
        if (seenKeys.contains('${item.title}@$seenAt')) continue;
        await ds.markWordSeen(item.title);
      }
      _lastSync = DateTime.now();
    } catch (e) {
      _error = e.toString();
      debugPrint('History sync failed: $e');
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }
}
