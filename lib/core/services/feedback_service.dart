import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_diagnostics_service.dart';

class FeedbackService {
  FeedbackService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Uri _feedbackUri = Uri.parse(
    'https://cifraband-api.onrender.com/feedback',
  );

  static Future<String> submitFeedback({
    required String type,
    required String severity,
    required String message,
    String? screen,
  }) async {
    final trimmedMessage = message.trim();
    if (trimmedMessage.length < 8) {
      throw ArgumentError('Descreva um pouco melhor o que aconteceu.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Você precisa estar logado para enviar feedback.');
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final token = await user.getIdToken();
    AppDiagnosticsService.log(
      'Enviando feedback',
      context: {'type': type, 'severity': severity, 'screen': screen},
    );
    final response = await http
        .post(
          _feedbackUri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'type': type,
            'severity': severity,
            'message': trimmedMessage,
            'screen': screen,
            'user': {
              'name': userData['name'] ?? user.displayName,
              'church_id': userData['church_id'],
              'is_admin': userData['is_admin'] == true,
            },
            'app': {
              'version': packageInfo.version,
              'build_number': packageInfo.buildNumber,
              'package_name': packageInfo.packageName,
            },
            'device': await _collectDeviceInfo(),
            'logs': AppDiagnosticsService.recentLogs(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      AppDiagnosticsService.log(
        'Falha HTTP ao enviar feedback',
        level: 'error',
        context: {'statusCode': response.statusCode, 'body': response.body},
      );
      throw StateError('API retornou HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    final ticketId = decoded is Map<String, dynamic>
        ? '${decoded['ticketId'] ?? ''}'
        : '';

    if (ticketId.isEmpty) {
      throw const FormatException('API não retornou o código do feedback.');
    }

    FirebaseCrashlytics.instance.log(
      'Feedback enviado: $ticketId / $type / $severity',
    );
    AppDiagnosticsService.log(
      'Feedback enviado com sucesso',
      context: {'ticketId': ticketId},
    );
    return ticketId;
  }

  static Future<Map<String, dynamic>> _collectDeviceInfo() async {
    if (kIsWeb) {
      final web = await _deviceInfo.webBrowserInfo;
      return {
        'platform': 'web',
        'browser': web.browserName.name,
        'user_agent': web.userAgent,
      };
    }

    if (Platform.isAndroid) {
      final android = await _deviceInfo.androidInfo;
      return {
        'platform': 'android',
        'brand': android.brand,
        'manufacturer': android.manufacturer,
        'model': android.model,
        'device': android.device,
        'product': android.product,
        'sdk_int': android.version.sdkInt,
        'release': android.version.release,
      };
    }

    if (Platform.isIOS) {
      final ios = await _deviceInfo.iosInfo;
      return {
        'platform': 'ios',
        'name': ios.name,
        'model': ios.model,
        'system_name': ios.systemName,
        'system_version': ios.systemVersion,
      };
    }

    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
    };
  }
}
