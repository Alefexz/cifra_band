import 'package:cifra_band/features/songs/domain/transposer_engine.dart';

class ChordStudyService {
  ChordStudyService._();

  static const _sharpNotes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  static const Map<String, List<String>> guitarShapes = {
    'C': ['x', '3', '2', '0', '1', '0'],
    'Cm': ['x', '3', '5', '5', '4', '3'],
    'D': ['x', 'x', '0', '2', '3', '2'],
    'Dm': ['x', 'x', '0', '2', '3', '1'],
    'E': ['0', '2', '2', '1', '0', '0'],
    'Em': ['0', '2', '2', '0', '0', '0'],
    'F': ['1', '3', '3', '2', '1', '1'],
    'Fm': ['1', '3', '3', '1', '1', '1'],
    'G': ['3', '2', '0', '0', '0', '3'],
    'Gm': ['3', '5', '5', '3', '3', '3'],
    'A': ['x', '0', '2', '2', '2', '0'],
    'Am': ['x', '0', '2', '2', '1', '0'],
    'B': ['x', '2', '4', '4', '4', '2'],
    'Bm': ['x', '2', '4', '4', '3', '2'],
  };

  static List<String> uniqueChords(String content) {
    final chords = <String>{};
    for (final line in content.split('\n')) {
      if (!TransposerEngine.isChordLine(line)) continue;
      for (final token in line.trim().split(RegExp(r'\s+'))) {
        if (TransposerEngine.isChordToken(token)) {
          chords.add(token.replaceAll('*', ''));
        }
      }
    }
    return chords.toList()..sort();
  }

  static String degreeForChord(String chord, String key) {
    final root = _root(chord);
    final tonic = _root(key);
    if (root.isEmpty || tonic.isEmpty) return '-';
    final diff = (_index(root) - _index(tonic)) % 12;
    const degrees = {
      0: '1',
      1: 'b2',
      2: '2',
      3: 'b3',
      4: '3',
      5: '4',
      6: '#4/b5',
      7: '5',
      8: 'b6',
      9: '6',
      10: 'b7',
      11: '7',
    };
    final quality =
        RegExp(r'^[A-G][#b]?m(?!aj)', caseSensitive: false).hasMatch(chord)
        ? 'm'
        : '';
    return '${degrees[diff] ?? '-'}$quality';
  }

  static List<String> keyboardNotes(String chord) {
    final root = _root(chord);
    if (root.isEmpty) return const [];
    final lower = chord.toLowerCase();
    final intervals = lower.contains('dim')
        ? const [0, 3, 6]
        : lower.contains('aug')
        ? const [0, 4, 8]
        : lower.contains('sus2')
        ? const [0, 2, 7]
        : lower.contains('sus4')
        ? const [0, 5, 7]
        : RegExp(r'^[A-G][#b]?m(?!aj)').hasMatch(chord)
        ? const [0, 3, 7]
        : const [0, 4, 7];
    final rootIndex = _index(root);
    return intervals.map((i) => _sharpNotes[(rootIndex + i) % 12]).toList();
  }

  static String simplifiedName(String chord) {
    final simplified = TransposerEngine.simplifyChord(chord);
    return simplified.replaceAll('*', '');
  }

  static String _root(String value) {
    final match = RegExp(
      r'^([A-G][#b]?)(?:m)?',
    ).firstMatch(TransposerEngine.normalizeKey(value));
    if (match == null) {
      return RegExp(r'^([A-G][#b]?)').firstMatch(value)?.group(1) ?? '';
    }
    return match.group(1) ?? '';
  }

  static int _index(String note) {
    final normalized = note
        .replaceAll('Db', 'C#')
        .replaceAll('Eb', 'D#')
        .replaceAll('Gb', 'F#')
        .replaceAll('Ab', 'G#')
        .replaceAll('Bb', 'A#');
    final index = _sharpNotes.indexOf(normalized);
    return index < 0 ? 0 : index;
  }
}
