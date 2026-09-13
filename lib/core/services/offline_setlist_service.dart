import 'dart:convert';

import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineSetlistSummary {
  final String scheduleId;
  final String title;
  final int songCount;
  final DateTime savedAt;

  const OfflineSetlistSummary({
    required this.scheduleId,
    required this.title,
    required this.songCount,
    required this.savedAt,
  });
}

class OfflineCultSetlist {
  final String scheduleId;
  final String title;
  final List<SongModel> songs;
  final DateTime savedAt;

  const OfflineCultSetlist({
    required this.scheduleId,
    required this.title,
    required this.songs,
    required this.savedAt,
  });
}

class OfflineSetlistService {
  static Future<OfflineSetlistStore> _store() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Entre na conta para acessar downloads.');
    return OfflineSetlistStore(await SharedPreferences.getInstance(), uid);
  }

  static Future<void> saveCultSetlist({
    required String scheduleId,
    required String title,
    required List<SongModel> songs,
  }) async => (await _store()).saveCultSetlist(
    scheduleId: scheduleId,
    title: title,
    songs: songs,
  );
  static Future<List<OfflineSetlistSummary>> listSummaries() async =>
      (await _store()).listSummaries();
  static Future<OfflineCultSetlist?> loadCultSetlist(String id) async =>
      (await _store()).loadCultSetlist(id);
  static Future<bool> isCultSetlistSaved(String id) async =>
      (await _store()).isCultSetlistSaved(id);
  static Future<void> deleteCultSetlist(String id) async =>
      (await _store()).deleteCultSetlist(id);

  // Old downloads have no owner. Restore only after checking server permission;
  // keep the original bytes untouched when offline or access is denied.
  static Future<void> migrateAuthorizedLegacy() async {
    final store = await _store();
    for (final raw
        in store.prefs.getStringList('offline_cult_setlists_index') ??
            <String>[]) {
      try {
        final id = (jsonDecode(raw) as Map)['scheduleId'] as String;
        if (await store.loadCultSetlist(id) != null) continue;
        final doc = await FirebaseFirestore.instance
            .collection('schedules')
            .doc(id)
            .get(const GetOptions(source: Source.server));
        if (!doc.exists || FirebaseAuth.instance.currentUser?.uid != store.uid)
          return;
        final legacy = store.prefs.getString('offline_cult_setlist_$id');
        if (legacy == null) continue;
        final data = Map<String, dynamic>.from(jsonDecode(legacy) as Map)
          ..['uid'] = store.uid
          ..['schema'] = 2;
        await store.prefs.setString(store._setlistKey(id), jsonEncode(data));
        final restored = await store.loadCultSetlist(id);
        if (restored != null)
          await store._upsertSummary(
            store.prefs,
            OfflineSetlistSummary(
              scheduleId: id,
              title: restored.title,
              songCount: restored.songs.length,
              savedAt: restored.savedAt,
            ),
          );
      } catch (_) {
        /* Not authorized or offline: leave legacy data quarantined. */
      }
    }
  }
}

class OfflineSetlistStore {
  OfflineSetlistStore(this.prefs, this.uid);
  final SharedPreferences prefs;
  final String uid;
  String get _indexKey => 'offline_v2_${uid}_index';

  String _setlistKey(String scheduleId) => 'offline_v2_${uid}_$scheduleId';

  Future<void> saveCultSetlist({
    required String scheduleId,
    required String title,
    required List<SongModel> songs,
  }) async {
    final savedAt = DateTime.now();
    final payload = {
      'uid': uid,
      'schema': 2,
      'scheduleId': scheduleId,
      'title': title,
      'savedAt': savedAt.toIso8601String(),
      'songs': songs.map((song) => song.toMap()..['id'] = song.id).toList(),
    };

    await prefs.setString(_setlistKey(scheduleId), jsonEncode(payload));
    await _upsertSummary(
      prefs,
      OfflineSetlistSummary(
        scheduleId: scheduleId,
        title: title,
        songCount: songs.length,
        savedAt: savedAt,
      ),
    );
  }

  Future<List<OfflineSetlistSummary>> listSummaries() async {
    final rawList = prefs.getStringList(_indexKey) ?? [];
    final summaries = <OfflineSetlistSummary>[];

    for (final raw in rawList) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (await loadCultSetlist(data['scheduleId']?.toString() ?? '') == null)
          continue;
        summaries.add(
          OfflineSetlistSummary(
            scheduleId: data['scheduleId']?.toString() ?? '',
            title: data['title']?.toString() ?? 'Setlist offline',
            songCount: int.tryParse(data['songCount']?.toString() ?? '') ?? 0,
            savedAt:
                DateTime.tryParse(data['savedAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      } catch (_) {
        // Ignora registros antigos corrompidos.
      }
    }

    summaries.removeWhere((summary) => summary.scheduleId.isEmpty);
    summaries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return summaries;
  }

  Future<OfflineCultSetlist?> loadCultSetlist(String scheduleId) async {
    final raw = prefs.getString(_setlistKey(scheduleId));
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['uid'] != uid ||
          data['schema'] != 2 ||
          data['scheduleId'] != scheduleId)
        return null;
      final rawSongs = data['songs'];
      final songs = rawSongs is List
          ? rawSongs
                .whereType<Map>()
                .map(
                  (song) => SongModel.fromMap(
                    Map<String, dynamic>.from(song),
                    song['id']?.toString() ?? '',
                  ),
                )
                .toList()
          : <SongModel>[];
      if (songs.isEmpty ||
          songs.any(
            (song) => song.content.trim().isEmpty || song.title.trim().isEmpty,
          ))
        return null;

      return OfflineCultSetlist(
        scheduleId: scheduleId,
        title: data['title']?.toString() ?? 'Setlist offline',
        songs: songs,
        savedAt:
            DateTime.tryParse(data['savedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> isCultSetlistSaved(String scheduleId) async {
    return await loadCultSetlist(scheduleId) != null;
  }

  Future<void> deleteCultSetlist(String scheduleId) async {
    await prefs.remove(_setlistKey(scheduleId));
    final summaries = await listSummaries();
    final updated = summaries
        .where((summary) => summary.scheduleId != scheduleId)
        .map(_summaryToJson)
        .toList();
    await prefs.setStringList(_indexKey, updated);
  }

  Future<void> _upsertSummary(
    SharedPreferences prefs,
    OfflineSetlistSummary summary,
  ) async {
    final summaries = await listSummaries();
    final all = [
      summary,
      ...summaries.where((item) => item.scheduleId != summary.scheduleId),
    ];
    for (final old in all.skip(20)) {
      await prefs.remove(_setlistKey(old.scheduleId));
    }
    final updated = all.take(20).map(_summaryToJson).toList();
    await prefs.setStringList(_indexKey, updated);
  }

  static String _summaryToJson(OfflineSetlistSummary summary) {
    return jsonEncode({
      'scheduleId': summary.scheduleId,
      'title': summary.title,
      'songCount': summary.songCount,
      'savedAt': summary.savedAt.toIso8601String(),
    });
  }
}
