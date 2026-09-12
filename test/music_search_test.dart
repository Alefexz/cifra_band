import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cifra_band/features/home/data/music_search_service.dart';
import 'package:cifra_band/features/home/domain/music_search_ranking.dart';

Map<String, dynamic> song(String title, String artist, [int id = 1]) => {
  'trackName': title,
  'artistName': artist,
  'artistId': id,
  'kind': 'song',
};
http.Response response(List<Map<String, dynamic>> items) =>
    http.Response(jsonEncode({'results': items, 'data': items}), 200);

void main() {
  test('exact title first; unrelated provider hits removed', () {
    final hits = MusicSearchRanking.rank('porque ele vive', [
      song('Nao Ter', 'Sandy e Junior'),
      song('Ele Vive', 'Leonardo Goncalves'),
      song('Porque Ele Vive / Outro Hino', 'Artista'),
      song('Porque Ele Vive', 'Harpa Crista'),
    ]);
    expect(hits.first['trackName'], 'Porque Ele Vive');
    expect(hits.length, 2);
  });
  for (final query in [
    'por que ele vive 545',
    '545 deus enviou',
    'harpa 545',
    '545',
  ]) {
    test('verified hymn first for $query', () {
      final hits = MusicSearchRanking.rank(query, [
        song('Porque Ele Vive', 'Dunamis Music'),
        song('Porque Ele Vive - HC 545', 'Nossa Harpa'),
        ...MusicSearchRanking.verifiedHymns,
      ]);
      expect(hits.first['artistName'], 'Harpa Cristã');
      expect(hits.any((s) => s['artistName'] == 'Dunamis Music'), false);
    });
  }
  test('number never silently changed or removed', () {
    expect(
      MusicSearchRanking.rank(
        '546 deus enviou',
        MusicSearchRanking.verifiedHymns,
      ),
      isEmpty,
    );
    expect(
      MusicSearchRanking.rank(
        '545 musica inexistente',
        MusicSearchRanking.verifiedHymns,
      ),
      isEmpty,
    );
    expect(
      MusicSearchRanking.rank('Atos 2', [song('Atos 2', 'Gabriela Rocha')]),
      hasLength(1),
    );
  });
  test('accents, case and por que normalize consistently', () {
    expect(
      MusicSearchRanking.rank('POR QUE ELE VIVE', [
        song('Porque Ele Vive', 'Harpa Cristã'),
      ]),
      hasLength(1),
    );
    expect(
      MusicSearchRanking.rank('isaias saad', [
        song('Bondade de Deus', 'Isaías Saad'),
      ]),
      hasLength(1),
    );
  });
  test('title plus artist excludes another recording', () {
    final hits = MusicSearchRanking.rank('bondade de deus isaias saad', [
      song('Bondade de Deus', 'Isaías Saad'),
      song('Bondade de Deus', 'Outra Pessoa'),
    ]);
    expect(hits.length, 1);
    expect(hits.single['artistName'], 'Isaías Saad');
  });
  test('exact title outranks recording qualifiers with artist in query', () {
    final hits = MusicSearchRanking.rank('bondade de deus isaias saad', [
      song('Bondade de Deus (Acustico)', 'Isaias Saad'),
      song('Bondade de Deus', 'Isaias Saad'),
    ]);
    expect(hits.first['trackName'], 'Bondade de Deus');
  });
  test(
    'deduplicates live suffix but preserves medleys and parenthesized titles',
    () {
      final hits = MusicSearchRanking.rank('Oceanos', [
        song('Oceanos (Oceans)', 'Ana'),
        song('Oceanos (Oceans) (Ao Vivo)', 'Ana'),
        song('Oceanos / Lugar Secreto', 'Ana'),
      ]);
      expect(hits.length, 2);
      expect(hits.first['cleanTrackName'], 'Oceanos (Oceans)');
    },
  );
  test('instrumental hidden unless explicitly requested', () {
    final items = [song('Galileu (Instrumental)', 'Fernandinho')];
    expect(MusicSearchRanking.rank('Galileu', items), isEmpty);
    expect(
      MusicSearchRanking.rank('Galileu instrumental', items),
      hasLength(1),
    );
  });
  test(
    'initial search never waits for artist or album lookup; cached on repeat',
    () async {
      var calls = 0;
      final service = MusicSearchService(
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/search');
          return response([song('Galileu', 'Fernandinho')]);
        }),
      );
      addTearDown(service.close);
      expect((await service.search('Galileu')).songs, hasLength(1));
      await service.search('Galileu');
      expect(calls, 2);
    },
  );
  test(
    'network errors preserve local verified results but do not masquerade as no results',
    () async {
      final service = MusicSearchService(
        client: MockClient((_) async => http.Response('', 503)),
      );
      addTearDown(service.close);
      final result = await service.search('545 deus enviou');
      expect(result.partial, true);
      expect(result.songs.single['artistName'], 'Harpa Cristã');
      await expectLater(service.search('Galileu'), throwsException);
    },
  );
  test('artist lookup works even if song search returns empty', () async {
    final service = MusicSearchService(
      client: MockClient(
        (r) async => response(
          r.url.queryParameters['entity'] == 'musicArtist'
              ? [
                  {'artistName': 'Fernandinho', 'artistId': 99},
                ]
              : [],
        ),
      ),
    );
    addTearDown(service.close);
    expect((await service.search('Fernandinho')).artist?['artistId'], 99);
  });
  test('empty query does not call network', () async {
    final service = MusicSearchService(
      client: MockClient((_) => throw StateError('Unexpected request')),
    );
    addTearDown(service.close);
    expect((await service.search(' ')).songs, isEmpty);
  });
}
