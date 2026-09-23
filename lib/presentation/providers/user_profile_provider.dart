import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:lang/core/services/realtime_sync_service.dart';
import 'package:lang/data/datasources/supabase_data_source.dart';
import 'package:lang/domain/entities/user_profile.dart';

/// Single source of truth for the user's profile. Loads from local prefs at
/// startup, syncs to Supabase when available, realtime-pulled.
class UserProfileProvider extends ChangeNotifier {
  final SupabaseDataSource? _ds;
  final RealtimeSyncService? _syncService;

  UserProfile _profile = const UserProfile();
  bool _syncing = false;
  String? _error;

  UserProfileProvider({
    SupabaseDataSource? ds,
    RealtimeSyncService? syncService,
  }) : _ds = ds,
       _syncService = syncService;

  UserProfile get profile => _profile;
  bool get syncing => _syncing;
  String? get error => _error;
  bool get hasRemote => _ds != null;

  static const _kPrefsKey = 'user_profile';

  Future<void> init() async {
    await _loadLocal();
    await pull();
    _subRealtime();
  }

  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsKey);
    if (raw == null) return;
    try {
      _profile = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      notifyListeners();
    } catch (_) {
      /* keep defaults */
    }
  }

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefsKey, jsonEncode(_profile.toJson()));
  }

  void _subRealtime() {
    _syncService?.onTableChange('user_profiles', (table, newRow, oldRow) {
      if (newRow == null) return;
      try {
        final remote = UserProfile.fromJson(newRow);
        // last-write-wins by updated_at
        if (remote.updatedAt != null &&
            (_profile.updatedAt == null ||
                remote.updatedAt!.isAfter(_profile.updatedAt!))) {
          _profile = remote;
          notifyListeners();
          _saveLocal();
        }
      } catch (_) {
        /* malformed row, skip */
      }
    });
  }

  Future<void> pull() async {
    final ds = _ds;
    if (ds == null) return;
    _syncing = true;
    _error = null;
    notifyListeners();
    try {
      final row = await ds.getUserProfile();
      if (row != null) {
        final remote = UserProfile.fromJson(row);
        if (remote.updatedAt != null &&
            (_profile.updatedAt == null ||
                remote.updatedAt!.isAfter(_profile.updatedAt!))) {
          _profile = remote;
          await _saveLocal();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> update(UserProfile next) async {
    _profile = next.copyWith();
    await _saveLocal();
    notifyListeners();
    // best-effort: push to cloud if available
    final ds = _ds;
    if (ds == null) return;
    try {
      await ds.saveUserProfile(_profile.toJson());
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setDisplayName(String name) =>
      update(_profile.copyWith(displayName: name));
  Future<void> setLanguages(List<String> langs, String target) => update(
    _profile.copyWith(languages: langs, currentTargetLanguage: target),
  );

  Future<void> setStats({
    int? xp,
    int? gems,
    int? streak,
    int? dailyGoal,
    int? cardsMastered,
  }) => update(
    _profile.copyWith(
      xp: xp,
      gems: gems,
      streak: streak,
      dailyGoal: dailyGoal,
      cardsMastered: cardsMastered,
    ),
  );
}
