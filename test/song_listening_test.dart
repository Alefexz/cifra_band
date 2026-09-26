import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/songs/domain/song_listening.dart';
import 'package:cifra_band/features/songs/presentation/widgets/song_suggestion_sheet.dart';

void main() {
  test('listening suggestions never masquerade as a chord sheet', () {
    expect(
      SongListening.hasChord({'kind': 'listening', 'title': 'Louvor'}),
      false,
    );
    expect(
      SongListening.hasChord({
        'content': 'C G Am\nUma letra para cantar\nOutra frase para acompanhar',
      }),
      true,
    );
  });

  test('safe provider links and encoded search preserve title and artist', () {
    for (final invalid in [
      'javascript:alert(1)',
      'http://youtu.be/abc',
      'https://youtube.com.evil.test/watch?v=abc',
      'https://user@youtube.com/watch?v=abc',
      'https://localhost/song',
      'https://open.spotify.com/',
      'https://youtu.be:8080/abc',
    ]) {
      expect(SongListening.reference(invalid), isNull, reason: invalid);
    }
    final options = SongListening.options({
      'title': 'Graça & Paz / Amor',
      'artist': 'João',
      'referenceUrl': 'https://open.spotify.com/track/abc',
    });
    expect(options['Abrir link enviado']!.host, 'open.spotify.com');
    expect(
      options['Buscar no YouTube']!.queryParameters['search_query'],
      'Graça & Paz / Amor João',
    );
    expect(
      options['Buscar no Spotify']!.pathSegments.last,
      'Graça & Paz / Amor João',
    );
    expect(
      SongListening.options({
        'title': 'Louvor',
        'artist': 'Artista',
      }).containsKey('Abrir link enviado'),
      false,
    );
  });

  testWidgets(
    'saves title and artist without chord lookup, content or invented key',
    (tester) async {
      Map<String, String>? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SongSuggestionSheet(
              title: 'Louvor novo',
              artist: 'Artista',
              save: (song) async {
                saved = song;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Enviar sugestão'));
      await tester.tap(find.text('Enviar sugestão'));
      await tester.pumpAndSettle();
      expect(saved, {
        'title': 'Louvor novo',
        'artist': 'Artista',
        'kind': 'listening',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty artist stops submit and failures retain input for retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongSuggestionSheet(
            title: 'Louvor novo',
            artist: 'Artista',
            save: (_) async {
              attempts++;
              throw Exception('offline');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.ensureVisible(find.text('Enviar sugestão'));
    await tester.tap(find.text('Enviar sugestão'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    await tester.enterText(find.byType(TextFormField).last, 'Artista');
    await tester.ensureVisible(find.text('Enviar sugestão'));
    await tester.tap(find.text('Enviar sugestão'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('Seus dados foram mantidos'), findsOneWidget);
    expect(find.text('Louvor novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'suggestion form fits narrow screen with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 740),
              textScaler: TextScaler.linear(1.6),
              viewInsets: EdgeInsets.only(bottom: 240),
            ),
            child: Scaffold(
              body: SongSuggestionSheet(
                title: 'Louvor com um nome bastante comprido',
                artist: 'Ministério de Louvor',
                save: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
