// lib/features/songs/data/repositories/song_repository_impl.dart

import '../../domain/entities/song_entity.dart';
import '../../domain/repositories/song_repository.dart';
import '../datasources/song_scraper_datasource.dart';

class SongRepositoryImpl implements SongRepository {
  final SongScraperDatasource datasource;

  SongRepositoryImpl(this.datasource);

  @override
  Future<SongEntity> extractSongFromUrl(String url) {
    return datasource.extractSongFromUrl(url); // Manda o motor trabalhar!
  }
}