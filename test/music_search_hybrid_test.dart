import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cifra_band/features/home/data/music_search_service.dart';
import 'package:cifra_band/features/home/domain/music_search_ranking.dart';
import 'music_search_test.dart' show song, response;

Map<String, dynamic> track(String title, {int id = 1}) => {
  'id': 7,
  'title': title,
  'type': 'track',
  'artist': {
    'id': id,
    'name': 'Fernandinho',
    'picture_medium': 'https://example.com/artist.jpg',
  },
  'album': {'cover_medium': 'https://example.com/cover.jpg'},
};
http.Response deezer(List<Map<String, dynamic>> items) =>
    http.Response(jsonEncode({'data': items}), 200);

void main() {
  test('explicit artist beats another performer repeating artist in title', () {
    final hits = MusicSearchRanking.rank('alvo mais que a neve harpa crista', [
      song('Alvo Mais Que a Neve Harpa Crista', 'Outro Cantor'),
      song('039 - Alvo Mais Que a Neve', 'Harpa Cristã'),
    ]);
    expect(hits.first['artistName'], 'Harpa Cristã');
  });
  test('apostrophes and written out contraction match the same title', () {
    for (final query in [
      'aquieta minhalma ministerio zoe',
      'aquieta minha alma ministerio zoe',
    ]) {
      expect(
        MusicSearchRanking.rank(query, [
          song("Aquieta Minh'alma", 'Ministério Zoe'),
        ]),
        hasLength(1),
      );
    }
  });
  test('typos accepted with label; exact titles remain ahead', () {
    final items = MusicSearchRanking.rank('bondade de deuz', [
      song('Bondade de Deus', 'Isaías Saad'),
    ]);
    expect(items, hasLength(1));
    expect(items.first['approximateMatch'], true);
    final ranked = MusicSearchRanking.rank('Galileu', [
      song('Galileus', 'Outra'),
      song('Galileu', 'Fernandinho'),
    ]);
    expect(ranked.first['artistName'], 'Fernandinho');
    expect(MusicSearchRanking.rank('999', [song('998', 'Harpa')]), isEmpty);
    expect(
      MusicSearchRanking.rank('abcxyz', [song('Galileu', 'Fernandinho')]),
      isEmpty,
    );
  });
  test('Deezer available when Apple fails; IDs do not collide', () async {
    final service = MusicSearchService(
      client: MockClient(
        (r) async => r.url.host == 'api.deezer.com'
            ? deezer([track('Galileu')])
            : http.Response('', 503),
      ),
    );
    addTearDown(service.close);
    final result = await service.search('Galileu');
    expect(result.songs, hasLength(1));
    expect(result.artist?['artistId'], 'deezer:1');
    expect(result.partial, true);
  });
  test('slow source does not hide results from the fast one', () async {
    final slow = Completer<http.Response>();
    final first = Completer<MusicSearchResult>();
    final service = MusicSearchService(
      client: MockClient(
        (r) => r.url.host == 'api.deezer.com'
            ? Future.value(deezer([track('Galileu')]))
            : slow.future,
      ),
    );
    addTearDown(service.close);
    final pending = service.search(
      'Galileu',
      onUpdate: (r) {
        if (!first.isCompleted) first.complete(r);
      },
    );
    expect((await first.future).songs.first['trackName'], 'Galileu');
    slow.complete(response([song('Galileu', 'Fernandinho')]));
    expect((await pending).songs, hasLength(1));
  });
  test(
    'backend lyrics accepted only for this query; token sent only to own API',
    () async {
      final service = MusicSearchService(
        idTokenProvider: () async => 'test-token',
        client: MockClient((r) async {
          if (r.url.host == 'cifraband-api.onrender.com') {
            expect(r.headers['Authorization'], 'Bearer test-token');
            return response([
              {
                'trackName': 'Canção',
                'artistName': 'Artista',
                'provider': 'global_cache',
                'catalogMatch': 'lyrics',
                'matchedQuery': 'hoje vamos cantar juntos',
              },
            ]);
          }
          expect(r.headers['Authorization'], isNull);
          return r.url.host == 'api.deezer.com' ? deezer([]) : response([]);
        }),
      );
      addTearDown(service.close);
      final r = await service.search('hoje vamos cantar juntos');
      expect(r.songs.single['catalogMatch'], 'lyrics');
      expect(MusicSearchRanking.rank('qualquer outra frase', r.songs), isEmpty);
    },
  );
  test('Deezer artist albums and album tracks use correct endpoints', () async {
    final paths = <String>[];
    final service = MusicSearchService(
      client: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('/albums')) {
          return deezer([
            {'id': 8, 'title': 'Album', 'cover_medium': ''},
          ]);
        }
        return deezer([track('Galileu')]);
      }),
    );
    addTearDown(service.close);
    final albums = await service.artistItems('deezer:1', 'album');
    expect(albums.single['collectionId'], 'deezer:8');
    final tracks = await service.albumTracks(albums.single['collectionId']);
    expect(tracks.single['artistName'], 'Fernandinho');
    expect(paths, ['/artist/1/albums', '/album/8/tracks']);
    await expectLater(
      service.albumTracks('deezer:../search'),
      throwsFormatException,
    );
  });
  test('cache metadata keeps artist navigation and artwork from providers', () {
    final results = MusicSearchRanking.rank('Galileu', [
      {
        'trackName': 'Galileu',
        'artistName': 'Fernandinho',
        'provider': 'global_cache',
      },
      {...song('Galileu', 'Fernandinho'), 'artworkUrl100': 'cover'},
    ]);
    expect(results, hasLength(1));
    expect(results.first['artistId'], 1);
    expect(results.first['artworkUrl100'], 'cover');
  });
}
