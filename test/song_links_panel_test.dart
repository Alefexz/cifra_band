import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';
import 'package:cifra_band/features/songs/presentation/widgets/song_listening_sheet.dart';

void main() {
  const song = SongEntity(id: 'test', title: 'Louvor', artist: 'Artista', originalKey: 'D',
      content: 'D G\nUma letra para cantar\nOutra frase para acompanhar', url: 'https://example.com/chord');
  testWidgets('opening suggestion automatically resolves all three actions with no link input', (tester) async {
    final requested = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SongListeningSheet(
      song: const {'title': 'Louvor', 'artist': 'Artista'},
      loadChord: () async { requested.add('cifra'); return song; },
      loadLink: (platform) async { requested.add(platform); return {
        'status': 'found', 'title': 'Louvor - Artista',
        'url': platform == 'youtube' ? 'https://www.youtube.com/watch?v=ldK43s9UyQI'
            : 'https://open.spotify.com/track/4adUUVskCSWSoRAPcpAVYm',
      }; },
      openChord: (value) => opened.add(value.originalKey),
      openLink: (uri) async { opened.add(uri.host); return true; },
    ))));
    await tester.pumpAndSettle();
    expect(requested.toSet(), {'cifra', 'youtube', 'spotify'});
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Cifra'));
    await tester.tap(find.text('YouTube'));
    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(opened, ['D', 'www.youtube.com', 'open.spotify.com']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a slow or failed provider does not block other actions and fake links are rejected', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    var opens = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SongListeningSheet(
      song: const {'title': 'Louvor', 'artist': 'Artista'}, loadChord: () async => song,
      loadLink: (p) => p == 'youtube' ? pending.future : Future.value({'status': 'found', 'url': 'https://evil.test/song'}),
      openChord: (_) => opens++,
    ))));
    await tester.pump();
    await tester.tap(find.text('Cifra'));
    expect(opens, 1);
    expect(find.text('Buscando...'), findsOneWidget);
    expect(find.text('Referência não confirmada'), findsOneWidget);
    pending.complete({'status': 'unconfirmed'});
    await tester.pumpAndSettle();
    expect(find.text('Referência não confirmada'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
