import '../../domain/entities/song_entity.dart';

class SongModel extends SongEntity {
  const SongModel({
    required super.id,
    required super.title,
    required super.artist,
    required super.originalKey,
    super.shapeKey,
    super.capo,
    required super.content,
    required super.url,
  });

  factory SongModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return SongModel(
      id: documentId,
      title: _string(map['title']),
      artist: _string(map['artist']),
      originalKey: _string(map['originalKey']),
      shapeKey: _stringOrNull(map['shapeKey']),
      capo: _stringOrNull(map['capo']),
      content: _string(map['content']),
      url: _string(map['url']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'originalKey': originalKey,
      'shapeKey': shapeKey,
      'capo': capo,
      'content': content,
      'url': url,
    };
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;

    final valueString = value.toString().trim();

    if (valueString.isEmpty) return null;

    return valueString;
  }
}