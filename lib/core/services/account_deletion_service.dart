import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'account_local_data_service.dart';
import 'app_diagnostics_service.dart';
import 'push_notification_service.dart';

class AccountDeletionService {
  static const pageUrl = 'https://cifraband-api.onrender.com/account-deletion';
  static const _pendingKey = 'account_deletion_pending';
  static final pending = ValueNotifier<Map<String, dynamic>?>(null);

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['localCleared'] == true) {
      await prefs.remove(_pendingKey);
    } else {
      pending.value = data;
    }
  }

  static Future<Map<String, dynamic>> call(
    String action,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final token = authenticated
        ? await FirebaseAuth.instance.currentUser?.getIdToken(true)
        : null;
    if (authenticated && token == null) throw StateError('Entre novamente.');
    final response = await http
        .post(
          Uri.https('cifraband-api.onrender.com', '/account/deletion/$action'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('Servidor indisponivel. Tente novamente.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountDeletionException(
        response.statusCode,
        '${data['message'] ?? 'Nao foi possivel confirmar a solicitacao.'}',
      );
    }
    return data;
  }

  static Future<void> request(
    String password,
    Map<String, String> successors,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) throw StateError('Entre novamente.');
    await user!.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: password),
    );
    final random = Random.secure();
    final receipt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final data = <String, dynamic>{'uid': user.uid, 'receipt': receipt};
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_pendingKey, jsonEncode(data))) {
      throw StateError('Nao foi possivel guardar o protocolo.');
    }
    try {
      await call('request', {
        'confirm': true,
        'receipt': receipt,
        'successors': successors,
      });
    } on AccountDeletionException catch (error) {
      if (error.status >= 400 && error.status < 500) {
        await prefs.remove(_pendingKey);
      }
      rethrow;
    } finally {
      // A timeout is ambiguous. Keep the receipt so a restart can verify acceptance.
      if (prefs.containsKey(_pendingKey)) pending.value = data;
    }
  }

  static Future<void> clearLocal() async {
    final data = pending.value;
    if (data == null || data['localCleared'] == true) return;
    await AccountLocalDataService.eraseAccount(data['uid'] as String);
    await PushNotificationService.detachBeforeSignOut();
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
    await FirebaseAuth.instance.signOut();
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
    await FirebaseAnalytics.instance.resetAnalyticsData();
    await FirebaseCrashlytics.instance.setUserIdentifier('');
    await FirebaseCrashlytics.instance.setCustomKey('uid', '');
    await FirebaseCrashlytics.instance.setCustomKey('is_admin', false);
    AppDiagnosticsService.setContext({'auth': 'signed_out'});
    AppDiagnosticsService.clear();
    final prefs = await SharedPreferences.getInstance();
    final cleaned = <String, dynamic>{
      'receipt': data['receipt'],
      'localCleared': true,
    };
    if (!await prefs.setString(_pendingKey, jsonEncode(cleaned))) {
      throw StateError('Nao foi possivel registrar a limpeza local.');
    }
    pending.value = cleaned;
  }

  static Future<void> cancelUnaccepted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    pending.value = null;
  }
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
