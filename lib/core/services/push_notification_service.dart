// lib/core/services/push_notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'cifra_band_alerts',
        'Alertas do Cifra Band',
        description: 'Escalas, repertorios e respostas da equipe.',
        importance: Importance.high,
      );

  static bool _localNotificationsReady = false;
  static bool _foregroundListenerReady = false;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static Future<void>? _versionRegistration;
  static String? _registeredVersionKey;
  static DateTime? _registeredVersionAt;

  static Future<void> syncInstalledVersion() async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (_versionRegistration != null) return _versionRegistration;
    final pending = _syncInstalledVersion();
    _versionRegistration = pending;
    try {
      await pending;
    } finally {
      _versionRegistration = null;
    }
  }

  static Future<void> _syncInstalledVersion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      final package = await PackageInfo.fromPlatform();
      final build = int.tryParse(package.buildNumber);
      if (build == null) return;
      final key = '${user.uid}:$token:$build';
      if (_registeredVersionKey == key &&
          _registeredVersionAt != null &&
          DateTime.now().difference(_registeredVersionAt!) <
              const Duration(hours: 6)) {
        return;
      }
      for (final delay in [0, 6, 15]) {
        if (delay > 0) await Future<void>.delayed(Duration(seconds: delay));
        if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
        try {
          final idToken = await user.getIdToken();
          if (idToken == null) return;
          final response = await http
              .post(
                Uri.https('cifraband-api.onrender.com', '/devices/register'),
                headers: {
                  'Authorization': 'Bearer $idToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'token': token,
                  'build': build,
                  'platform': 'android',
                }),
              )
              .timeout(const Duration(seconds: 25));
          if (response.statusCode == 200) {
            _registeredVersionKey = key;
            _registeredVersionAt = DateTime.now();
            return;
          }
          if (response.statusCode >= 400 && response.statusCode < 500) return;
        } catch (_) {
          // A sleeping backend may need more than one attempt.
        }
      }
      debugPrint(
        '[Push] Registro da versão pendente; será tentado na próxima abertura.',
      );
    } catch (error) {
      debugPrint('[Push] Não foi possível registrar a versão: $error');
    }
  }

  static Future<void> registerDevice() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[Push] Usuario nao logado. Registro ignorado.');
      return;
    }

    await _initializeLocalNotifications();
    await _configureForegroundMessages();
    await _requestPermission();
    await _registerCurrentToken(user.uid);
    _listenForTokenRefresh(user.uid);
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (kIsWeb) return;

    await _initializeLocalNotifications();

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: data?.entries.join('&'),
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
    );
  }

  static Future<void> _requestPermission() async {
    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('[Push] Permissao: ${settings.authorizationStatus.name}');

    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<void> _registerCurrentToken(String uid) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final token = await _messaging.getToken();

        if (token == null || token.trim().isEmpty) {
          debugPrint('[Push] FCM retornou token vazio na tentativa $attempt.');
        } else {
          await _saveToken(uid, token);
          return;
        }
      } catch (e, stackTrace) {
        debugPrint('[Push] Falha ao obter token FCM na tentativa $attempt: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
    }

    debugPrint(
      '[Push] Nao foi possivel registrar este aparelho. '
      'Confira Google Play Services, internet e se o Cloud Messaging esta ativo no Firebase.',
    );
  }

  static void _listenForTokenRefresh(String uid) {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) => _saveToken(uid, newToken),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[Push] Falha no listener de refresh do token: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[Push] Token FCM registrado com sucesso para $uid: ${_maskToken(token)}',
      );
      unawaited(syncInstalledVersion());
    } catch (e, stackTrace) {
      debugPrint('[Push] Falha ao salvar token FCM no Firestore: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(settings: initializationSettings);

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.requestNotificationsPermission();

    _localNotificationsReady = true;
    debugPrint('[Push] Notificacoes locais inicializadas.');
  }

  static Future<void> _configureForegroundMessages() async {
    if (_foregroundListenerReady) return;

    FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] == 'app_update_available') return;
      final notification = message.notification;
      final android = notification?.android;

      if (notification == null) {
        debugPrint('[Push] Mensagem em foreground sem bloco notification.');
        return;
      }

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon: android?.smallIcon,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );

      debugPrint('[Push] Notificacao exibida em foreground.');
    });

    _foregroundListenerReady = true;
  }

  static String _maskToken(String token) {
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }
}
