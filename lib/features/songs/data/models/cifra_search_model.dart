class CifraSearchModel {
  final String id;
  final String title;
  final String artist;
  final String content;
  final String originalKey;

  CifraSearchModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.content,
    required this.originalKey,
  });

  factory CifraSearchModel.fromMap(Map<String, dynamic> map) {
    return CifraSearchModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      content: map['content'] ?? '',
      originalKey: map['original_key'] ?? map['originalKey'] ?? 'C',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'content': content,
      'original_key': originalKey,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}