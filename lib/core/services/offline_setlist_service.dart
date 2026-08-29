import 'dart:convert';

import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _indexKey = 'offline_cult_setlists_index';

  static String _setlistKey(String scheduleId) =>
      'offline_cult_setlist_$scheduleId';

  static Future<void> saveCultSetlist({
    required String scheduleId,
    required String title,
    required List<SongModel> songs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = DateTime.now();
    final payload = {
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

  static Future<List<OfflineSetlistSummary>> listSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_indexKey) ?? [];
    final summaries = <OfflineSetlistSummary>[];

    for (final raw in rawList) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
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

  static Future<OfflineCultSetlist?> loadCultSetlist(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_setlistKey(scheduleId));
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
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

  static Future<void> deleteCultSetlist(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_setlistKey(scheduleId));
    final summaries = await listSummaries();
    final updated = summaries
        .where((summary) => summary.scheduleId != scheduleId)
        .map(_summaryToJson)
        .toList();
    await prefs.setStringList(_indexKey, updated);
  }

  static Future<void> _upsertSummary(
    SharedPreferences prefs,
    OfflineSetlistSummary summary,
  ) async {
    final summaries = await listSummaries();
    final updated = [
      summary,
      ...summaries.where((item) => item.scheduleId != summary.scheduleId),
    ].take(20).map(_summaryToJson).toList();
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
