import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/core/services/personal_setlist_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';

SongModel song(
  String id, {
  String key = 'C',
  String content = 'C G\nUma letra de teste\nOutra linha de teste',
}) => SongModel(
  id: id,
  title: id,
  artist: 'Teste',
  originalKey: key,
  shapeKey: key,
  content: content,
  url: '',
);

void main() {
  test(
    'download reuses local copies, fetches only missing and preserves order',
    () async {
      final loaded = <String>[];
      final progress = <(int, int)>[];
      final a = song('a', key: 'Dm');
      final result = await collectOfflineSongs(
        ids: ['c', 'a', 'b'],
        local: {'a': a, 'removed': song('removed')},
        load: (id) async {
          loaded.add(id);
          return song(id);
        },
        onProgress: (done, total) => progress.add((done, total)),
      );
      expect(loaded, ['c', 'b']);
      expect(result.map((s) => s.id), ['c', 'a', 'b']);
      expect(result[1], same(a));
      expect(result[1].originalKey, 'Dm');
      expect(progress, [(0, 3), (1, 3), (2, 3), (3, 3)]);
    },
  );
  test('fully cached setlist does not request song content again', () async {
    await collectOfflineSongs(
      ids: ['a'],
      local: {'a': song('a')},
      load: (_) async => throw StateError('unneeded fetch'),
      onProgress: (_, _) {},
    );
  });
  test('incomplete local content is fetched again', () async {
    var calls = 0;
    await collectOfflineSongs(
      ids: ['a'],
      local: {'a': song('a', content: '')},
      load: (id) async {
        calls++;
        return song(id);
      },
      onProgress: (_, _) {},
    );
    expect(calls, 1);
  });
  test('failure never returns a partial successful download', () async {
    await expectLater(
      collectOfflineSongs(
        ids: ['a', 'b'],
        local: {'a': song('a')},
        load: (_) async => throw StateError('network'),
        onProgress: (_, _) {},
      ),
      throwsStateError,
    );
    await expectLater(
      collectOfflineSongs(
        ids: ['a'],
        local: {},
        load: (id) async => song(id, content: ''),
        onProgress: (_, _) {},
      ),
      throwsStateError,
    );
  });
  test('saved arrangement identity is stable and separates keys', () {
    expect(
      PersonalSetlistService.songId(song('a')),
      PersonalSetlistService.songId(song('a')),
    );
    expect(
      PersonalSetlistService.songId(song('a')),
      isNot(PersonalSetlistService.songId(song('a', key: 'D'))),
    );
    expect(PersonalSetlistService.offlineId('abc'), 'setlist:abc');
  });
}
