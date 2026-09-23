import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifra_band/core/services/chord_study_service.dart';
import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cifra_band/core/services/offline_setlist_service.dart';
import 'package:cifra_band/features/home/domain/music_search_ranking.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';

void main() {
  test(
    'artist intention tolerates duo typos without matching song phrases',
    () {
      for (final query in [
        'Jorge e Mateus',
        'jorge e matheus',
        'jorgeve mayheus',
        'Jorge & Mateus',
      ]) {
        expect(
          MusicSearchRanking.artistIntentScore(query, 'Jorge & Mateus'),
          greaterThanOrEqualTo(750),
          reason: query,
        );
      }
      expect(
        MusicSearchRanking.artistIntentScore('Sol Nos Olhos', 'Jorge & Mateus'),
        0,
      );
      expect(
        MusicSearchRanking.artistIntentScore(
          'Galileu Fernandinho',
          'Fernandinho',
        ),
        0,
      );
      expect(MusicSearchRanking.artistIntentScore('545', 'Harpa Crista'), 0);
    },
  );
  test('altered ninths differ and minor major seventh remains minor', () {
    expect(ChordStudyService.keyboardNotes('C7(b9)'), contains('C#'));
    expect(ChordStudyService.keyboardNotes('C7(b9)'), isNot(contains('D')));
    expect(ChordStudyService.keyboardNotes('C7(#9)'), contains('D#'));
    expect(ChordStudyService.qualityLabel('Am7M'), 'Menor com sétima maior');
    expect(
      ChordStudyService.keyboardNotes('Cdim7'),
      unorderedEquals(['C', 'D#', 'F#', 'A']),
    );
  });
  test('never substitutes diagrams that lose an extension or quality', () {
    for (final chord in ['Csus4', 'Cm6']) {
      expect(ChordStudyService.guitarShapeFor(chord), isNull, reason: chord);
    }
    for (final chord in ['D7/F#', 'Cdim7', 'Am7M', 'C7(b9)', 'C7(#9)']) {
      expect(ChordStudyService.guitarShapeFor(chord)?.label, chord);
    }
    expect(ChordStudyService.guitarShapeFor('D/F#')?.positions.first, '2');
    expect(ChordStudyService.guitarShapeFor('Cmaj7')?.label, 'C7M');
  });
  test('import never discards lyric line or infers key from first chord', () {
    const raw = 'Primeira frase da letra\nC G\nSegunda frase da letra';
    final draft = OfficialLibraryService.parseImportedText(raw);
    expect(draft.content, raw);
    expect(draft.originalKey, isEmpty);
    expect(draft.artist, 'Artista nao informado');
  });
  test(
    'offline downloads are account-scoped and corrupt files do not get badge',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = OfflineSetlistStore(prefs, 'a'),
          b = OfflineSetlistStore(prefs, 'b');
      final song = SongModel(
        id: 's',
        title: 'Teste',
        artist: 'Autor',
        originalKey: 'C',
        content: 'C G\nLetra para tocar',
        url: '',
      );
      await a.saveCultSetlist(
        scheduleId: 'event',
        title: 'Culto',
        songs: [song],
      );
      expect(await a.isCultSetlistSaved('event'), true);
      expect(await b.listSummaries(), isEmpty);
      expect(await b.loadCultSetlist('event'), isNull);
      await prefs.setString(
        'offline_v2_a_event',
        jsonEncode({'schema': 2, 'uid': 'b', 'songs': []}),
      );
      expect(await a.isCultSetlistSaved('event'), false);
    },
  );
  test(
    'offline retention preserves all intentional downloads',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = OfflineSetlistStore(prefs, 'a');
      for (var i = 0; i < 21; i++) {
        await store.saveCultSetlist(
          scheduleId: '$i',
          title: 'Culto',
          songs: [
            SongModel(
              id: 's',
              title: 'Teste',
              artist: 'Autor',
              originalKey: 'C',
              content: 'C G\nLetra',
              url: '',
            ),
          ],
        );
      }
      expect(await store.listSummaries(), hasLength(21));
      expect(prefs.containsKey('offline_v2_a_0'), true);
    },
  );
}
