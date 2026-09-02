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

  static const _flatNotes = [
    'C',
    'Db',
    'D',
    'Eb',
    'E',
    'F',
    'Gb',
    'G',
    'Ab',
    'A',
    'Bb',
    'B',
  ];

  static const _flatKeys = {
    'F',
    'Bb',
    'Eb',
    'Ab',
    'Db',
    'Gb',
    'Dm',
    'Gm',
    'Cm',
    'Fm',
    'Bbm',
    'Ebm',
  };

  static const Map<String, List<String>> guitarShapes = {
    'C': ['x', '3', '2', '0', '1', '0'],
    'C#': ['x', '4', '6', '6', '6', '4'],
    'Db': ['x', '4', '6', '6', '6', '4'],
    'D': ['x', 'x', '0', '2', '3', '2'],
    'D#': ['x', '6', '8', '8', '8', '6'],
    'Eb': ['x', '6', '8', '8', '8', '6'],
    'E': ['0', '2', '2', '1', '0', '0'],
    'F': ['1', '3', '3', '2', '1', '1'],
    'F#': ['2', '4', '4', '3', '2', '2'],
    'Gb': ['2', '4', '4', '3', '2', '2'],
    'G': ['3', '2', '0', '0', '0', '3'],
    'G#': ['4', '6', '6', '5', '4', '4'],
    'Ab': ['4', '6', '6', '5', '4', '4'],
    'A': ['x', '0', '2', '2', '2', '0'],
    'A#': ['x', '1', '3', '3', '3', '1'],
    'Bb': ['x', '1', '3', '3', '3', '1'],
    'B': ['x', '2', '4', '4', '4', '2'],
    'Cm': ['x', '3', '5', '5', '4', '3'],
    'C#m': ['x', '4', '6', '6', '5', '4'],
    'Dbm': ['x', '4', '6', '6', '5', '4'],
    'Dm': ['x', 'x', '0', '2', '3', '1'],
    'D#m': ['x', '6', '8', '8', '7', '6'],
    'Ebm': ['x', '6', '8', '8', '7', '6'],
    'Em': ['0', '2', '2', '0', '0', '0'],
    'Fm': ['1', '3', '3', '1', '1', '1'],
    'F#m': ['2', '4', '4', '2', '2', '2'],
    'Gbm': ['2', '4', '4', '2', '2', '2'],
    'Gm': ['3', '5', '5', '3', '3', '3'],
    'G#m': ['4', '6', '6', '4', '4', '4'],
    'Abm': ['4', '6', '6', '4', '4', '4'],
    'Am': ['x', '0', '2', '2', '1', '0'],
    'A#m': ['x', '1', '3', '3', '2', '1'],
    'Bbm': ['x', '1', '3', '3', '2', '1'],
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
    return chords.toList()..sort(_compareChords);
  }

  static ChordInsight insightFor(String chord, String key) {
    final cleanChord = chord.replaceAll('*', '').trim();
    final simple = simplifiedName(cleanChord);
    final degree = degreeForChord(cleanChord, key);
    final root = rootOf(cleanChord);
    return ChordInsight(
      chord: cleanChord,
      simplified: simple,
      root: root,
      quality: qualityLabel(cleanChord),
      notes: keyboardNotes(cleanChord),
      degree: degree,
      roman: romanForChord(cleanChord, key),
      function: functionForDegree(degree),
      explanation: explanationForChord(cleanChord, key),
      guitarShape: guitarShapeFor(cleanChord),
    );
  }

  static List<ScaleDegreeInfo> degreeMapForKey(String key) {
    final normalizedKey = TransposerEngine.normalizeKey(key);
    final minor = TransposerEngine.isMinorKey(normalizedKey);
    final tonic = rootOf(normalizedKey);
    if (tonic.isEmpty) return const [];

    final preferFlats =
        tonic.contains('b') || _flatKeys.contains(normalizedKey);
    final intervals = minor
        ? const [0, 2, 3, 5, 7, 8, 10]
        : const [0, 2, 4, 5, 7, 9, 11];
    final qualities = minor
        ? const ['m', 'dim', '', 'm', 'm', '', '']
        : const ['', 'm', 'm', '', '', 'm', 'dim'];
    final romans = minor
        ? const ['i', 'ii°', 'III', 'iv', 'v', 'VI', 'VII']
        : const ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii°'];
    final numeric = minor
        ? const ['1m', '2dim', 'b3', '4m', '5m', 'b6', 'b7']
        : const ['1', '2m', '3m', '4', '5', '6m', '7dim'];

    final tonicIndex = _index(tonic);
    return List.generate(7, (index) {
      final note = _formatNote(
        tonicIndex + intervals[index],
        preferFlats: preferFlats,
      );
      final chord = '$note${qualities[index]}';
      final degree = numeric[index];
      return ScaleDegreeInfo(
        degree: degree,
        roman: romans[index],
        chord: chord,
        function: functionForDegree(degree),
        explanation: explanationForDegree(degree, normalizedKey),
      );
    });
  }

  static String degreeForChord(String chord, String key) {
    final root = rootOf(chord);
    final tonic = rootOf(key);
    if (root.isEmpty || tonic.isEmpty) return '-';
    final diff = (_index(root) - _index(tonic)) % 12;
    const majorDegrees = {
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
    final quality = isMinorChord(chord) ? 'm' : '';
    return '${majorDegrees[diff] ?? '-'}$quality';
  }

  static String romanForChord(String chord, String key) {
    final degree = degreeForChord(chord, key).replaceAll('m', '');
    final minorChord = isMinorChord(chord);
    final diminished =
        chord.toLowerCase().contains('dim') ||
        chord.contains('°') ||
        chord.contains('º') ||
        chord.toLowerCase().contains('m7(b5)');
    final base = switch (degree) {
      '1' => 'I',
      'b2' => 'bII',
      '2' => 'II',
      'b3' => 'bIII',
      '3' => 'III',
      '4' => 'IV',
      '#4/b5' => '#IV/bV',
      '5' => 'V',
      'b6' => 'bVI',
      '6' => 'VI',
      'b7' => 'bVII',
      '7' => 'VII',
      _ => '-',
    };
    if (base == '-') return base;
    if (diminished) return '${base.toLowerCase()}°';
    return minorChord ? base.toLowerCase() : base;
  }

  static String functionForDegree(String degree) {
    final clean = degree.replaceAll('m', '').replaceAll('dim', '');
    return switch (clean) {
      '1' || '3' || '6' => 'Repouso',
      '2' || '4' || 'b6' => 'Preparação',
      '5' || '7' || 'b7' => 'Tensão/volta',
      'b3' => 'Cor menor',
      '#4/b5' => 'Passagem',
      _ => 'Cor fora do campo',
    };
  }

  static String explanationForDegree(String degree, String key) {
    final clean = degree.replaceAll('m', '').replaceAll('dim', '');
    final minorKey = TransposerEngine.isMinorKey(key);
    return switch (clean) {
      '1' => 'Centro do tom. É onde a música parece descansar e resolver.',
      '2' =>
        'Grau de preparação. Em louvor costuma empurrar bem para o 5 ou voltar para o 1.',
      'b3' =>
        minorKey
            ? 'Marca muito o clima menor. Dá identidade emocional ao tom.'
            : 'Acorde emprestado do tom menor paralelo. Traz uma cor mais intensa.',
      '3' =>
        'Ajuda a definir se o tom soa maior. Também aparece como passagem para o 6.',
      '4' =>
        'Abre a harmonia e cria sensação de levantar. Muito comum antes do 1 ou do 5.',
      '5' =>
        minorKey
            ? 'No tom menor pode aparecer menor ou maior. Quando vira maior/V7, cria uma volta forte para o 1m.'
            : 'Dominante. Cria expectativa e normalmente quer voltar para o 1.',
      'b6' =>
        'Cor forte em tons menores e worship moderno. Costuma dar peso antes de voltar.',
      '6' =>
        'Repouso relativo. Em tom maior, o 6m costuma abrir uma parte mais emocional.',
      'b7' =>
        'Volta mais aberta e moderna. Muito usado para criar caminho para 4 ou 1.',
      '7' =>
        'Tensão máxima dentro do tom maior. Normalmente pede resolução para o 1.',
      '#4/b5' =>
        'Grau de passagem. Use como cor ou ligação, não como ponto de descanso.',
      _ =>
        'Esse grau foge do campo básico do tom. Pode ser empréstimo, passagem ou acorde da versão específica.',
    };
  }

  static String explanationForChord(String chord, String key) {
    final degree = degreeForChord(chord, key);
    final roman = romanForChord(chord, key);
    final function = functionForDegree(degree);
    final quality = qualityLabel(chord).toLowerCase();
    return 'No tom $key, $chord funciona como $degree ($roman). '
        'A sensação principal é $function. '
        'Como acorde $quality, ${explanationForDegree(degree, key)}';
  }

  static List<String> keyboardNotes(String chord) {
    final root = rootOf(chord);
    if (root.isEmpty) return const [];
    final lower = chord.toLowerCase();
    final intervals = <int>[
      if (lower.contains('dim') ||
          lower.contains('°') ||
          lower.contains('º') ||
          lower.contains('m7(b5)')) ...[
        0,
        3,
        6,
      ] else if (lower.contains('aug')) ...[
        0,
        4,
        8,
      ] else if (lower.contains('sus2')) ...[
        0,
        2,
        7,
      ] else if (lower.contains('sus4')) ...[
        0,
        5,
        7,
      ] else if (isMinorChord(chord)) ...[
        0,
        3,
        7,
      ] else ...[
        0,
        4,
        7,
      ],
    ];

    if (RegExp(r'(?:maj7|7m|m7m|7M|M7)').hasMatch(chord)) {
      intervals.add(11);
    } else if (RegExp(r'7').hasMatch(chord)) {
      intervals.add(10);
    }
    if (RegExp(r'(?:add9|9)').hasMatch(lower)) intervals.add(14);
    if (RegExp(r'6').hasMatch(lower)) intervals.add(9);

    final slashBass = RegExp(r'/([A-G][#b]?)').firstMatch(chord)?.group(1);
    final rootIndex = _index(root);
    final notes = intervals
        .map((interval) => _sharpNotes[(rootIndex + interval) % 12])
        .toList();
    if (slashBass != null) {
      notes.insert(0, _sharpNotes[_index(slashBass)]);
    }
    return _unique(notes);
  }

  static List<String>? guitarShapeFor(String chord) {
    final simple = simplifiedName(chord);
    return guitarShapes[simple] ??
        guitarShapes[TransposerEngine.normalizeKey(simple)] ??
        guitarShapes[rootOf(chord)];
  }

  static String simplifiedName(String chord) {
    final simplified = TransposerEngine.simplifyChord(chord);
    return simplified.replaceAll('*', '');
  }

  static String rootOf(String value) {
    final normalized = TransposerEngine.normalizeKey(value);
    final normalizedMatch = RegExp(
      r'^([A-G][#b]?)(?:m)?',
    ).firstMatch(normalized);
    if (normalizedMatch != null) return normalizedMatch.group(1) ?? '';
    return RegExp(r'^([A-G][#b]?)').firstMatch(value)?.group(1) ?? '';
  }

  static bool isMinorChord(String chord) {
    return RegExp(r'^[A-G][#b]?m(?!aj)', caseSensitive: false).hasMatch(chord);
  }

  static String qualityLabel(String chord) {
    final lower = chord.toLowerCase();
    if (lower.contains('m7(b5)') || lower.contains('ø')) {
      return 'Meio-diminuto';
    }
    if (lower.contains('dim') || chord.contains('°') || chord.contains('º')) {
      return 'Diminuto';
    }
    if (lower.contains('aug')) return 'Aumentado';
    if (lower.contains('sus2')) return 'Suspenso 2';
    if (lower.contains('sus4') || RegExp(r'^[A-G][#b]?4').hasMatch(chord)) {
      return 'Suspenso 4';
    }
    if (lower.contains('maj7') || lower.contains('7m')) {
      return 'Maior com sétima maior';
    }
    if (isMinorChord(chord)) {
      if (lower.contains('7')) return 'Menor com sétima';
      return 'Menor';
    }
    if (lower.contains('7')) return 'Dominante';
    return 'Maior';
  }

  static int _compareChords(String left, String right) {
    final leftRoot = _index(rootOf(left));
    final rightRoot = _index(rootOf(right));
    if (leftRoot != rightRoot) return leftRoot.compareTo(rightRoot);
    return left.compareTo(right);
  }

  static String _formatNote(int index, {required bool preferFlats}) {
    final normalized = index % 12;
    final safeIndex = normalized < 0 ? normalized + 12 : normalized;
    return preferFlats ? _flatNotes[safeIndex] : _sharpNotes[safeIndex];
  }

  static List<String> _unique(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      if (seen.add(value)) result.add(value);
    }
    return result;
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

class ChordInsight {
  const ChordInsight({
    required this.chord,
    required this.simplified,
    required this.root,
    required this.quality,
    required this.notes,
    required this.degree,
    required this.roman,
    required this.function,
    required this.explanation,
    required this.guitarShape,
  });

  final String chord;
  final String simplified;
  final String root;
  final String quality;
  final List<String> notes;
  final String degree;
  final String roman;
  final String function;
  final String explanation;
  final List<String>? guitarShape;
}

class ScaleDegreeInfo {
  const ScaleDegreeInfo({
    required this.degree,
    required this.roman,
    required this.chord,
    required this.function,
    required this.explanation,
  });

  final String degree;
  final String roman;
  final String chord;
  final String function;
  final String explanation;
}
