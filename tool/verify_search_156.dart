import 'dart:convert';
import 'package:cifra_band/features/home/data/music_search_service.dart';

Future<void> main() async {
  final service = MusicSearchService();
  try {
    for (final query in [
      'jorgeve mayheus',
      'Jorge e Matheus',
      'Jorge & Mateus',
      'Sol Nos Olhos',
      'Fernandinho',
      'Gabriela Rocha',
      'porque ele vive 545',
      'Bonddade de Deus',
    ]) {
      final watch = Stopwatch()..start();
      final result = await service.search(query);
      // Metadata only: no lyrics, credentials or user data.
      print(
        jsonEncode({
          'query': query,
          'ms': watch.elapsedMilliseconds,
          'artist': result.artist?['artistName'],
          'artistIntent': result.artist?['artistIntent'],
          'firstSongs': result.songs
              .take(3)
              .map((s) => '${s['trackName']} - ${s['artistName']}')
              .toList(),
          'partial': result.partial,
        }),
      );
    }
  } finally {
    service.close();
  }
}
