import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';

class PlayedHistoryService {
  static Future<void> recordSong(SongEntity song) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _buildDocId(song.artist, song.title);
    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('played_history');

    await historyRef.doc(docId).set({
      'title': song.title,
      'artist': song.artist,
      'originalKey': song.originalKey,
      'shapeKey': song.shapeKey,
      'capo': song.capo,
      'referenceUrl': song.referenceUrl,
      'rehearsalNotes': song.rehearsalNotes,
      'bpm': song.bpm,
      'content': song.content,
      'url': song.url,
      'played_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final snapshot = await historyRef
        .orderBy('played_at', descending: true)
        .limit(40)
        .get();

    final overflowDocs = snapshot.docs.skip(20);
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in overflowDocs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> deleteSongById(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('played_history')
        .doc(docId)
        .delete();
  }

  static Future<void> clearHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('played_history');
    final snapshot = await historyRef.limit(100).get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static String _buildDocId(String artist, String title) {
    final raw = '${artist}_$title'.toLowerCase();
    return raw
        .replaceAll(RegExp(r'[^a-z0-9áàãâäéèêëíìîïóòõôöúùûüçñ]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
