// lib/features/songs/domain/repositories/song_repository.dart

import '../entities/song_entity.dart';

abstract class SongRepository {
  Future<SongEntity> extractSongFromUrl(String url);
}