import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/music_search_ranking.dart';

class MusicSearchResult {
  const MusicSearchResult(this.songs, this.artist, {this.partial = false});
  final List<Map<String, dynamic>> songs;
  final Map<String, dynamic>? artist;
  final bool partial;
}

class MusicSearchService {
  MusicSearchService({http.Client? client, this.idTokenProvider})
    : _client = client ?? http.Client();
  final http.Client _client;
  final Future<String?> Function()? idTokenProvider;
  final _cache = <String, ({DateTime at, List<Map<String, dynamic>> items})>{};
  void close() => _client.close();

  int _artistCandidateScore(String query, Map<String, dynamic> artist) {
    final similarity = MusicSearchRanking.artistIntentScore(
      query,
      artist['artistName']?.toString() ?? '',
    );
    final fans = num.tryParse('${artist['fanCount']}') ?? 0;
    final albums = int.tryParse('${artist['albumCount']}');
    return similarity + (fans >= 1000000 ? 300 : 0) - (albums == 0 ? 400 : 0);
  }

  Future<List<Map<String, dynamic>>> _request(
    Uri uri, {
    String key = 'results',
    Map<String, String>? headers,
  }) async {
    final cached = _cache[uri.toString()];
    if (cached != null && DateTime.now().difference(cached.at).inMinutes < 5) {
      return cached.items
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Catálogo indisponível');
    final data = jsonDecode(response.body);
    if (data is! Map || data[key] is! List || data['error'] != null) {
      throw const FormatException('Catálogo inválido');
    }
    final items = (data[key] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (_cache.length >= 30) _cache.remove(_cache.keys.first);
    _cache[uri.toString()] = (at: DateTime.now(), items: items);
    return items;
  }

  Uri _apple(String path, Map<String, String> params) =>
      Uri.https('itunes.apple.com', path, {...params, 'country': 'br'});
  Map<String, dynamic> _deezerSong(Map<String, dynamic> item) => {
    'trackName': item['title'],
    'artistName': item['artist']?['name'],
    'artistId': 'deezer:${item['artist']?['id']}',
    'trackId': 'deezer:${item['id']}',
    'artworkUrl100': item['album']?['cover_medium'],
    'artistArtwork': item['artist']?['picture_medium'],
    'provider': 'deezer',
    'kind': 'song',
  };

  MusicSearchResult _rank(
    String query,
    Iterable<Map<String, dynamic>> raw, {
    bool partial = false,
  }) {
    var songs = MusicSearchRanking.rank(query, raw);
    final directArtists =
        raw
            .where(
              (item) =>
                  item['kind'] == 'artist' &&
                  MusicSearchRanking.artistIntentScore(
                        query,
                        item['artistName']?.toString() ?? '',
                      ) >=
                      750,
            )
            .toList()
          ..sort(
            (a, b) => _artistCandidateScore(
              query,
              b,
            ).compareTo(_artistCandidateScore(query, a)),
          );
    if (directArtists.isNotEmpty) {
      final selected = directArtists.first;
      final relatedSongs = MusicSearchRanking.rank(
        selected['artistName'].toString(),
        raw.where(
          (s) =>
              MusicSearchRanking.artistIntentScore(
                s['artistName']?.toString() ?? '',
                selected['artistName'].toString(),
              ) ==
              1000,
        ),
      );
      songs = relatedSongs;
      return MusicSearchResult(songs, {
        ...selected,
        'artistIntent': true,
      }, partial: partial);
    }
    Map<String, dynamic>? artist;
    final candidates = songs.where(
      (s) =>
          s['artistId'] != null &&
          MusicSearchRanking.artistMatches(query, s['artistName'].toString()),
    );
    final related = candidates.firstOrNull ?? songs.firstOrNull;
    if (related?['artistId'] != null) {
      artist = {
        'artistId': related!['artistId'],
        'artistName': related['artistName'],
        'artworkUrl100': related['artistArtwork'] ?? related['artworkUrl100'],
      };
    }
    return MusicSearchResult(songs, artist, partial: partial);
  }

  Future<MusicSearchResult> search(
    String query, {
    void Function(MusicSearchResult)? onUpdate,
  }) async {
    if (query.trim().isEmpty) return const MusicSearchResult([], null);
    if (query.length > 120) throw const FormatException('Pesquisa muito longa');
    final seeds = MusicSearchRanking.rank(
      query,
      MusicSearchRanking.verifiedHymns,
    );
    final providers = <String, List<Map<String, dynamic>>>{'local': seeds};
    var successes = 0, failures = 0;
    Iterable<Map<String, dynamic>> merged() => [
      'local',
      'global',
      'deezer',
      'apple',
      'deezer_artists',
      'apple_artists',
      'artist_prefix',
    ].expand((key) => providers[key] ?? <Map<String, dynamic>>[]);
    if (seeds.isNotEmpty) onUpdate?.call(_rank(query, seeds));
    Future<void> collect(
      String name,
      Future<List<Map<String, dynamic>>> Function() fetch,
    ) async {
      try {
        providers[name] = await fetch();
        successes++;
      } catch (_) {
        failures++;
      }
      final snapshot = _rank(query, merged());
      if (snapshot.songs.isNotEmpty || snapshot.artist != null)
        onUpdate?.call(snapshot);
    }

    final term = MusicSearchRanking.providerQuery(query);
    await Future.wait([
      collect(
        'deezer_artists',
        () async =>
            (await _request(
                  Uri.https('api.deezer.com', '/search/artist', {
                    'q': term,
                    'limit': '10',
                  }),
                  key: 'data',
                ))
                .map(
                  (a) => <String, dynamic>{
                    'artistId': 'deezer:${a['id']}',
                    'artistName': a['name'],
                    'artworkUrl100': a['picture_medium'],
                    'fanCount': a['nb_fan'],
                    'albumCount': a['nb_album'],
                    'kind': 'artist',
                  },
                )
                .toList(),
      ),
      collect(
        'apple_artists',
        () async => (await _request(
          _apple('/search', {
            'term': term,
            'entity': 'musicArtist',
            'limit': '10',
          }),
        )).map((a) => {...a, 'kind': 'artist'}).toList(),
      ),
      collect(
        'deezer',
        () async => (await _request(
          Uri.https('api.deezer.com', '/search', {'q': term, 'limit': '50'}),
          key: 'data',
        )).where((s) => s['type'] == 'track').map(_deezerSong).toList(),
      ),
      collect(
        'apple',
        () async => (await _request(
          _apple('/search', {'term': term, 'entity': 'song', 'limit': '50'}),
        )).where((s) => s['kind'] == 'song').toList(),
      ),
      if (idTokenProvider != null)
        collect('global', () async {
          final token = await idTokenProvider!().timeout(
            const Duration(seconds: 3),
          );
          if (token == null) return [];
          return _request(
            Uri.https('cifraband-api.onrender.com', '/catalog-search', {
              'q': query,
            }),
            headers: {'Authorization': 'Bearer $token'},
          );
        }),
    ]);
    if (successes == 0 && seeds.isEmpty) {
      throw Exception('Catálogos indisponíveis');
    }
    var result = _rank(query, merged(), partial: failures > 0);
    // A typo in the second name of a duo must not turn into an unrelated song.
    // Candidate discovery is broad; the full artist name is still fuzzy-validated.
    if (result.artist?['artistIntent'] != true &&
        MusicSearchRanking.hymnNumber(query) == null) {
      final words = MusicSearchRanking.normalize(query).split(' ');
      if (words.length >= 2 && words.first.length >= 5) {
        await collect(
          'artist_prefix',
          () async =>
              (await _request(
                    Uri.https('api.deezer.com', '/search/artist', {
                      'q': words.first.substring(0, 5),
                      'limit': '25',
                    }),
                    key: 'data',
                  ))
                  .map(
                    (a) => <String, dynamic>{
                      'artistId': 'deezer:${a['id']}',
                      'artistName': a['name'],
                      'artworkUrl100': a['picture_medium'],
                      'fanCount': a['nb_fan'],
                      'albumCount': a['nb_album'],
                      'kind': 'artist',
                    },
                  )
                  .toList(),
        );
        result = _rank(query, merged(), partial: failures > 0);
      }
    }
    if (result.artist?['artistIntent'] == true) return result;
    if (result.songs.isNotEmpty ||
        MusicSearchRanking.hymnNumber(query) != null) {
      return result;
    }
    try {
      final artists = await _request(
        _apple('/search', {
          'term': MusicSearchRanking.normalize(query),
          'entity': 'musicArtist',
          'limit': '10',
        }),
      );
      for (final artist in artists) {
        if (MusicSearchRanking.artistMatches(
          query,
          artist['artistName']?.toString() ?? '',
        )) {
          return MusicSearchResult(
            result.songs,
            artist,
            partial: result.partial,
          );
        }
      }
    } catch (_) {
      /* The original results remain valid. */
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> artistItems(
    Object id,
    String entity,
  ) async {
    if (id.toString().startsWith('deezer:')) {
      final artistId = id.toString().substring(7);
      if (!RegExp(r'^\d+$').hasMatch(artistId)) {
        throw const FormatException('Artista inválido');
      }
      final items = await _request(
        Uri.https(
          'api.deezer.com',
          '/artist/$artistId/${entity == 'song' ? 'top' : 'albums'}',
          {'limit': '25'},
        ),
        key: 'data',
      );
      return entity == 'song'
          ? items.map(_deezerSong).toList()
          : items
                .map(
                  (item) => {
                    'collectionId': 'deezer:${item['id']}',
                    'collectionName': item['title'],
                    'artistName': item['artist']?['name'] ?? '',
                    'artworkUrl100': item['cover_medium'],
                    'releaseDate': item['release_date'],
                  },
                )
                .toList();
    }
    final items = await _request(
      _apple('/lookup', {'id': id.toString(), 'entity': entity, 'limit': '25'}),
    );
    return items
        .where(
          (item) => entity == 'song'
              ? item['kind'] == 'song'
              : item['wrapperType'] == 'collection',
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> albumTracks(Object id) async {
    if (id.toString().startsWith('deezer:')) {
      final albumId = id.toString().substring(7);
      if (!RegExp(r'^\d+$').hasMatch(albumId)) {
        throw const FormatException('Álbum inválido');
      }
      return (await _request(
        Uri.https('api.deezer.com', '/album/$albumId/tracks', {'limit': '100'}),
        key: 'data',
      )).map(_deezerSong).toList();
    }
    return (await _request(
      _apple('/lookup', {
        'id': id.toString(),
        'entity': 'song',
        'limit': '100',
      }),
    )).where((s) => s['kind'] == 'song').toList();
  }
}
