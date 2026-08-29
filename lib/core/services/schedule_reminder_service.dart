import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ScheduleReminderService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'cifra_band_reminders',
        'Lembretes de Escala',
        description:
            'Lembretes locais antes dos cultos em que voce foi escalado.',
        importance: Importance.high,
      );

  static bool _initialized = false;

  static Future<void> scheduleUpcomingReminders({
    required String churchId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || churchId.isEmpty) return;

    try {
      await _initialize();

      final now = DateTime.now();
      final snapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('church_id', isEqualTo: churchId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('date')
          .limit(20)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateValue = data['date'];
        if (dateValue is! Timestamp) continue;

        final assignments = List<dynamic>.from(data['team_assignments'] ?? []);
        Map<dynamic, dynamic>? myAssignment;
        for (final assignment in assignments.whereType<Map>()) {
          if (assignment['uid'] == user.uid &&
              assignment['status'] != 'declined') {
            myAssignment = assignment;
            break;
          }
        }
        if (myAssignment == null) continue;

        final scheduleDate = dateValue.toDate();
        final title = data['title']?.toString() ?? 'Culto';
        final role = myAssignment['role']?.toString() ?? 'Equipe';

        await _scheduleReminder(
          id: _notificationId(doc.id, 24),
          scheduleDate: scheduleDate.subtract(const Duration(hours: 24)),
          title: 'Escala amanhã',
          body: '$title: voce toca $role amanhã.',
          payload: doc.id,
        );

        await _scheduleReminder(
          id: _notificationId(doc.id, 2),
          scheduleDate: scheduleDate.subtract(const Duration(hours: 2)),
          title: 'Escala em 2 horas',
          body: '$title: prepare sua cifra e seu instrumento.',
          payload: doc.id,
        );
      }

      debugPrint('[Reminder] Lembretes de escala sincronizados.');
    } catch (e, stackTrace) {
      debugPrint('[Reminder] Falha ao sincronizar lembretes: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> cancelScheduleReminders(String scheduleId) async {
    await _initialize();
    await _notifications.cancel(id: _notificationId(scheduleId, 24));
    await _notifications.cancel(id: _notificationId(scheduleId, 2));
  }

  static Future<void> _scheduleReminder({
    required int id,
    required DateTime scheduleDate,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (scheduleDate.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduleDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> _initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Manaus'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(settings: settings);

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_androidChannel);
    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  static int _notificationId(String scheduleId, int hoursBefore) {
    final hash = scheduleId.codeUnits.fold<int>(
      0,
      (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
    );
    return ((hash % 1000000) * 10) + hoursBefore;
  }
}
