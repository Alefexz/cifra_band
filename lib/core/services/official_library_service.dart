import 'dart:math';

import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:cifra_band/features/songs/domain/transposer_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OfficialSong {
  final String id;
  final String title;
  final String artist;
  final String originalKey;
  final String? shapeKey;
  final String? capo;
  final String? bpm;
  final String? referenceUrl;
  final String? rehearsalNotes;
  final String content;
  final String url;
  final int versionNumber;
  final DateTime? updatedAt;

  const OfficialSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.originalKey,
    this.shapeKey,
    this.capo,
    this.bpm,
    this.referenceUrl,
    this.rehearsalNotes,
    required this.content,
    required this.url,
    required this.versionNumber,
    this.updatedAt,
  });

  factory OfficialSong.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return OfficialSong(
      id: doc.id,
      title: _string(data['title'], 'Cifra sem titulo'),
      artist: _string(data['artist'], 'Artista nao informado'),
      originalKey: _string(data['originalKey'], 'C'),
      shapeKey: _nullable(data['shapeKey']),
      capo: _nullable(data['capo']),
      bpm: _nullable(data['bpm']),
      referenceUrl: _nullable(data['referenceUrl']),
      rehearsalNotes: _nullable(data['rehearsalNotes']),
      content: _string(data['content'], ''),
      url: _string(data['url'], ''),
      versionNumber: int.tryParse(data['versionNumber']?.toString() ?? '') ?? 1,
      updatedAt: data['updated_at'] is Timestamp
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
    );
  }

  SongModel toSongModel() {
    return SongModel(
      id: id,
      title: title,
      artist: artist,
      originalKey: originalKey,
      shapeKey: shapeKey,
      capo: capo,
      referenceUrl: referenceUrl,
      rehearsalNotes: rehearsalNotes,
      bpm: bpm,
      content: content,
      url: url,
    );
  }

  static String _string(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class ImportedSongDraft {
  final String title;
  final String artist;
  final String originalKey;
  final String content;

  const ImportedSongDraft({
    required this.title,
    required this.artist,
    required this.originalKey,
    required this.content,
  });
}

class OfficialSongValidation {
  final int chordCount;
  final List<String> unknownTokens;

  const OfficialSongValidation({
    required this.chordCount,
    required this.unknownTokens,
  });

  bool get isValid => chordCount > 0 && unknownTokens.length <= 8;
}

class OfficialLibraryService {
  OfficialLibraryService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Stream<List<OfficialSong>> watchOfficialSongs() async* {
    final churchId = await _currentChurchId();
    yield* _firestore
        .collection('ministries')
        .doc(churchId)
        .collection('official_songs')
        .where('archived', isEqualTo: false)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(OfficialSong.fromDoc).toList());
  }

  static Future<OfficialSong?> findOfficialSong(
    String title,
    String artist,
  ) async {
    final churchId = await _currentChurchId();
    final key = buildSongKey(title, artist);
    final doc = await _firestore
        .collection('ministries')
        .doc(churchId)
        .collection('official_songs')
        .doc(key)
        .get();
    if (!doc.exists) return null;
    return OfficialSong.fromDoc(doc);
  }

  static Future<String> saveOfficialSong({
    required String title,
    required String artist,
    required String originalKey,
    String? shapeKey,
    String? capo,
    String? bpm,
    String? referenceUrl,
    String? rehearsalNotes,
    required String content,
    String? url,
    String? existingId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Faca login para salvar a cifra.');
    final churchId = await _currentChurchId();
    final docId = (existingId?.trim().isNotEmpty ?? false)
        ? existingId!.trim()
        : buildSongKey(title, artist);
    final doc = _firestore
        .collection('ministries')
        .doc(churchId)
        .collection('official_songs')
        .doc(docId);
    final current = await doc.get();
    final version = current.exists
        ? (int.tryParse(current.data()?['versionNumber']?.toString() ?? '') ??
                  1) +
              1
        : 1;

    final payload = {
      'title': title.trim(),
      'artist': artist.trim(),
      'originalKey': TransposerEngine.normalizeKey(originalKey).isEmpty
          ? 'C'
          : TransposerEngine.normalizeKey(originalKey),
      'shapeKey': _emptyToNull(shapeKey),
      'capo': _emptyToNull(capo),
      'bpm': _emptyToNull(bpm),
      'referenceUrl': _emptyToNull(referenceUrl),
      'rehearsalNotes': _emptyToNull(rehearsalNotes),
      'content': content.trimRight(),
      'url': url?.trim() ?? '',
      'archived': false,
      'versionNumber': version,
      'updated_by': user.uid,
      'updated_at': FieldValue.serverTimestamp(),
      if (!current.exists) 'created_by': user.uid,
      if (!current.exists) 'created_at': FieldValue.serverTimestamp(),
    };

    await doc.set(payload, SetOptions(merge: true));
    await doc.collection('versions').doc('v$version').set({
      ...payload,
      'saved_at': FieldValue.serverTimestamp(),
    });
    return docId;
  }

  static Future<String> saveFromSong(SongModel song) {
    return saveOfficialSong(
      title: song.title,
      artist: song.artist,
      originalKey: song.originalKey,
      shapeKey: song.shapeKey,
      capo: song.capo,
      bpm: song.bpm,
      referenceUrl: song.referenceUrl,
      rehearsalNotes: song.rehearsalNotes,
      content: song.content,
      url: song.url,
      existingId: buildSongKey(song.title, song.artist),
    );
  }

  static Future<void> archiveSong(String songId) async {
    final churchId = await _currentChurchId();
    await _firestore
        .collection('ministries')
        .doc(churchId)
        .collection('official_songs')
        .doc(songId)
        .update({'archived': true, 'updated_at': FieldValue.serverTimestamp()});
  }

  static ImportedSongDraft parseImportedText(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    var title = '';
    var artist = '';
    var key = '';
    final contentLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('titulo:') || lower.startsWith('titulo ')) {
        title = trimmed.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('título:')) {
        title = trimmed.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('artista:')) {
        artist = trimmed.split(':').skip(1).join(':').trim();
        continue;
      }
      if (lower.startsWith('tom:')) {
        key = TransposerEngine.normalizeKey(
          trimmed.split(':').skip(1).join(':').trim(),
        );
        continue;
      }
      contentLines.add(line);
    }

    final nonEmpty = contentLines.where((line) => line.trim().isNotEmpty);
    if (title.isEmpty && nonEmpty.isNotEmpty) {
      final first = nonEmpty.first.trim();
      if (!TransposerEngine.isChordLine(first) &&
          !TransposerEngine.isHeaderLine(first)) {
        title = first;
        contentLines.remove(first);
      }
    }
    if (artist.isEmpty && contentLines.isNotEmpty) {
      final second = contentLines
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .skip(1)
          .take(1)
          .join();
      if (second.isNotEmpty &&
          !TransposerEngine.isChordLine(second) &&
          !TransposerEngine.isHeaderLine(second)) {
        artist = second;
      }
    }
    key = key.isEmpty ? _inferKey(contentLines.join('\n')) : key;

    return ImportedSongDraft(
      title: title.isEmpty ? 'Nova cifra' : title,
      artist: artist.isEmpty ? 'Artista nao informado' : artist,
      originalKey: key.isEmpty ? 'C' : key,
      content: contentLines.join('\n').trim(),
    );
  }

  static OfficialSongValidation validateContent(String content) {
    final unknown = <String>{};
    var chordCount = 0;

    for (final line in content.split('\n')) {
      if (!TransposerEngine.isChordLine(line)) continue;
      for (final token in line.trim().split(RegExp(r'\s+'))) {
        if (TransposerEngine.isChordToken(token)) {
          chordCount++;
        } else if (RegExp(r'^[A-Ga-g]').hasMatch(token)) {
          unknown.add(token);
        }
      }
    }

    return OfficialSongValidation(
      chordCount: chordCount,
      unknownTokens: unknown.take(12).toList(),
    );
  }

  static String buildSongKey(String title, String artist) {
    final normalized = '${_slug(artist)}_${_slug(title)}'
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isNotEmpty)
      return normalized.substring(0, min(180, normalized.length));
    return 'cifra_${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<String> _currentChurchId() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Faca login para acessar a biblioteca.');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final churchId = doc.data()?['church_id']?.toString() ?? '';
    if (churchId.isEmpty) {
      throw StateError(
        'Entre em um ministerio para usar a biblioteca oficial.',
      );
    }
    return churchId;
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String _inferKey(String content) {
    for (final line in content.split('\n')) {
      if (!TransposerEngine.isChordLine(line)) continue;
      for (final token in line.trim().split(RegExp(r'\s+'))) {
        if (TransposerEngine.isChordToken(token)) {
          return TransposerEngine.normalizeKey(token);
        }
      }
    }
    return 'C';
  }

  static String _slug(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .trim();
  }
}
