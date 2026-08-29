class SongEntity {
  final String id;
  final String title;
  final String artist;

  /// Tom REAL da música.
  /// Ex.: G
  final String originalKey;

  /// Tom/formato dos acordes escritos na cifra.
  /// Ex.: F quando a música está em G com capo na 2ª casa.
  final String? shapeKey;

  /// Casa do capotraste.
  /// Ex.: 2
  final String? capo;
  final String? referenceUrl;
  final String? rehearsalNotes;
  final String? bpm;

  final String content;
  final String url;

  const SongEntity({
    required this.id,
    required this.title,
    required this.artist,
    required this.originalKey,
    this.shapeKey,
    this.capo,
    this.referenceUrl,
    this.rehearsalNotes,
    this.bpm,
    required this.content,
    required this.url,
  });
}
