import 'package:cifra_band/features/songs/data/datasources/direct_chord_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final complete =
      '''
<title>Medley - Corinhos de Fogo Acordes - Midian Lima | LosAcordes.com</title>
<h1 id="songtitle">Medley - Corinhos de Fogo <span>Acordes</span></h1>
<h2 id="artistname"><a>Midian Lima</a></h2>
<span class="actualkey">Bm</span>
<pre id="core">Bm       G       A
Uma frase de teste com palavras suficientes para uma linha.
G        A       D
Outra frase de teste que completa a letra da musica.
${'Bm  G  A  D  Esta e uma linha de teste para validar a cifra.\n' * 10}</pre>
''';

  test('accepts the full selected medley and its verified page', () {
    final song = DirectChordSource.parsePage(
      complete,
      artist: 'Midian Lima',
      track: 'Medley - Corinhos de Fogo',
      id: 'midian_lima_medley',
      url:
          'https://www.losacordes.com/acordes/midian-lima/medley-corinhos-de-fogo/',
    );
    expect(song?.originalKey, 'Bm');
    expect(song?.content, contains('Outra frase de teste'));
  });

  test('rejects a named medley missing one of its sections', () {
    final song = DirectChordSource.parsePage(
      complete,
      artist: 'Midian Lima',
      track: 'Medley - Corinhos de Fogo (Deus Forte / Divisa de Fogo)',
      id: 'x',
      url:
          'https://www.losacordes.com/acordes/midian-lima/medley-corinhos-de-fogo/',
    );
    expect(song, isNull);
  });

  test('rejects wrong artist, wrong title and chord-only page', () {
    const url =
        'https://www.losacordes.com/acordes/midian-lima/medley-corinhos-de-fogo/';
    expect(
      DirectChordSource.parsePage(
        complete,
        artist: 'Outro Artista',
        track: 'Medley - Corinhos de Fogo',
        id: 'x',
        url: url,
      ),
      isNull,
    );
    expect(
      DirectChordSource.parsePage(
        complete,
        artist: 'Midian Lima',
        track: 'Outro Medley',
        id: 'x',
        url: url,
      ),
      isNull,
    );
    expect(
      DirectChordSource.parsePage(
        complete.replaceAll(
          RegExp(r'<pre id="core">[\s\S]*?</pre>'),
          '<pre id="core">Bm G A D</pre>',
        ),
        artist: 'Midian Lima',
        track: 'Medley - Corinhos de Fogo',
        id: 'x',
        url: url,
      ),
      isNull,
    );
  });

  test('tries selected title then safe singular/plural slug', () async {
    final requested = <Uri>[];
    final source = DirectChordSource(
      client: MockClient((request) async {
        requested.add(request.url);
        if (request.url.path.endsWith('/medley-corinhos-de-fogo/')) {
          return http.Response(complete, 200, request: request);
        }
        return http.Response('', 404, request: request);
      }),
    );
    addTearDown(source.close);

    final song = await source.find(
      artist: 'Midian Lima',
      track: 'Medley - Corinho de Fogo',
      id: 'midian_lima_medley',
    );
    expect(song?.title, 'Medley - Corinhos de Fogo');
    expect(requested.map((uri) => uri.path), [
      '/acordes/midian-lima/medley-corinho-de-fogo/',
      '/acordes/midian-lima/medley-corinhos-de-fogo/',
    ]);
  });

  test(
    'live selected Midian Lima medley has lyrics and chords',
    () async {
      final source = DirectChordSource();
      addTearDown(source.close);
      final song = await source.find(
        artist: 'Midian Lima',
        track:
            'Medley - Corinhos de Fogo (Deus Forte Como Jeová / Divisa de Fogo / Vem Cá Vem Ver / Carros de Fogo / Jacó Segurou o Anjo)',
        id: 'midian_lima_medley_corinhos_de_fogo',
      );
      expect(song, isNotNull);
      expect(song!.content.length, greaterThan(1000));
      expect(song.originalKey, 'Bm');
    },
    skip: !const bool.fromEnvironment('LIVE_CHORD_SOURCE_TEST'),
  );
}
