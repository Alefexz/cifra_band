import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'rehearsal_preparation.dart';

class RehearsalStatus {
  final bool rehearsed;
  final String note;
  final DateTime? updatedAt;
  final RehearsalPreparation preparation;

  const RehearsalStatus({
    required this.rehearsed,
    required this.note,
    this.updatedAt,
    this.preparation = const RehearsalPreparation(),
  });

  factory RehearsalStatus.fromMap(Map<String, dynamic>? data) {
    return RehearsalStatus(
      rehearsed: data?['rehearsed'] == true,
      preparation: RehearsalPreparation.fromMap(data),
      note: data?['note']?.toString() ?? '',
      updatedAt: data?['updated_at'] is Timestamp
          ? (data?['updated_at'] as Timestamp).toDate()
          : null,
    );
  }
}

class RehearsalService {
  RehearsalService._();

  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String songKey(String title, String artist) {
    return OfficialLibraryService.buildSongKey(title, artist);
  }

  static String _docId(String songKey) {
    final uid = _auth.currentUser?.uid ?? 'anon';
    return '${uid}_$songKey';
  }

  static Stream<RehearsalStatus> watchMyStatus({
    required String scheduleId,
    required String songKey,
  }) {
    return _firestore
        .collection('schedules')
        .doc(scheduleId)
        .collection('rehearsal_status')
        .doc(_docId(songKey))
        .snapshots()
        .map((doc) => RehearsalStatus.fromMap(doc.data()));
  }

  static Future<void> saveMyStatus({
    required String scheduleId,
    required String songKey,
    required String title,
    required String artist,
    required bool rehearsed,
    String? note,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Faca login para marcar ensaio.');
    await _firestore
        .collection('schedules')
        .doc(scheduleId)
        .collection('rehearsal_status')
        .doc(_docId(songKey))
        .set({
          'uid': user.uid,
          'songKey': songKey,
          'title': title,
          'artist': artist,
          'rehearsed': rehearsed,
          if (note != null) 'note': note.trim(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static Stream<Map<String, RehearsalPreparation>> watchTeam(
    String scheduleId,
  ) {
    return _firestore
        .collection('schedules')
        .doc(scheduleId)
        .collection('rehearsal_status')
        .snapshots()
        .map(
          (snapshot) => {
            for (final doc in snapshot.docs)
              doc.id: RehearsalPreparation.fromMap(doc.data()),
          },
        );
  }

  static Future<void> savePreparation({
    required String scheduleId,
    required Map<String, dynamic> song,
    PreparationStage? stage,
    String? note,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Faça login novamente.');
    if (stage == PreparationStage.needsReview) {
      throw ArgumentError('Escolha sua preparação para o arranjo atual.');
    }
    if (note != null && note.trim().length > 1500) {
      throw ArgumentError('A observação deve ter até 1500 caracteres.');
    }
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    final key = songKey(title, artist);
    final revision = RehearsalPreparation.revisionOf(song);
    final schedule = _firestore.collection('schedules').doc(scheduleId);
    final status = schedule.collection('rehearsal_status').doc('${uid}_$key');
    await _firestore.runTransaction((tx) async {
      final current = (await tx.get(schedule)).data();
      final previous = (await tx.get(status)).data();
      final songs = (current?['approved_songs'] as List?) ?? [];
      if (!songs.whereType<Map>().any(
        (entry) =>
            RehearsalPreparation.revisionOf(Map<String, dynamic>.from(entry)) ==
            revision,
      )) {
        throw StateError(
          'O repertório mudou. Reabra o ensaio antes de salvar.',
        );
      }
      // A note alone never changes readiness or acknowledges a changed arrangement.
      tx.set(status, {
        'uid': uid,
        'songKey': key,
        'title': title,
        'artist': artist,
        if (stage != null) ...{
          'preparation': stage.name,
          'rehearsed': stage == PreparationStage.ready,
          'arrangementRevision': revision,
        } else if (previous == null)
          'rehearsed': false,
        if (note != null) 'note': note.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
