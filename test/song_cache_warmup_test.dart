import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cached song warmup delegates to the throttled lightweight endpoint',
    () {
      final datasource = File(
        'lib/features/songs/data/datasources/song_scraper_datasource.dart',
      ).readAsStringSync();
      final warmup = File(
        'lib/core/services/backend_warmup_service.dart',
      ).readAsStringSync();
      expect(
        datasource,
        contains("BackendWarmupService.wake(reason: 'song_cache_hit')"),
      );
      expect(datasource, isNot(contains('_wakeRenderInBackground')));
      expect(warmup, contains('/app-version'));
      expect(warmup, isNot(contains('/searchSong')));
    },
  );
}
