// lib/features/songs/presentation/providers/song_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/song_scraper_datasource.dart';
import '../../data/repositories/song_repository_impl.dart';
import '../../domain/repositories/song_repository.dart';

// 1. Provedor do nosso Motor de Raspagem
final songScraperProvider = Provider<SongScraperDatasource>((ref) {
  return SongScraperDatasource();
});

// 2. Provedor do Repositório (injetando o motor nele)
final songRepositoryProvider = Provider<SongRepository>((ref) {
  final datasource = ref.watch(songScraperProvider);
  return SongRepositoryImpl(datasource);
});