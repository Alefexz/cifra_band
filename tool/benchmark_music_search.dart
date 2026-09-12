import 'dart:convert';
import 'dart:io';
import 'package:cifra_band/features/home/data/music_search_service.dart';
import 'package:cifra_band/features/home/domain/music_search_ranking.dart';

Future<void> main() async {
  final cases = <List<String>>[
    ['a casa e sua casa worship', 'A Casa É Sua', 'Casa Worship'],
    ['por que ele vive 545', 'Porque Ele Vive - 545', 'Harpa Cristã'],
    ['faz chover fernandinho', 'Faz Chover', 'Fernandinho'],
    ['eu navegarei gabriela rocha', 'Eu Navegarei', 'Gabriela Rocha'],
    ['ressuscita me aline barros', 'Ressuscita-me', 'Aline Barros'],
    ['advogado fiel bruna karla', 'Advogado Fiel', 'Bruna Karla'],
    ['escudo voz da verdade', 'Escudo', 'Voz da Verdade'],
    ['aquieta minhalma ministerio zoe', "Aquieta Minh'alma", 'Ministério Zoe'],
    ['deserto maria marcal', 'Deserto', 'Maria Marçal'],
    ['me atraiu gabriela rocha', 'Me Atraiu', 'Gabriela Rocha'],
    ['ousado amor isaias saad', 'Ousado Amor', 'Isaías Saad'],
    ['bondade de deus isaias saad', 'Bondade de Deus', 'Isaías Saad'],
    [
      'todavia me alegrarei samuel messias',
      'Todavia Me Alegrarei',
      'Samuel Messias',
    ],
    ['algo novo kemuel', 'Algo Novo', 'Kemuel'],
    ['lugar secreto gabriela rocha', 'Lugar Secreto', 'Gabriela Rocha'],
    ['deus provera gabriela gomes', 'Deus Proverá', 'Gabriela Gomes'],
    ['em teus bracos laura souguellis', 'Em Teus Braços', 'Laura Souguellis'],
    ['pra sempre fernandinho', 'Pra Sempre', 'Fernandinho'],
    ['maranata ministerio avivah', 'Maranata', 'Ministério Avivah'],
    ['galileu fernandinho', 'Galileu', 'Fernandinho'],
    [
      'ninguem explica deus preto no branco',
      'Ninguém Explica Deus',
      'Preto no Branco',
    ],
    ['lindo momento julliany souza', 'Lindo Momento', 'Julliany Souza'],
    ['alfa e omega marine friesen', 'Alfa e Ômega', 'Marine Friesen'],
    ['grandioso es tu harpa crista', 'Grandioso És Tu', 'Harpa Cristã'],
    [
      'alvo mais que a neve harpa crista',
      'Alvo Mais Que a Neve',
      'Harpa Cristã',
    ],
    ['vencendo vem jesus harpa crista', 'Vencendo Vem Jesus', 'Harpa Cristã'],
    ['firme nas promessas harpa crista', 'Firme nas Promessas', 'Harpa Cristã'],
    [
      'mais perto quero estar harpa crista',
      'Mais Perto Quero Estar',
      'Harpa Cristã',
    ],
    ['sossegai harpa crista', 'Sossegai', 'Harpa Cristã'],
    ['deus de promessas toque no altar', 'Deus de Promessas', 'Toque no Altar'],
    ['te agradeco kleber lucas', 'Te Agradeço', 'Kleber Lucas'],
    [
      'tua graca me basta toque no altar',
      'Tua Graça Me Basta',
      'Toque no Altar',
    ],
    [
      'marca da promessa trazendo a arca',
      'Marca da Promessa',
      'Trazendo a Arca',
    ],
    ['sonda me usa me aline barros', 'Sonda-me, Usa-me', 'Aline Barros'],
    ['pelo sangue renascer praise', 'Pelo Sangue', 'Renascer Praise'],
    ['deus cuida de mim kleber lucas', 'Deus Cuida de Mim', 'Kleber Lucas'],
    ['raridade anderson freire', 'Raridade', 'Anderson Freire'],
    ['sabor de mel damares', 'Sabor de Mel', 'Damares'],
    ['preciso de ti diante do trono', 'Preciso de Ti', 'Diante do Trono'],
    ['a ele a gloria diante do trono', 'A Ele a Glória', 'Diante do Trono'],
    ['tempo perdido legiao urbana', 'Tempo Perdido', 'Legião Urbana'],
    ['pais e filhos legiao urbana', 'Pais e Filhos', 'Legião Urbana'],
    ['evidencias chitaozinho xororo', 'Evidências', 'Chitãozinho'],
    [
      'como e grande o meu amor por voce roberto carlos',
      'Como É Grande o Meu Amor Por Você',
      'Roberto Carlos',
    ],
    ['asa branca luiz gonzaga', 'Asa Branca', 'Luiz Gonzaga'],
    ['tocando em frente almir sater', 'Tocando em Frente', 'Almir Sater'],
    ['romaria renato teixeira', 'Romaria', 'Renato Teixeira'],
    ['canteiros fagner', 'Canteiros', 'Fagner'],
    ['trem das onze adoniran barbosa', 'Trem das Onze', 'Adoniran Barbosa'],
    ['aquarela toquinho', 'Aquarela', 'Toquinho'],
  ];
  final service = MusicSearchService();
  final rows = <Map<String, dynamic>>[];
  try {
    for (final c in cases) {
      final watch = Stopwatch()..start();
      int? firstMs;
      try {
        final result = await service.search(
          c[0],
          onUpdate: (_) {
            firstMs ??= watch.elapsedMilliseconds;
          },
        );
        bool match(Map<String, dynamic> s) =>
            MusicSearchRanking.normalize(
              s['trackName'].toString(),
            ).contains(MusicSearchRanking.normalize(c[1])) &&
            MusicSearchRanking.normalize(
              s['artistName'].toString(),
            ).contains(MusicSearchRanking.normalize(c[2]));
        final rank = c[1].isEmpty
            ? (result.songs.isEmpty ? 0 : -1)
            : result.songs.indexWhere(match) + 1;
        rows.add({
          'query': c[0],
          'expectedTitle': c[1],
          'expectedArtist': c[2],
          'rank': rank,
          'firstMs': firstMs,
          'totalMs': watch.elapsedMilliseconds,
          'partial': result.partial,
          'top3': result.songs
              .take(3)
              .map((s) => '${s['trackName']} - ${s['artistName']}')
              .toList(),
        });
        stdout.writeln(
          '${rows.length}/${cases.length}: ${c[0]} | rank=$rank | ${watch.elapsedMilliseconds}ms',
        );
      } catch (e) {
        rows.add({
          'query': c[0],
          'expectedTitle': c[1],
          'expectedArtist': c[2],
          'rank': 0,
          'error': e.toString(),
        });
        stdout.writeln('ERROR ${c[0]}: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 2200));
    }
  } finally {
    service.close();
  }
  final positive = rows
      .where((r) => r['expectedTitle'] != null && r['expectedTitle'] != '')
      .toList();
  final summary = {
    'cases': rows.length,
    'positiveCases': positive.length,
    'top1': positive.where((r) => r['rank'] == 1).length,
    'top5': positive
        .where(
          (r) =>
              r['rank'] is int &&
              (r['rank'] as int) > 0 &&
              (r['rank'] as int) <= 5,
        )
        .length,
    'rows': rows,
  };
  await File(
    'build/search-benchmark.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  stdout.writeln(jsonEncode({...summary}..remove('rows')));
}
