import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountLocalDataService {
  AccountLocalDataService._();
  static final session = ValueNotifier<String?>(null);
  static SharedPreferences? _prefs;

  // Called before showing login or account-switch UI. Pin even a signed-out
  // startup so ownerless legacy data cannot be claimed by the next login.
  static Future<void> initialize(String? startupUid) async {
    final prefs = await SharedPreferences.getInstance();
    const ownerKey = 'legacy_local_data_owner';
    if (!prefs.containsKey(ownerKey)) {
      if (!await prefs.setString(ownerKey, startupUid ?? '')) {
        throw StateError('Could not pin legacy data owner.');
      }
    }
    if (startupUid != null && prefs.getString(ownerKey) == startupUid) {
      final store = AccountLocalDataStore(prefs, startupUid);
      final favorites = prefs.getStringList('favorite_songs');
      if (favorites != null) {
        final merged = <String, String>{};
        for (final raw in [...store.loadFavorites(), ...favorites]) {
          var identity = 'raw:$raw';
          try {
            final decoded = jsonDecode(raw);
            if (decoded is Map &&
                decoded['id'] is String &&
                (decoded['id'] as String).isNotEmpty) {
              identity = 'id:${decoded['id']}';
            }
          } on FormatException {
            // Keep unknown legacy bytes without losing otherwise valid entries.
          }
          merged.putIfAbsent(identity, () => raw);
        }
        await store.saveFavorites(merged.values.toList());
        await prefs.remove('favorite_songs');
      }
      for (final key
          in prefs
              .getKeys()
              .where((key) => key.startsWith('song_note_'))
              .toList()) {
        final target = store.noteKey(key.substring('song_note_'.length));
        if (!prefs.containsKey(target)) {
          if (!await prefs.setString(target, prefs.getString(key) ?? '')) {
            throw StateError('Could not migrate annotation.');
          }
        }
        await prefs.remove(key);
      }
    }
    _prefs = prefs;
    setSession(startupUid);
  }

  static void setSession(String? uid) => session.value = uid;

  static Future<void> eraseAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('deleted_local_$uid', true);
    if (session.value == uid) setSession(null);
    final ownsLegacy = prefs.getString('legacy_local_data_owner') == uid;
    for (final key in prefs.getKeys().toList()) {
      if (key == 'favorite_songs_$uid' ||
          key.startsWith('account_note_${uid}_') ||
          key.startsWith('offline_v2_${uid}_') ||
          (ownsLegacy &&
              (key == 'favorite_songs' || key.startsWith('song_note_'))) ||
          key.startsWith('offline_cult_setlist')) {
        if (!await prefs.remove(key))
          throw StateError('Falha ao apagar dados locais.');
      }
    }
    if (ownsLegacy) await prefs.setString('legacy_local_data_owner', '');
  }

  static AccountLocalDataStore? get current {
    final uid = session.value;
    final prefs = _prefs;
    return uid == null || prefs == null
        ? null
        : AccountLocalDataStore(prefs, uid);
  }
}

class AccountLocalDataStore {
  AccountLocalDataStore(this.prefs, this.uid);
  final SharedPreferences prefs;
  final String uid;
  String get favoritesKey => 'favorite_songs_$uid';
  String noteKey(String songKey) => 'account_note_${uid}_$songKey';

  List<String> loadFavorites() => prefs.getStringList(favoritesKey) ?? [];
  Future<void> saveFavorites(List<String> songs) async {
    if (prefs.getBool('deleted_local_$uid') == true) return;
    if (!await prefs.setStringList(favoritesKey, songs)) {
      throw StateError('Could not save favorites.');
    }
  }

  String loadNote(String songKey) => prefs.getString(noteKey(songKey)) ?? '';
  Future<void> saveNote(String songKey, String note) async {
    if (prefs.getBool('deleted_local_$uid') == true) return;
    final saved = note.trim().isEmpty
        ? await prefs.remove(noteKey(songKey))
        : await prefs.setString(noteKey(songKey), note.trim());
    if (!saved) throw StateError('Could not save annotation.');
  }
}
