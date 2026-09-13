import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cifra_band/features/home/data/music_search_service.dart';

Future<void> main() async {
  final service = MusicSearchService();
  final client = http.Client();
  final rows = <Map<String, Object?>>[];
  try {
    for (final query in [
      'por que ele vive 545',
      'bondade de deus isaias saad',
      'galileu fernandinho',
      'aquieta minhalma ministerio zoe',
      'fernandinho',
      'alvo mais que a neve harpa crista',
      'tempo perdido legiao urbana',
      'bonddade de deus',
    ]) {
      final clock = Stopwatch()..start();
      int? first;
      try {
        final result = await service.search(
          query,
          onUpdate: (_) => first ??= clock.elapsedMilliseconds,
        );
        final elapsed = clock.elapsedMilliseconds;
        final cachedClock = Stopwatch()..start();
        await service.search(query);
        rows.add({
          'query': query,
          'firstMs': first,
          'totalMs': elapsed,
          'cachedMs': cachedClock.elapsedMilliseconds,
          'count': result.songs.length,
          'firstTitle': result.songs.firstOrNull?['trackName'],
          'partial': result.partial,
        });
      } catch (e) {
        rows.add({
          'query': query,
          'error': e.toString(),
          'totalMs': clock.elapsedMilliseconds,
        });
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    for (var i = 0; i < 5; i++) {
      final clock = Stopwatch()..start();
      try {
        final response = await client
            .get(Uri.https('cifraband-api.onrender.com', '/app-version'))
            .timeout(const Duration(seconds: 70));
        rows.add({
          'endpoint': 'app-version',
          'attempt': i + 1,
          'status': response.statusCode,
          'totalMs': clock.elapsedMilliseconds,
        });
      } catch (e) {
        rows.add({
          'endpoint': 'app-version',
          'error': e.toString(),
          'totalMs': clock.elapsedMilliseconds,
        });
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final output = const JsonEncoder.withIndent('  ').convert({
      'measuredAt': DateTime.now().toUtc().toIso8601String(),
      'scope':
          'Desktop network; metadata search without Firebase token; no phone frame or cold-state instrumentation',
      'rows': rows,
    });
    await File('build/audit-response-times.json').writeAsString(output);
    stdout.writeln(output);
  } finally {
    service.close();
    client.close();
  }
}
