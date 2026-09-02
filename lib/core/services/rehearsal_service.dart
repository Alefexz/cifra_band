import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RehearsalStatus {
  final bool rehearsed;
  final String note;
  final DateTime? updatedAt;

  const RehearsalStatus({
    required this.rehearsed,
    required this.note,
    this.updatedAt,
  });

  factory RehearsalStatus.fromMap(Map<String, dynamic>? data) {
    return RehearsalStatus(
      rehearsed: data?['rehearsed'] == true,
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
          'note': note?.trim() ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
