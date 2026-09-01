import 'dart:collection';

import 'package:flutter/foundation.dart';

class AppDiagnosticsService {
  AppDiagnosticsService._();

  static const int _maxEntries = 80;
  static final ListQueue<Map<String, dynamic>> _entries =
      ListQueue<Map<String, dynamic>>();

  static void log(
    String message, {
    String level = 'info',
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    final entry = <String, dynamic>{
      'at': DateTime.now().toIso8601String(),
      'level': level,
      'message': message,
      if (error != null) 'error': _limit('$error', 700),
      if (stackTrace != null) 'stack': _compactStack(stackTrace),
      if (context != null && context.isNotEmpty)
        'context': _sanitizeMap(context),
    };

    _entries.add(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    debugPrint('[Diag][$level] $message${error == null ? '' : ' | $error'}');
  }

  static List<Map<String, dynamic>> recentLogs() {
    return List<Map<String, dynamic>>.unmodifiable(_entries);
  }

  static void clear() {
    _entries.clear();
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, Object?> input) {
    final result = <String, dynamic>{};

    for (final entry in input.entries.take(30)) {
      final key = _limit(entry.key, 80);
      result[key] = _sanitizeValue(entry.value);
    }

    return result;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null || value is num || value is bool) return value;

    if (value is String) return _limit(value, 500);

    if (value is Iterable) {
      return value.take(20).map(_sanitizeValue).toList(growable: false);
    }

    if (value is Map) {
      return _sanitizeMap(value.map((key, item) => MapEntry('$key', item)));
    }

    return _limit('$value', 500);
  }

  static String _compactStack(StackTrace stackTrace) {
    return stackTrace
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(8)
        .join('\n');
  }

  static String _limit(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}
