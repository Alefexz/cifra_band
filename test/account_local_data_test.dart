import 'dart:convert';
import 'package:cifra_band/core/services/account_local_data_service.dart';
import 'package:cifra_band/core/services/song_annotation_service.dart';
import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cifra_band/features/setlist/presentation/screens/favorite_songs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final song = jsonEncode({
    'id': 'private',
    'title': 'Account A favorite',
    'artist': 'Test',
    'originalKey': 'C',
    'content': 'C G\nTest words',
    'url': '',
  });
  final noteKey = OfficialLibraryService.buildSongKey('Song', 'Artist');

  setUp(() async {
    AccountLocalDataService.setSession(null);
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'favorites and annotations are isolated through A logout B login',
    () async {
      await AccountLocalDataService.initialize('a');
      await AccountLocalDataService.current!.saveFavorites([song]);
      await SongAnnotationService.save('Song', 'Artist', 'Private A note');
      AccountLocalDataService.setSession(null);
      expect(AccountLocalDataService.current, isNull);
      expect(await SongAnnotationService.load('Song', 'Artist'), isEmpty);
      AccountLocalDataService.setSession('b');
      expect(AccountLocalDataService.current!.loadFavorites(), isEmpty);
      expect(await SongAnnotationService.load('Song', 'Artist'), isEmpty);
      await SongAnnotationService.save('Song', 'Artist', 'Private B note');
      AccountLocalDataService.setSession('a');
      expect(AccountLocalDataService.current!.loadFavorites(), [song]);
      expect(
        await SongAnnotationService.load('Song', 'Artist'),
        'Private A note',
      );
    },
  );

  test('legacy migration pins startup owner and never migrates to B', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_songs': [song],
      'song_note_$noteKey': 'Legacy A',
    });
    await AccountLocalDataService.initialize('a');
    expect(AccountLocalDataService.current!.loadFavorites(), [song]);
    expect(await SongAnnotationService.load('Song', 'Artist'), 'Legacy A');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('favorite_songs'), isFalse);
    expect(prefs.containsKey('song_note_$noteKey'), isFalse);
    await AccountLocalDataService.initialize('b');
    expect(AccountLocalDataService.current!.loadFavorites(), isEmpty);
    expect(await SongAnnotationService.load('Song', 'Artist'), isEmpty);
  });

  test(
    'signed-out first startup quarantines legacy data on every later login',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorite_songs': [song],
        'song_note_$noteKey': 'Owner unknown',
      });
      await AccountLocalDataService.initialize(null);
      await AccountLocalDataService.initialize('b');
      expect(AccountLocalDataService.current!.loadFavorites(), isEmpty);
      expect(await SongAnnotationService.load('Song', 'Artist'), isEmpty);
      expect(
        (await SharedPreferences.getInstance()).getStringList('favorite_songs'),
        [song],
      );
    },
  );

  test(
    'interrupted migration is pinned and does not overwrite scoped data',
    () async {
      SharedPreferences.setMockInitialValues({
        'legacy_local_data_owner': 'a',
        'favorite_songs': [song],
        'favorite_songs_a': ['existing'],
        'song_note_$noteKey': 'Legacy A',
        'account_note_a_$noteKey': 'New A',
      });
      await AccountLocalDataService.initialize('b');
      expect(AccountLocalDataService.current!.loadFavorites(), isEmpty);
      await AccountLocalDataService.initialize('a');
      expect(AccountLocalDataService.current!.loadFavorites(), [
        'existing',
        song,
      ]);
      expect(await SongAnnotationService.load('Song', 'Artist'), 'New A');
    },
  );

  testWidgets('open favorites screen clears memory immediately on logout', (
    tester,
  ) async {
    await AccountLocalDataService.initialize('a');
    await AccountLocalDataService.current!.saveFavorites([song]);
    await tester.pumpWidget(const MaterialApp(home: FavoriteSongsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Account A favorite'), findsOneWidget);
    AccountLocalDataService.setSession(null);
    await tester.pump();
    expect(find.text('Account A favorite'), findsNothing);
    AccountLocalDataService.setSession('b');
    await tester.pump();
    expect(find.text('Account A favorite'), findsNothing);
    AccountLocalDataService.setSession('a');
    await tester.pump();
    expect(find.text('Account A favorite'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
