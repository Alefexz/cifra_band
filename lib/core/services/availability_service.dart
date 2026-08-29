import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilityService {
  static String dateId(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<bool> isUnavailable({
    required String uid,
    required DateTime date,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('availability')
        .doc(dateId(date))
        .get();
    return snapshot.exists;
  }

  static Future<Set<String>> unavailableUserIds({
    required Iterable<String> uids,
    required DateTime date,
  }) async {
    final entries = await Future.wait(
      uids.map((uid) async {
        final unavailable = await isUnavailable(uid: uid, date: date);
        return MapEntry(uid, unavailable);
      }),
    );

    return entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
  }
}
