import 'entities/song_entity.dart';
import 'transposer_engine.dart';

class SongArrangement {
  const SongArrangement(this.key, this.shapeKey, this.content);
  final String key;
  final String shapeKey;
  final String content;

  factory SongArrangement.prepare({
    required SongEntity song,
    required String key,
    required String capo,
  }) {
    final sourceKey = (song.shapeKey ?? '').isNotEmpty
        ? song.shapeKey!
        : song.originalKey;
    final shape = TransposerEngine.transposeKey(
      key,
      -(int.tryParse(capo) ?? 0),
    );
    return SongArrangement(
      key,
      shape,
      TransposerEngine.transposeCifra(song.content, sourceKey, shape),
    );
  }
}
