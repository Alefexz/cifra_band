import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/songs/data/models/song_model.dart';
import '../../features/songs/data/datasources/song_scraper_datasource.dart';
import '../../features/songs/domain/song_arrangement.dart';
import 'offline_setlist_service.dart';

class PersonalSetlistService {
  static String offlineId(String id) => 'setlist:$id';
  static String songId(SongModel song) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            song.title,
            song.artist,
            song.originalKey,
            song.shapeKey,
            song.capo,
            song.content,
            song.referenceUrl,
            song.bpm,
            song.rehearsalNotes,
          ]),
        ),
      )
      .toString();

  static Future<bool> addSong(String setlistId, SongModel song) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Entre na sua conta.');
    if (song.title.trim().isEmpty ||
        song.content.trim().isEmpty ||
        song.content.length > 120000) {
      throw StateError('A cifra está vazia ou excede o limite.');
    }
    final db = FirebaseFirestore.instance;
    final parent = db.collection('setlists').doc(setlistId);
    final ref = parent.collection('songs').doc(songId(song));
    return db.runTransaction((tx) async {
      final setlist = await tx.get(parent);
      final data = setlist.data();
      if (data == null ||
          (data['ownerId'] != uid &&
              !(data['sharedWith'] as List? ?? []).contains(uid))) {
        throw StateError('Você não tem acesso a esta setlist.');
      }
      final existing = await tx.get(ref);
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('A conta mudou. Tente novamente.');
      }
      if (existing.exists) return false;
      tx.set(ref, {
        ...song.toMap(),
        'key': song.originalKey,
        'created_by': uid,
        'created_at': FieldValue.serverTimestamp(),
      });
      tx.update(parent, {
        'songIds': FieldValue.arrayUnion([ref.id]),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  static Future<void> download(
    String id, {
    required void Function(int, int) onProgress,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Entre na sua conta.');
    void checkAccount() {
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('A conta mudou. Download interrompido.');
      }
    }

    final store = OfflineSetlistStore(
      await SharedPreferences.getInstance(),
      uid,
    );
    final ref = FirebaseFirestore.instance.collection('setlists').doc(id);
    final parent = await ref
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    final data = parent.data();
    if (data == null) throw StateError('Setlist não encontrada.');
    checkAccount();
    final ids = (data['songIds'] as List? ?? [])
        .map((v) => v.toString())
        .toList();
    if (ids.isEmpty) throw StateError('Esta setlist ainda não tem músicas.');
    final previous = await store.loadCultSetlist(offlineId(id));
    final local = {
      for (final song in previous?.songs ?? <SongModel>[]) song.id: song,
    };
    final songs = await collectOfflineSongs(
      ids: ids,
      local: local,
      onProgress: onProgress,
      load: (songId) async {
        checkAccount();
        final doc = await ref
            .collection('songs')
            .doc(songId)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 20));
        final raw = doc.data();
        if (raw == null) {
          throw StateError(
            'Uma cifra não foi encontrada na setlist. Nenhum download parcial foi salvo.',
          );
        }
        final song = SongModel.fromMap({
          ...raw,
          'originalKey': raw['key'] ?? raw['originalKey'],
        }, songId);
        if (song.content.trim().isNotEmpty) return song;
        if (song.title.isEmpty || song.artist.isEmpty) {
          throw StateError('Cifra sem título ou artista.');
        }
        // The existing scraper checks the global database before the web backend.
        final found = await SongScraperDatasource().extractSongFromUrl(
          Uri.https('cifraband-api.onrender.com', '/searchSong', {
            'artist': song.artist,
            'track': song.title,
          }).toString(),
        );
        final arrangement = SongArrangement.prepare(
          song: found,
          key: song.originalKey.isEmpty ? found.originalKey : song.originalKey,
          capo: song.capo ?? '',
        );
        return SongModel(
          id: songId,
          title: song.title,
          artist: song.artist,
          originalKey: arrangement.key,
          shapeKey: arrangement.shapeKey,
          capo: song.capo,
          content: arrangement.content,
          url: found.url,
          referenceUrl: song.referenceUrl ?? found.referenceUrl,
          bpm: song.bpm,
          rehearsalNotes: song.rehearsalNotes,
        );
      },
    );
    checkAccount();
    // Recheck membership and ordering before replacing the complete offline copy.
    final latest = await ref
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 20));
    if (jsonEncode(latest.data()?['songIds'] ?? []) != jsonEncode(ids)) {
      throw StateError('A setlist mudou durante o download. Tente novamente.');
    }
    checkAccount();
    await store.saveCultSetlist(
      scheduleId: offlineId(id),
      title: data['title']?.toString() ?? 'Setlist',
      songs: songs,
    );
  }
}

Future<List<SongModel>> collectOfflineSongs({
  required List<String> ids,
  required Map<String, SongModel> local,
  required Future<SongModel> Function(String) load,
  required void Function(int, int) onProgress,
}) async {
  final songs = <SongModel>[];
  onProgress(0, ids.length);
  for (final id in ids) {
    final cached = local[id];
    final song = cached != null && cached.content.trim().isNotEmpty
        ? cached
        : await load(id);
    if (song.id != id ||
        song.title.trim().isEmpty ||
        song.content.trim().isEmpty) {
      throw StateError('Cifra incompleta: ${song.title}');
    }
    songs.add(song);
    onProgress(songs.length, ids.length);
  }
  return songs;
}
