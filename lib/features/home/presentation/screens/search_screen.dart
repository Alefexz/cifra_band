// lib/features/home/presentation/screens/search_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math'; // ⚠️ O IMPORT QUE FALTAVA PARA O RANDOM() FUNCIONAR!
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
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
  Map<String, dynamic>? _artist;
  String _activeFilter = 'Músicas';
  int _searchRequestId = 0;

  static const String _apiHost = 'cifraband-api.onrender.com';

  Future<Map<String, dynamic>> _getJson(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw Exception('Servidor retornou ${response.statusCode}');
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) throw Exception('Resposta inválida.');
    return decoded;
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
          'limit': '6',
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

      clearColdStartWarning();

      _saveToLibraryInvisible(songEntity);

      if (!mounted) return;
      setState(() => _loadingTrack = null);
      context.push('/cifra', extra: songEntity);
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
    } catch (e) {
      clearColdStartWarning();
      if (!mounted) return;
      setState(() => _loadingTrack = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não encontrei a cifra no momento.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _playTopSongs() {
    if (_artistTopSongs.isEmpty) return;
    final first = _artistTopSongs.first;
    _onSongSelected(
      first['cleanTrackName']?.toString() ??
          first['trackName']?.toString() ??
          '',
      first['artistName']?.toString() ?? '',
      first['artworkUrl100']?.toString() ?? '',
    );
  }

  void _playArtistMix() {
    if (_artistTopSongs.isEmpty && _songs.isEmpty) return;
    final source = _artistTopSongs.isNotEmpty ? _artistTopSongs : _songs;
    final random = Random();
    final song = source[random.nextInt(source.length)];
    _onSongSelected(
      song['cleanTrackName']?.toString() ?? song['trackName']?.toString() ?? '',
      song['artistName']?.toString() ?? '',
      song['artworkUrl100']?.toString() ?? '',
    );
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
                  icon: Icons.play_circle_fill_rounded,
                  text: 'Top músicas',
                  filled: true,
                  onTap: _playTopSongs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildArtistButton(
                  icon: Icons.shuffle_rounded,
                  text: 'Mix do artista',
                  filled: false,
                  onTap: _playArtistMix,
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
                'Artista encontrado',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _playTopSongs,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Abrir principais músicas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A24),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pronto para tocar?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesquise uma música ou artista\npara encontrar a cifra.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
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
