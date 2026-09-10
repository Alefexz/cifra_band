// lib/features/home/presentation/screens/search_screen.dart

import 'dart:async';
import 'package:cifra_band/features/songs/domain/song_content_quality.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cifra_band/features/songs/data/datasources/song_scraper_datasource.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';
import 'package:cifra_band/features/songs/presentation/providers/song_providers.dart';
import '../widgets/logo_loader.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  String? _loadingTrack;
  String? _loadingAlbumId;

  List<dynamic> _songs = [];
  List<dynamic> _albums = [];
  List<dynamic> _artistTopSongs = [];
  List<Map<String, dynamic>> _discoverySongs = [];
  bool _isLoadingDiscovery = false;
  Map<String, dynamic>? _artist;
  String _activeFilter = 'Músicas';
  int _searchRequestId = 0;

  static const String _apiHost = 'cifraband-api.onrender.com';

  static const List<Map<String, String>> _curatedDiscoverySongs = [
    {
      'trackName': 'Ah, Jesus / Coração Igual ao Teu',
      'cleanTrackName': 'Ah, Jesus / Coração Igual ao Teu',
      'artistName': 'Julliany Souza',
      'cacheId': 'julliany_souza_ah_jesus_coracao_igual_ao_teu',
    },
    {
      'trackName': 'Tudo É Perda',
      'cleanTrackName': 'Tudo É Perda',
      'artistName': 'Felipe Rodrigues',
      'cacheId': 'felipe_rodrigues_tudo_e_perda',
    },
    {
      'trackName': 'Todavia Me Alegrarei',
      'cleanTrackName': 'Todavia Me Alegrarei',
      'artistName': 'Samuel Messias',
      'cacheId': 'samuel_messias_todavia_me_alegrarei',
    },
    {
      'trackName': 'Não Me Deixe Esquecer',
      'cleanTrackName': 'Não Me Deixe Esquecer',
      'artistName': 'Valesca Mayssa',
      'cacheId': 'valesca_mayssa_nao_me_deixe_esquecer',
    },
    {
      'trackName': 'É Tudo Sobre Você / Ser Mudado',
      'cleanTrackName': 'É Tudo Sobre Você / Ser Mudado',
      'artistName': 'Morada',
      'cacheId': 'morada_e_tudo_sobre_voce_ser_mudado',
    },
    {
      'trackName': 'Em Todas As Áreas',
      'cleanTrackName': 'Em Todas As Áreas',
      'artistName': 'Gabriel Brito',
      'cacheId': 'gabriel_brito_em_todas_as_areas',
    },
    {
      'trackName': 'Atos 2',
      'cleanTrackName': 'Atos 2',
      'artistName': 'Gabriela Rocha',
      'cacheId': 'gabriela_rocha_atos_2',
    },
    {
      'trackName': 'Deus de Obras Completas',
      'cleanTrackName': 'Deus de Obras Completas',
      'artistName': 'Kemilly Santos',
      'cacheId': 'kemilly_santos_deus_de_obras_completas',
    },
    {
      'trackName': 'Sublime',
      'cleanTrackName': 'Sublime',
      'artistName': 'FHOP',
      'cacheId': 'fhop_sublime',
    },
    {
      'trackName': 'É Tudo Sobre Você',
      'cleanTrackName': 'É Tudo Sobre Você',
      'artistName': 'Morada',
      'cacheId': 'morada_e_tudo_sobre_voce',
    },
  ];

  @override
  void initState() {
    super.initState();
    _discoverySongs = _curatedDiscoverySongs
        .map((song) => Map<String, dynamic>.from(song))
        .toList();
    unawaited(_loadDiscoverySongs());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('Servidor retornou ${response.statusCode}');
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) throw Exception('Resposta inválida.');
    return decoded;
  }

  Future<void> _loadDiscoverySongs() async {
    if (_isLoadingDiscovery) return;
    _isLoadingDiscovery = true;

    try {
      final songs = <Map<String, dynamic>>[];
      final seen = <String>{};

      try {
        await _addCachedDiscoverySongs(songs, seen);
      } catch (error) {
        debugPrint('⚠️ Erro carregando descobertas do cache global: $error');
      }

      for (final seed in _curatedDiscoverySongs) {
        final seededSong = Map<String, dynamic>.from(seed);
        final track = seededSong['trackName']?.toString() ?? '';
        final artist = seededSong['artistName']?.toString() ?? '';
        final key =
            '${_normalizeForDiscovery(artist)}|${_normalizeForDiscovery(track)}';

        if (seen.contains(key)) {
          continue;
        }

        try {
          final hydrated = await _hydrateSongArtwork(seededSong);
          if (seen.add(key)) songs.add(hydrated);
        } catch (_) {
          if (seen.add(key)) songs.add(seededSong);
        }
      }

      if (!mounted) return;
      setState(() {
        _discoverySongs = songs.isEmpty
            ? _curatedDiscoverySongs
                  .map((song) => Map<String, dynamic>.from(song))
                  .toList()
            : songs;
      });
    } finally {
      _isLoadingDiscovery = false;
    }
  }

  Future<void> _addCachedDiscoverySongs(
    List<Map<String, dynamic>> songs,
    Set<String> seen,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;

      final curatedDocs = await Future.wait(
        _curatedDiscoverySongs.map((song) {
          final cacheId = song['cacheId'];
          if (cacheId == null || cacheId.isEmpty) {
            return Future.value(null);
          }
          return firestore.collection('global_cifras').doc(cacheId).get();
        }),
      );

      for (final snapshot in curatedDocs) {
        if (snapshot == null || !snapshot.exists) continue;
        final song = await _cachedSongFromSnapshot(snapshot);
        _addDiscoverySong(songs, seen, song);
      }

      final recentCache = await firestore
          .collection('global_cifras')
          .orderBy('updated_at', descending: true)
          .limit(12)
          .get();

      for (final snapshot in recentCache.docs) {
        final song = await _cachedSongFromSnapshot(snapshot);
        _addDiscoverySong(songs, seen, song);
      }
    } catch (error) {
      debugPrint('⚠️ Cache global indisponível na descoberta: $error');
    }
  }

  Future<Map<String, dynamic>> _cachedSongFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final data = snapshot.data() ?? {};
    final title = data['title']?.toString() ?? '';
    final artist = data['artist']?.toString() ?? '';
    final song = <String, dynamic>{
      'cacheId': snapshot.id,
      'trackName': title,
      'cleanTrackName': _cleanVisualTrackName(title),
      'artistName': artist,
      'originalKey': data['originalKey']?.toString() ?? 'C',
      'shapeKey': data['shapeKey']?.toString(),
      'capo': data['capo']?.toString(),
      'content': data['content']?.toString() ?? '',
      'url': data['url']?.toString() ?? '',
      'source': data['source']?.toString() ?? 'global_cache',
      'isCachedCifra': true,
    };

    try {
      return await _hydrateSongArtwork(song);
    } catch (_) {
      return song;
    }
  }

  void _addDiscoverySong(
    List<Map<String, dynamic>> songs,
    Set<String> seen,
    Map<String, dynamic> song,
  ) {
    final track = _displayTrack(song);
    final artist = _displayArtist(song);
    final content = song['content']?.toString() ?? '';
    if (track.trim().isEmpty || artist.trim().isEmpty) return;
    if (song['isCachedCifra'] == true && !SongContentQuality.hasLyrics(content))
      return;

    final key =
        '${_normalizeForDiscovery(artist)}|${_normalizeForDiscovery(track)}';
    if (seen.add(key)) {
      songs.add(song);
    }
  }

  Future<Map<String, dynamic>> _hydrateSongArtwork(
    Map<String, dynamic> song,
  ) async {
    final track = song['trackName']?.toString() ?? '';
    final artist = song['artistName']?.toString() ?? '';

    if ((song['artworkUrl100']?.toString() ?? '').isNotEmpty ||
        track.isEmpty ||
        artist.isEmpty) {
      return song;
    }

    final url = Uri.https('itunes.apple.com', '/search', {
      'term': '$track $artist',
      'entity': 'song',
      'limit': '3',
      'country': 'br',
    });

    try {
      final data = await _getJson(url);
      final results = data['results'] as List? ?? [];
      final match = results.whereType<Map>().firstWhere((item) {
        final title = item['trackName']?.toString() ?? '';
        final itemArtist = item['artistName']?.toString() ?? '';
        return _normalizeForDiscovery(
              title,
            ).contains(_normalizeForDiscovery(track)) ||
            _normalizeForDiscovery(
              itemArtist,
            ).contains(_normalizeForDiscovery(artist));
      }, orElse: () => const {});

      final artwork = match['artworkUrl100']?.toString() ?? '';
      if (artwork.isNotEmpty) {
        song['artworkUrl100'] = artwork;
      }
    } catch (_) {
      return song;
    }

    return song;
  }

  String _cleanVisualTrackName(String title) {
    return title
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
  }

  String _normalizeForDiscovery(Object? value) {
    return value
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  // ============================================================
  // BUSCA NATURAL: CONFIANDO NA RELEVÂNCIA DA APPLE
  // ============================================================
  Future<void> _performSearch(String query) async {
    final cleanQuery = query.trim();
    final requestId = ++_searchRequestId;

    if (cleanQuery.isEmpty) {
      if (!mounted) return;
      setState(() {
        _songs = [];
        _albums = [];
        _artist = null;
        _artistTopSongs = [];
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _artist = null;
        _artistTopSongs = [];
        _albums = [];
        _songs = [];
      });
    }

    try {
      // 1. Busca Simples: Pegamos as 50 melhores músicas segundo a Apple
      final searchUrl = Uri.https('itunes.apple.com', '/search', {
        'term': cleanQuery,
        'entity': 'song',
        'limit': '50',
        'country': 'br',
      });

      final response = await http
          .get(searchUrl)
          .timeout(const Duration(seconds: 15));
      final jsonResponse = json.decode(response.body);
      final rawSongs = jsonResponse['results'] as List? ?? [];

      if (rawSongs.isEmpty) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() => _isLoading = false);
        return;
      }

      // 2. Filtramos e Limpamos MANTENDO a ordem exata da Apple
      final List<Map<String, dynamic>> processedSongs = [];
      final Set<String> seenKeys = {};

      for (var item in rawSongs) {
        if (item is! Map) continue;
        final song = Map<String, dynamic>.from(item);

        String title = song['trackName']?.toString() ?? '';
        String artist = song['artistName']?.toString() ?? '';

        final lowerTitle = title.toLowerCase();
        if (lowerTitle.contains('playback') ||
            lowerTitle.contains('karaoke') ||
            lowerTitle.contains('instrumental')) {
          continue;
        }

        // Título visualmente limpo
        String cleanTitle = title
            .replaceAll(RegExp(r'\(.*?\)'), '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .trim();
        song['cleanTrackName'] = cleanTitle;

        final key = '${artist.toLowerCase()}|${cleanTitle.toLowerCase()}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          processedSongs.add(song);
        }
      }

      if (processedSongs.isEmpty) {
        if (!mounted || requestId != _searchRequestId) return;
        setState(() => _isLoading = false);
        return;
      }

      // 3. O "Melhor Artista" é simplesmente o dono da música Nº 1
      final bestMatch = processedSongs.first;
      final artistId = bestMatch['artistId'];

      Map<String, dynamic>? artistProfile;
      List<dynamic> topSongs = [];
      List<dynamic> albums = [];

      if (artistId != null) {
        final lookupUrl = Uri.https('itunes.apple.com', '/lookup', {
          'id': artistId.toString(),
          'entity': 'song',
          'limit': '25',
          'country': 'br',
        });
        final albumUrl = Uri.https('itunes.apple.com', '/lookup', {
          'id': artistId.toString(),
          'entity': 'album',
          'limit': '15',
          'country': 'br',
        });

        final results = await Future.wait([
          http.get(lookupUrl).timeout(const Duration(seconds: 10)),
          http.get(albumUrl).timeout(const Duration(seconds: 10)),
        ]);

        final artistData =
            json.decode(results[0].body)['results'] as List? ?? [];
        final albumsData =
            json.decode(results[1].body)['results'] as List? ?? [];

        if (artistData.isNotEmpty) {
          artistProfile = artistData.firstWhere(
            (item) => item['wrapperType'] == 'artist',
            orElse: () => null,
          );

          final rawTop = artistData
              .where((item) => item['wrapperType'] == 'track')
              .toList();
          final uniqueTop = <String, dynamic>{};
          for (var song in rawTop) {
            String title = song['trackName']?.toString() ?? '';
            title = title
                .replaceAll(RegExp(r'\(.*?\)'), '')
                .replaceAll(RegExp(r'\[.*?\]'), '')
                .trim();
            song['cleanTrackName'] = title;
            final key = title.toLowerCase();
            if (!uniqueTop.containsKey(key) && !key.contains('playback'))
              uniqueTop[key] = song;
          }
          topSongs = uniqueTop.values.toList();
        }

        final rawAlbums = albumsData
            .where((item) => item['wrapperType'] == 'collection')
            .toList();
        final uniqueAlbums = <String, dynamic>{};
        for (var album in rawAlbums) {
          final name = album['collectionName']?.toString() ?? '';
          if (!name.toLowerCase().contains('single') &&
              !name.toLowerCase().contains('playback')) {
            uniqueAlbums[name.toLowerCase()] = album;
          }
        }
        albums = uniqueAlbums.values.toList();
      }

      if (artistProfile != null) {
        artistProfile['artworkUrl100'] ??= bestMatch['artworkUrl100'];
      } else {
        artistProfile = {
          'artistName': bestMatch['artistName'],
          'artworkUrl100': bestMatch['artworkUrl100'],
        };
      }

      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _artist = artistProfile;
        _artistTopSongs = topSongs;
        _songs = processedSongs;
        _albums = albums;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao pesquisar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _performSearch(query),
    );
    if (mounted) setState(() {});
  }

  // ============================================================
  // BUSCAR CIFRA NO BACKEND (COM ALERTA DE COLD START E CACHE)
  // ============================================================
  Future<void> _onSongSelected(
    String track,
    String artist,
    String coverUrl,
  ) async {
    if (_loadingTrack != null || track.trim().isEmpty || artist.trim().isEmpty)
      return;

    if (mounted) setState(() => _loadingTrack = track);

    bool snackBarShown = false;

    Timer? coldStartTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted || _loadingTrack != track) return;
      snackBarShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  '☕ Calma, estamos acordando o servidor... aguarde só um pouquinho!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 60),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    void clearColdStartWarning() {
      coldStartTimer.cancel();
      if (mounted && snackBarShown)
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    try {
      final uri = Uri.https(_apiHost, '/searchSong', {
        'artist': artist.trim(),
        'track': track.trim(),
      });

      final repository = ref.read(songRepositoryProvider);
      final SongEntity songEntity = await repository.extractSongFromUrl(
        uri.toString(),
      );
      final officialSong = await OfficialLibraryService.findOfficialSong(
        songEntity.title,
        songEntity.artist,
      ).catchError((_) => null);

      clearColdStartWarning();

      _saveToLibraryInvisible(songEntity);

      if (!mounted) return;
      setState(() => _loadingTrack = null);
      context.push('/cifra', extra: officialSong?.toSongModel() ?? songEntity);
    } on TimeoutException {
      clearColdStartWarning();
      if (!mounted) return;
      setState(() => _loadingTrack = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O servidor demorou para responder. Tente de novo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on SongSearchException catch (e) {
      clearColdStartWarning();
      if (!mounted) return;
      setState(() => _loadingTrack = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Suporte',
            textColor: Colors.white,
            onPressed: () => context.push('/feedback'),
          ),
        ),
      );
    } catch (e) {
      clearColdStartWarning();
      if (!mounted) return;
      setState(() => _loadingTrack = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não consegui buscar essa cifra agora. Tente de novo.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDiscoverySong(Map<String, dynamic> song) {
    final content = song['content']?.toString() ?? '';

    if (song['isCachedCifra'] == true &&
        SongContentQuality.hasLyrics(content)) {
      final songEntity = SongEntity(
        id: song['cacheId']?.toString() ?? _displayTrack(song),
        title: _displayTrack(song),
        artist: _displayArtist(song),
        originalKey: song['originalKey']?.toString() ?? 'C',
        shapeKey: song['shapeKey']?.toString(),
        capo: song['capo']?.toString(),
        referenceUrl: song['referenceUrl']?.toString(),
        rehearsalNotes: song['rehearsalNotes']?.toString(),
        bpm: song['bpm']?.toString(),
        content: content,
        url: song['url']?.toString() ?? '',
      );

      context.push('/cifra', extra: songEntity);
      return;
    }

    _onSongSelected(
      _searchTrack(song),
      _displayArtist(song),
      song['artworkUrl100']?.toString() ?? '',
    );
  }

  void _openArtistSongs() {
    if (_artist == null) return;
    setState(() => _activeFilter = 'Artistas');
  }

  void _openArtistAlbums() {
    if (_albums.isEmpty) return;
    setState(() => _activeFilter = 'Álbuns');
  }

  Future<void> _openAlbum(Map<String, dynamic> album) async {
    final collectionId = album['collectionId'];
    if (collectionId == null) return;
    final albumKey = collectionId.toString();

    if (_loadingAlbumId != null) return;
    if (mounted) setState(() => _loadingAlbumId = albumKey);

    try {
      final url = Uri.parse(
        'https://itunes.apple.com/lookup?id=$collectionId&entity=song&country=br&limit=100',
      );
      final jsonResponse = await _getJson(url);
      final results = jsonResponse['results'] is List
          ? List<dynamic>.from(jsonResponse['results'])
          : <dynamic>[];

      // Remove as tracks que contêm 'playback'
      final tracks = results.where((item) {
        if (item is! Map ||
            item['wrapperType'] != 'track' ||
            item['kind'] != 'song')
          return false;
        final title = item['trackName']?.toString().toLowerCase() ?? '';
        if (title.contains('playback') || title.contains('karaoke'))
          return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() => _loadingAlbumId = null);

      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF121218),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => _buildAlbumSheet(album, tracks),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAlbumId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o álbum.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildAlbumSheet(Map<String, dynamic> album, List<dynamic> tracks) {
    final image = album['artworkUrl100']?.toString() ?? '';
    final name = album['collectionName']?.toString() ?? 'Álbum';
    final artist = album['artistName']?.toString() ?? '';

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildArtwork(image, 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          artist,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${tracks.length} músicas',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma música encontrada.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index] as Map;
                        final title =
                            track['trackName']?.toString() ?? 'Música';
                        final cleanTitle = title
                            .replaceAll(RegExp(r'\(.*?\)'), '')
                            .replaceAll(RegExp(r'\[.*?\]'), '')
                            .trim();
                        final trackArtist =
                            track['artistName']?.toString() ?? artist;
                        final artwork =
                            track['artworkUrl100']?.toString() ?? image;
                        final isLoading = _loadingTrack == title;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 3,
                          ),
                          leading: SizedBox(
                            width: 28,
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            cleanTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            trackArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          trailing: isLoading
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: LogoLoader(size: 28),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade900,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _onSongSelected(
                                        title,
                                        trackArtist,
                                        artwork,
                                      );
                                    },
                                  ),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Repertório',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          if (_songs.isNotEmpty || _artist != null || _albums.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildFilters(),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: LogoLoader(size: 100))
                : _songs.isEmpty && _artist == null && _albums.isEmpty
                ? _buildEmptyState()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Buscar artista ou música...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.blueAccent,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      _searchRequestId++;
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _songs = [];
                        _albums = [];
                        _artist = null;
                        _artistTopSongs = [];
                        _isLoading = false;
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1A1A24),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['Músicas', 'Álbuns', 'Artistas'];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index], selected = _activeFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.blueAccent.withOpacity(0.15)
                    : const Color(0xFF17171F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: selected ? Colors.blueAccent : Colors.white10,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: selected ? Colors.blueAccent : Colors.grey.shade400,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_activeFilter == 'Álbuns') return _buildAlbumsTab();
    if (_activeFilter == 'Artistas') return _buildArtistsTab();
    return _buildSongsTab();
  }

  Widget _buildSongsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_artist != null) _buildArtistHero(),
          if (_artist != null && _artistTopSongs.isNotEmpty) ...[
            const SizedBox(height: 26),
            const Text(
              'TOP MÚSICAS',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            ..._artistTopSongs.map((song) => _buildCompactSong(song)),
          ],
          if (_songs.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              'MÚSICAS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ..._songs.map((song) => _buildSongCard(song)),
          ],
          if (_songs.isEmpty && _artist == null) _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildArtistHero() {
    if (_artist == null) return const SizedBox.shrink();

    final artistName = _artist!['artistName']?.toString() ?? 'Artista';
    String imageUrl = '';

    if (_artist!['artworkUrl100'] != null)
      imageUrl = _artist!['artworkUrl100'].toString();
    if (imageUrl.isEmpty && _artistTopSongs.isNotEmpty)
      imageUrl = _artistTopSongs.first['artworkUrl100']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCircularArtwork(imageUrl, 76),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artistName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Artista',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildArtistButton(
                  icon: Icons.queue_music_rounded,
                  text: 'Ver músicas',
                  filled: true,
                  onTap: _openArtistSongs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildArtistButton(
                  icon: Icons.album_rounded,
                  text: 'Álbuns',
                  filled: false,
                  onTap: _openArtistAlbums,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArtistButton({
    required IconData icon,
    required String text,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? Colors.blueAccent : Colors.transparent,
          foregroundColor: filled ? Colors.white : Colors.blueAccent,
          elevation: 0,
          side: filled
              ? BorderSide.none
              : const BorderSide(color: Colors.blueAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsTab() {
    if (_albums.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: _albums.length,
      itemBuilder: (context, index) =>
          _buildAlbumCard(_albums[index] as Map<String, dynamic>),
    );
  }

  Widget _buildAlbumCard(Map<String, dynamic> album) {
    final image = album['artworkUrl100']?.toString() ?? '';
    final name = album['collectionName']?.toString() ?? 'Álbum';
    final artist = album['artistName']?.toString() ?? '';
    final year = album['releaseDate']?.toString().split('-').first ?? '';
    final albumKey = album['collectionId']?.toString();
    final isLoading = albumKey != null && _loadingAlbumId == albumKey;
    final isBlocked = _loadingAlbumId != null && !isLoading;

    return GestureDetector(
      onTap: isLoading || isBlocked ? null : () => _openAlbum(album),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            _buildArtwork(image, 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                  if (year.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        year,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: LogoLoader(size: 22),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white38,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistsTab() {
    if (_artist == null) return _buildEmptyState();

    final artistName = _artist!['artistName']?.toString() ?? 'Artista';
    String image = '';

    if (_artist!['artworkUrl100'] != null)
      image = _artist!['artworkUrl100'].toString();
    if (image.isEmpty && _artistTopSongs.isNotEmpty)
      image = _artistTopSongs.first['artworkUrl100']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildCircularArtwork(image, 110),
              const SizedBox(height: 18),
              Text(
                artistName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _artistTopSongs.isEmpty
                    ? 'Artista encontrado'
                    : '${_artistTopSongs.length} músicas encontradas',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ],
          ),
        ),
        if (_artistTopSongs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'DESTAQUES DO ARTISTA',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._artistTopSongs.asMap().entries.map(
            (entry) => _buildArtistSongTile(entry.key + 1, entry.value),
          ),
        ] else ...[
          const SizedBox(height: 18),
          Text(
            'Pesquise pelo nome de uma música desse artista para abrir a cifra.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArtistSongTile(int position, dynamic song) {
    final track =
        song['cleanTrackName']?.toString() ??
        song['trackName']?.toString() ??
        '';
    final searchTrack = song['trackName']?.toString() ?? '';
    final artist = song['artistName']?.toString() ?? '';
    final image = song['artworkUrl100']?.toString() ?? '';
    final isLoading = _loadingTrack == searchTrack;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isLoading
          ? null
          : () => _onSongSelected(searchTrack, artist, image),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$position',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildArtwork(image, 52),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: LogoLoader(size: 28),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSong(dynamic song) {
    final track =
        song['cleanTrackName']?.toString() ??
        song['trackName']?.toString() ??
        '';
    final searchTrack = song['trackName']?.toString() ?? '';
    final artist = song['artistName']?.toString() ?? '';
    final image = song['artworkUrl100']?.toString() ?? '';
    final isLoading = _loadingTrack == searchTrack;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      leading: _buildArtwork(image, 50),
      title: Text(
        track,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: isLoading
          ? const SizedBox(width: 28, height: 28, child: LogoLoader(size: 28))
          : IconButton(
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              onPressed: () => _onSongSelected(searchTrack, artist, image),
            ),
    );
  }

  Widget _buildSongCard(dynamic song) {
    final image = song['artworkUrl100']?.toString() ?? '';
    final track =
        song['cleanTrackName']?.toString() ??
        song['trackName']?.toString() ??
        'Desconhecido';
    final searchTrack = song['trackName']?.toString() ?? '';
    final artist = song['artistName']?.toString() ?? 'Desconhecido';
    final isLoading = _loadingTrack == searchTrack;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: _buildArtwork(image, 54),
        title: Text(
          track,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: LogoLoader(size: 22),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  onPressed: () => _onSongSelected(searchTrack, artist, image),
                ),
        ),
        onTap: isLoading
            ? null
            : () => _onSongSelected(searchTrack, artist, image),
      ),
    );
  }

  Widget _buildArtwork(String url, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.isEmpty
          ? _imageFallback(size)
          : Image.network(
              url.replaceAll('100x100bb', '${size.toInt()}x${size.toInt()}bb'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _imageFallback(size),
            ),
    );
  }

  Widget _buildCircularArtwork(String url, double size) {
    return ClipOval(
      child: url.isEmpty
          ? _imageFallback(size)
          : Image.network(
              url.replaceAll('100x100bb', '300x300bb'),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _imageFallback(size),
            ),
    );
  }

  Widget _imageFallback(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade900,
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white38,
        size: size * 0.35,
      ),
    );
  }

  Widget _buildEmptyState() {
    final trending = _discoverySongs.take(5).toList();
    final highlights = _discoverySongs.skip(2).take(5).toList();

    return RefreshIndicator(
      color: Colors.blueAccent,
      backgroundColor: const Color(0xFF17171F),
      onRefresh: _loadDiscoverySongs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _buildDiscoveryHeader(),
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Gospel em destaque hoje',
            actionIcon: Icons.trending_up_rounded,
          ),
          const SizedBox(height: 10),
          ...trending.asMap().entries.map(
            (entry) => _buildTrendingTile(entry.key + 1, entry.value),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            'Sugestões para culto',
            actionIcon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          _buildHighlightRail(highlights),
          const SizedBox(height: 26),
          _buildRecentSongsPreview(),
        ],
      ),
    );
  }

  Widget _buildDiscoveryHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF15151E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: Colors.blueAccent,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pronto para tocar?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Explore cifras em alta ou pesquise seu repertório.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required IconData actionIcon}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF17171F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Icon(actionIcon, color: Colors.blueAccent, size: 18),
        ),
      ],
    );
  }

  Widget _buildTrendingTile(int position, Map<String, dynamic> song) {
    final track = _displayTrack(song);
    final searchTrack = _searchTrack(song);
    final artist = _displayArtist(song);
    final image = song['artworkUrl100']?.toString() ?? '';
    final isLoading = _loadingTrack == searchTrack;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: isLoading ? null : () => _openDiscoverySong(song),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: position > 0
                  ? Text(
                      '$position',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Icon(
                      Icons.history_rounded,
                      color: Colors.grey.shade700,
                      size: 18,
                    ),
            ),
            const SizedBox(width: 10),
            _buildArtwork(image, 50),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isLoading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: LogoLoader(size: 28),
                  )
                : Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.blueAccent,
                      size: 23,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightRail(List<Map<String, dynamic>> songs) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildHighlightCard(songs[index]),
      ),
    );
  }

  Widget _buildHighlightCard(Map<String, dynamic> song) {
    final track = _displayTrack(song);
    final searchTrack = _searchTrack(song);
    final artist = _displayArtist(song);
    final image = song['artworkUrl100']?.toString() ?? '';
    final isLoading = _loadingTrack == searchTrack;

    return GestureDetector(
      onTap: isLoading ? null : () => _openDiscoverySong(song),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF17171F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildArtwork(image, 86),
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(child: LogoLoader(size: 34)),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              track,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSongsPreview() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('played_history')
          .orderBy('played_at', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Tocadas recentemente',
              actionIcon: Icons.history_rounded,
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data();
              final song = {
                'cacheId': doc.id,
                'trackName': data['title']?.toString() ?? '',
                'cleanTrackName': data['title']?.toString() ?? '',
                'artistName': data['artist']?.toString() ?? '',
                'originalKey': data['originalKey']?.toString() ?? 'C',
                'shapeKey': data['shapeKey']?.toString(),
                'capo': data['capo']?.toString(),
                'referenceUrl': data['referenceUrl']?.toString(),
                'rehearsalNotes': data['rehearsalNotes']?.toString(),
                'bpm': data['bpm']?.toString(),
                'content': data['content']?.toString() ?? '',
                'url': data['url']?.toString() ?? '',
                'isCachedCifra': true,
              };
              return _buildTrendingTile(0, song);
            }),
          ],
        );
      },
    );
  }

  String _displayTrack(Map<String, dynamic> song) {
    return song['cleanTrackName']?.toString().trim().isNotEmpty == true
        ? song['cleanTrackName'].toString()
        : song['trackName']?.toString() ?? 'Música';
  }

  String _searchTrack(Map<String, dynamic> song) {
    return song['trackName']?.toString().trim().isNotEmpty == true
        ? song['trackName'].toString()
        : _displayTrack(song);
  }

  String _displayArtist(Map<String, dynamic> song) {
    return song['artistName']?.toString().trim().isNotEmpty == true
        ? song['artistName'].toString()
        : 'Artista';
  }

  Future<void> _saveToLibraryInvisible(SongEntity song) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final safeDocumentId = '${song.artist}_${song.title}'.replaceAll(
        RegExp(r'[/\\]'),
        '_',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .doc(safeDocumentId)
          .set({
            'title': song.title,
            'artist': song.artist,
            'originalKey': song.originalKey,
            'shapeKey': song.shapeKey,
            'capo': song.capo,
            'content': song.content,
            'url': song.url,
            'saved_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('⚠️ Erro salvando cifra: $e');
    }
  }
}
