import 'transposer_engine.dart';

class SongContentQuality {
  static const incompleteMessage =
      'Esta cifra não contém letra suficiente para acompanhar a música. '
      'Não encontrei uma versão completa confiável. Tente outra versão ou reporte o problema.';

  static bool hasLyrics(String content) {
    var lyricLines = 0;
    var words = 0;
    var chords = 0;
    for (final raw in content.split('\n')) {
      final line = raw.replaceAll(RegExp(r'\[[^\]]*\]'), ' ').trim();
      if (line.isEmpty ||
          TransposerEngine.isTabLine(line) ||
          RegExp(
            r'^(?:parte\s+\d|tom\s*:|capo|afina|intro|solo|refr[aã]o|verso|ponte|final|repete|sem capotraste|com capotraste)',
            caseSensitive: false,
          ).hasMatch(line)) {
        continue;
      }
      final tokens = line.split(RegExp(r'\s+'));
      chords += tokens.where(TransposerEngine.isChordToken).length;
      if (tokens.every(
        (t) =>
            TransposerEngine.isChordToken(t) ||
            RegExp(r'^[|():/\d.xX-]+$').hasMatch(t),
      ))
        continue;
      final lineWords = RegExp(r'[A-Za-zÀ-ÿ]{2,}').allMatches(line).length;
      if (lineWords >= 2) {
        lyricLines++;
        words += lineWords;
      }
    }
    return lyricLines >= 2 && words >= 6 && chords >= 2;
  }

  static void requireLyrics(String content) {
    if (!hasLyrics(content)) throw const FormatException(incompleteMessage);
  }
}
