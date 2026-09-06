import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendWarmupService {
  static const String _versionUrl =
      'https://cifraband-api.onrender.com/app-version';
  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _minimumInterval = Duration(minutes: 5);

  static bool _inFlight = false;
  static DateTime? _lastWakeAt;

  static void wake({String reason = 'app_start', bool force = false}) {
    final now = DateTime.now();

    if (_inFlight) return;

    if (!force &&
        _lastWakeAt != null &&
        now.difference(_lastWakeAt!) < _minimumInterval) {
      return;
    }

    _inFlight = true;
    _lastWakeAt = now;
    unawaited(_wake(reason));
  }

  static Future<void> _wake(String reason) async {
    try {
      final response = await http
          .get(
            Uri.parse(_versionUrl),
            headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(_timeout);
      debugPrint('Cifra Band API acordada ($reason): ${response.statusCode}');
    } catch (error) {
      debugPrint('Falha ao acordar API ($reason): $error');
    } finally {
      _inFlight = false;
    }
  }
}
