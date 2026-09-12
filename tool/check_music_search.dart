import 'dart:io';
import 'package:cifra_band/features/home/data/music_search_service.dart';

Future<void> main() async {
  final service = MusicSearchService();
  try {
    for (final query in [
      'por que ele vive 545',
      '545 deus enviou',
      'bondade de deus isaias saad',
      'Fernandinho',
      'galileu',
    ]) {
      final watch = Stopwatch()..start();
      final result = await service.search(query);
      stdout.writeln(
        '$query | ${watch.elapsedMilliseconds}ms | ${result.songs.length} resultados | parcial=${result.partial}',
      );
      for (final song in result.songs.take(3)) {
        stdout.writeln('  ${song['trackName']} - ${song['artistName']}');
      }
      if (result.artist != null) {
        stdout.writeln('  Perfil: ${result.artist!['artistName']}');
      }
      if (query.contains('545') &&
          result.songs.first['artistName'] != 'Harpa Cristã') {
        throw StateError('Hino 545 nao priorizado');
      }
    }
  } finally {
    service.close();
  }
}
