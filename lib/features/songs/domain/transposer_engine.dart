// lib/features/songs/domain/transposer_engine.dart

class TransposerEngine {
  static const List<String> _sharpScale = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
  static const List<String> _flatScale = ['C','Db','D','Eb','E','F','Gb','G','Ab','A','Bb','B'];

  static const Set<String> _flatKeys = {'F','Bb','Eb','Ab','Db','Gb','Dm','Gm','Cm','Fm','Bbm','Ebm'};

  static String normalizeKey(String key) {
    var value = key.trim();
    if (value.isEmpty) return '';
    value = value.replaceAll('♯','#').replaceAll('♭','b');
    if (value == 'A#') value = 'Bb';
    if (value == 'D#') value = 'Eb';
    if (value == 'G#') value = 'Ab';
    if (value == 'C#') value = 'C#';
    if (value == 'F#') value = 'F#';
    return value;
  }

  static bool _isMinorKey(String key) => key.trim().toLowerCase().endsWith('m');

  static String _removeMinor(String key) {
    final value = normalizeKey(key);
    if (value.endsWith('m')) return value.substring(0, value.length - 1);
    return value;
  }

  static int _noteToIndex(String note) {
    switch (normalizeKey(note)) {
      case 'C': return 0;
      case 'C#': case 'Db': return 1;
      case 'D': return 2;
      case 'D#': case 'Eb': return 3;
      case 'E': return 4;
      case 'F': return 5;
      case 'F#': case 'Gb': return 6;
      case 'G': return 7;
      case 'G#': case 'Ab': return 8;
      case 'A': return 9;
      case 'A#': case 'Bb': return 10;
      case 'B': return 11;
      default: return -1;
    }
  }

  static int _wrap12(int value) {
    final result = value % 12;
    return result < 0 ? result + 12 : result;
  }

  static String _formatNote(int index, {bool preferFlats = false}) {
    final normalized = _wrap12(index);
    return preferFlats ? _flatScale[normalized] : _sharpScale[normalized];
  }

  static String transposeKey(String currentKey, int semitones) {
    final key = normalizeKey(currentKey);
    if (key.isEmpty || semitones == 0) return key;

    final root = _removeMinor(key);
    final index = _noteToIndex(root);
    if (index == -1) return key;

    final targetIndex = _wrap12(index + semitones);
    final originalUsesFlats = root.contains('b') || _flatKeys.contains(key);
    final targetNote = _formatNote(targetIndex, preferFlats: originalUsesFlats);

    return _isMinorKey(key) ? '${targetNote}m' : targetNote;
  }

  static int getSemitonesDifference(String currentKey, String targetKey) {
    final current = _noteToIndex(_removeMinor(currentKey));
    final target = _noteToIndex(_removeMinor(targetKey));
    if (current == -1 || target == -1) return 0;
    return target - current;
  }

  // ⚠️ SOLUÇÃO 2: REGRA AMPLIADA PARA ACORDES BRASILEIROS (C7M, A7(2), etc)
  static final RegExp chordTokenRegex = RegExp(
    r'^[A-G][#b]?(?:m|M|maj|min|dim|aug|sus|add|\d|[#b+-]|\(|\)|/[A-G][#b]?)*$'
  );

  static bool isChordToken(String token) {
    final value = token.trim();
    if (value.isEmpty) return false;
    final cleaned = value.replaceAll(RegExp(r'^[,;:]+'), '').replaceAll(RegExp(r'[,;:]+$'), '');
    return chordTokenRegex.hasMatch(cleaned);
  }

  static bool isTabLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^[eEBGDA]\|').hasMatch(trimmed)) return true;
    if (trimmed.contains('|---') || trimmed.contains('|--') || trimmed.contains('|-')) return true;
    return false;
  }

  static bool isHeaderLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('[') && trimmed.endsWith(']');
  }

  static String _transposeNote(String note, int semitones, bool preferFlats) {
    final index = _noteToIndex(note);
    if (index == -1) return note;
    return _formatNote(index + semitones, preferFlats: preferFlats);
  }

  static String transposeChord(String chord, int semitones, {bool preferFlats = false}) {
    final value = chord.trim();
    if (value.isEmpty || semitones == 0) return value;
    if (!isChordToken(value)) return value;

    final rootMatch = RegExp(r'^([A-G][#b]?)').firstMatch(value);
    if (rootMatch == null) return value;

    final root = rootMatch.group(1)!;
    final rest = value.substring(root.length);
    String newRest = rest;

    final slashMatch = RegExp(r'^(.*/)([A-G][#b]?)(.*)$').firstMatch(rest);
    if (slashMatch != null) {
      final beforeBass = slashMatch.group(1)!;
      final bass = slashMatch.group(2)!;
      final afterBass = slashMatch.group(3)!;
      final newBass = _transposeNote(bass, semitones, preferFlats);
      newRest = '$beforeBass$newBass$afterBass';
    }

    final newRoot = _transposeNote(root, semitones, preferFlats);
    return '$newRoot$newRest';
  }

  static bool isChordLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (isHeaderLine(trimmed)) return false;
    if (isTabLine(trimmed)) return false;

    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return false;

    int chords = 0;
    for (final token in tokens) {
      if (isChordToken(token)) chords++;
    }
    return chords > 0 && chords >= (tokens.length / 2);
  }

  static String _transposeChordLine(String line, int semitones, {bool preferFlats = false}) {
    // ⚠️ SOLUÇÃO 1: FIM DOS ACORDES GRUDADOS! Substitui no lugar, sem apagar nenhum espaço.
    return line.replaceAllMapped(RegExp(r'\S+'), (match) {
      final token = match.group(0)!;
      if (isChordToken(token)) {
        return transposeChord(token, semitones, preferFlats: preferFlats);
      }
      return token;
    });
  }

  static String transposeCifra(String content, String currentKey, String targetKey) {
    if (content.isEmpty) return content;
    if (currentKey.isEmpty || targetKey.isEmpty) return content;

    final semitones = getSemitonesDifference(currentKey, targetKey);
    if (semitones == 0) return content;

    final targetNormalized = normalizeKey(targetKey);
    final preferFlats = targetNormalized.contains('b') || _flatKeys.contains(targetNormalized);

    final lines = content.split('\n');
    final result = <String>[];

    for (final line in lines) {
      if (isTabLine(line) || isHeaderLine(line)) {
        result.add(line);
        continue;
      }
      if (isChordLine(line)) {
        result.add(_transposeChordLine(line, semitones, preferFlats: preferFlats));
        continue;
      }
      result.add(line);
    }
    return result.join('\n');
  }

  static String transposeSong({
    required String content,
    required String originalKey,
    required String shapeKey,
    required String capo,
    required String targetKey,
  }) {
    if (content.isEmpty) return '';
    if (originalKey == targetKey || targetKey.isEmpty) return content;
    return transposeCifra(content, originalKey, targetKey);
  }
}