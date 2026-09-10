import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cifra_band/features/setlist/data/models/setlist_model.dart';
import 'package:cifra_band/features/songs/domain/entities/song_destination.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';
import 'package:cifra_band/features/songs/domain/song_arrangement.dart';
import 'package:cifra_band/features/songs/domain/song_content_quality.dart';

void main() {
  test('setlist dates accept legacy milliseconds and Firestore timestamps', () {
    final milliseconds = SetlistModel.fromMap({'updatedAt': 1000}, 'old');
    final timestamp = SetlistModel.fromMap({
      'updatedAt': Timestamp.fromMillisecondsSinceEpoch(1000),
    }, 'new');
    expect(milliseconds.updatedAt, timestamp.updatedAt);
  });
  const song = SongEntity(
    id: 'test',
    title: 'Teste',
    artist: 'Teste',
    originalKey: 'Bbm',
    shapeKey: 'Am',
    capo: '1',
    content: 'Am F C G\nUma letra para testar\nOutra linha para cantar',
    url: '',
  );

  test(
    'setlist and schedule with the same ID remain distinct destinations',
    () {
      expect(const SongDestination.setlist('same').isSchedule, isFalse);
      expect(const SongDestination.schedule('same').isSchedule, isTrue);
    },
  );
  test('minor key and original capo preserve chord shapes', () {
    final saved = SongArrangement.prepare(song: song, key: 'Bbm', capo: '1');
    expect(saved.key, 'Bbm');
    expect(saved.shapeKey, 'Am');
    expect(saved.content, song.content);
  });
  test('changing capo transposes chords and preserves lyrics', () {
    final saved = SongArrangement.prepare(song: song, key: 'Bbm', capo: '0');
    expect(saved.content.split('\n').first, 'Bbm Gb Db Ab');
    expect(saved.content.split('\n').skip(1), song.content.split('\n').skip(1));
  });
  test('new target key is reflected in saved chord content', () {
    final saved = SongArrangement.prepare(song: song, key: 'Bm', capo: '0');
    expect(saved.content.split('\n').first, 'Bm G D A');
  });
  test('chords plus lyrics are usable', () {
    expect(SongContentQuality.hasLyrics(song.content), isTrue);
  });
  test('tab-only and chord-only data cannot pass as complete song', () {
    expect(
      SongContentQuality.hasLyrics(
        '[Intro] C G Am F\nParte 1 de 2\nE|----0--2--3--|\nB|----1--3--0--|',
      ),
      isFalse,
    );
    expect(SongContentQuality.hasLyrics('C G Am F\nC7M D/F# Em7 Am7'), isFalse);
    expect(() => SongContentQuality.requireLyrics(''), throwsFormatException);
  });
  test('plain lyrics without chords are not a cifra', () {
    expect(
      SongContentQuality.hasLyrics(
        'Uma letra para testar\nOutra linha para cantar',
      ),
      isFalse,
    );
  });
}
