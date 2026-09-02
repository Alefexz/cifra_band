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

  static const Map<String, GuitarChordShape> _guitarShapes = {
    'C': GuitarChordShape(['x', '3', '2', '0', '1', '0'], label: 'C'),
    'C#': GuitarChordShape(['x', '4', '6', '6', '6', '4'], label: 'C#'),
    'Db': GuitarChordShape(['x', '4', '6', '6', '6', '4'], label: 'Db'),
    'D': GuitarChordShape(['x', 'x', '0', '2', '3', '2'], label: 'D'),
    'D#': GuitarChordShape(['x', '6', '8', '8', '8', '6'], label: 'D#'),
    'Eb': GuitarChordShape(['x', '6', '8', '8', '8', '6'], label: 'Eb'),
    'E': GuitarChordShape(['0', '2', '2', '1', '0', '0'], label: 'E'),
    'F': GuitarChordShape(['1', '3', '3', '2', '1', '1'], label: 'F'),
    'F#': GuitarChordShape(['2', '4', '4', '3', '2', '2'], label: 'F#'),
    'Gb': GuitarChordShape(['2', '4', '4', '3', '2', '2'], label: 'Gb'),
    'G': GuitarChordShape(['3', '2', '0', '0', '0', '3'], label: 'G'),
    'G#': GuitarChordShape(['4', '6', '6', '5', '4', '4'], label: 'G#'),
    'Ab': GuitarChordShape(['4', '6', '6', '5', '4', '4'], label: 'Ab'),
    'A': GuitarChordShape(['x', '0', '2', '2', '2', '0'], label: 'A'),
    'A#': GuitarChordShape(['x', '1', '3', '3', '3', '1'], label: 'A#'),
    'Bb': GuitarChordShape(['x', '1', '3', '3', '3', '1'], label: 'Bb'),
    'B': GuitarChordShape(['x', '2', '4', '4', '4', '2'], label: 'B'),
    'Cm': GuitarChordShape(['x', '3', '5', '5', '4', '3'], label: 'Cm'),
    'C#m': GuitarChordShape(['x', '4', '6', '6', '5', '4'], label: 'C#m'),
    'Dbm': GuitarChordShape(['x', '4', '6', '6', '5', '4'], label: 'Dbm'),
    'Dm': GuitarChordShape(['x', 'x', '0', '2', '3', '1'], label: 'Dm'),
    'D#m': GuitarChordShape(['x', '6', '8', '8', '7', '6'], label: 'D#m'),
    'Ebm': GuitarChordShape(['x', '6', '8', '8', '7', '6'], label: 'Ebm'),
    'Em': GuitarChordShape(['0', '2', '2', '0', '0', '0'], label: 'Em'),
    'Fm': GuitarChordShape(['1', '3', '3', '1', '1', '1'], label: 'Fm'),
    'F#m': GuitarChordShape(['2', '4', '4', '2', '2', '2'], label: 'F#m'),
    'Gbm': GuitarChordShape(['2', '4', '4', '2', '2', '2'], label: 'Gbm'),
    'Gm': GuitarChordShape(['3', '5', '5', '3', '3', '3'], label: 'Gm'),
    'G#m': GuitarChordShape(['4', '6', '6', '4', '4', '4'], label: 'G#m'),
    'Abm': GuitarChordShape(['4', '6', '6', '4', '4', '4'], label: 'Abm'),
    'Am': GuitarChordShape(['x', '0', '2', '2', '1', '0'], label: 'Am'),
    'A#m': GuitarChordShape(['x', '1', '3', '3', '2', '1'], label: 'A#m'),
    'Bbm': GuitarChordShape(['x', '1', '3', '3', '2', '1'], label: 'Bbm'),
    'Bm': GuitarChordShape(['x', '2', '4', '4', '3', '2'], label: 'Bm'),
    'C7M': GuitarChordShape(['x', '3', '2', '0', '0', '0'], label: 'C7M'),
    'D7M': GuitarChordShape(['x', 'x', '0', '2', '2', '2'], label: 'D7M'),
    'E7M': GuitarChordShape(['0', '2', '1', '1', '0', '0'], label: 'E7M'),
    'F7M': GuitarChordShape(['x', 'x', '3', '2', '1', '0'], label: 'F7M'),
    'G7M': GuitarChordShape(['3', '2', '0', '0', '0', '2'], label: 'G7M'),
    'A7M': GuitarChordShape(['x', '0', '2', '1', '2', '0'], label: 'A7M'),
    'B7M': GuitarChordShape(['x', '2', '4', '3', '4', '2'], label: 'B7M'),
    'C7': GuitarChordShape(['x', '3', '2', '3', '1', '0'], label: 'C7'),
    'D7': GuitarChordShape(['x', 'x', '0', '2', '1', '2'], label: 'D7'),
    'E7': GuitarChordShape(['0', '2', '0', '1', '0', '0'], label: 'E7'),
    'F7': GuitarChordShape(['1', '3', '1', '2', '1', '1'], label: 'F7'),
    'G7': GuitarChordShape(['3', '2', '0', '0', '0', '1'], label: 'G7'),
    'A7': GuitarChordShape(['x', '0', '2', '0', '2', '0'], label: 'A7'),
    'B7': GuitarChordShape(['x', '2', '1', '2', '0', '2'], label: 'B7'),
    'Am7': GuitarChordShape(['x', '0', '2', '0', '1', '0'], label: 'Am7'),
    'Bm7': GuitarChordShape(['x', '2', '4', '2', '3', '2'], label: 'Bm7'),
    'Cm7': GuitarChordShape(['x', '3', '5', '3', '4', '3'], label: 'Cm7'),
    'Dm7': GuitarChordShape(['x', 'x', '0', '2', '1', '1'], label: 'Dm7'),
    'Em7': GuitarChordShape(['0', '2', '0', '0', '0', '0'], label: 'Em7'),
    'F#m7': GuitarChordShape(['2', '4', '2', '2', '2', '2'], label: 'F#m7'),
    'Gm7': GuitarChordShape(['3', '5', '3', '3', '3', '3'], label: 'Gm7'),
    'Cadd9': GuitarChordShape(['x', '3', '2', '0', '3', '0'], label: 'Cadd9'),
    'D/F#': GuitarChordShape(['2', 'x', '0', '2', '3', '2'], label: 'D/F#'),
    'C/E': GuitarChordShape(['0', '3', '2', '0', '1', '0'], label: 'C/E'),
    'G/B': GuitarChordShape(['x', '2', '0', '0', '3', '3'], label: 'G/B'),
    'A/C#': GuitarChordShape(['x', '4', '2', '2', '2', '0'], label: 'A/C#'),
    'E/G#': GuitarChordShape(['4', '2', '2', '1', '0', '0'], label: 'E/G#'),
    'F/A': GuitarChordShape(['x', '0', '3', '2', '1', '1'], label: 'F/A'),
    'Am/G': GuitarChordShape(['3', '0', '2', '2', '1', '0'], label: 'Am/G'),
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
    return ChordInsight(
      chord: cleanChord,
      simplified: simplifiedName(cleanChord),
      root: rootOf(cleanChord),
      bass: bassOf(cleanChord),
      quality: qualityLabel(cleanChord),
      notes: _notesForChord(cleanChord),
      degree: degreeForChord(cleanChord, key),
      roman: romanForChord(cleanChord, key),
      function: functionForDegree(degreeForChord(cleanChord, key), key),
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
        ? const ['1m', '2°', 'b3', '4m', '5m', 'b6', 'b7']
        : const ['1', '2m', '3m', '4', '5', '6m', '7°'];

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
        function: functionForDegree(degree, normalizedKey),
        explanation: explanationForDegree(degree, normalizedKey),
      );
    });
  }

  static String degreeForChord(String chord, String key) {
    final root = rootOf(chord);
    final tonic = rootOf(key);
    if (root.isEmpty || tonic.isEmpty) return '-';
    return _degreeName((_index(root) - _index(tonic)) % 12);
  }

  static String romanForChord(String chord, String key) {
    final degree = degreeForChord(chord, key);
    final base = _romanBase(degree);
    if (base == '-') return base;

    final lower = chord.toLowerCase();
    final minorChord = isMinorChord(chord);
    final halfDiminished = lower.contains('m7(b5)') || lower.contains('ø');
    final diminished =
        halfDiminished ||
        lower.contains('dim') ||
        chord.contains('°') ||
        chord.contains('º');
    final augmented = lower.contains('aug') || chord.contains('+');

    var roman = base;
    if (diminished) {
      roman = '${base.toLowerCase()}${halfDiminished ? 'ø' : '°'}';
    } else if (minorChord) {
      roman = base.toLowerCase();
    } else if (augmented) {
      roman = '$base+';
    }

    final suffix = _romanExtensionSuffix(chord);
    final bass = bassOf(chord);
    if (bass.isEmpty) return '$roman$suffix';

    final bassDegree = _degreeName((_index(bass) - _index(rootOf(key))) % 12);
    return '$roman$suffix/$bassDegree';
  }

  static String functionForDegree(String degree, String key) {
    final clean = degree
        .replaceAll('m', '')
        .replaceAll('°', '')
        .replaceAll('dim', '');
    final minorKey = TransposerEngine.isMinorKey(key);
    return switch (clean) {
      '1' => 'Repouso',
      '2' || '4' => 'Preparação',
      '5' || '7' => 'Tensão/volta',
      '3' || '6' when !minorKey => 'Cor suave',
      'b3' || 'b6' || 'b7' when minorKey => 'Campo menor',
      'b3' || 'b6' || 'b7' => 'Empréstimo',
      'b2' || '#4/b5' => 'Fora do campo',
      _ => 'Cor fora do campo',
    };
  }

  static String explanationForDegree(String degree, String key) {
    final clean = degree
        .replaceAll('m', '')
        .replaceAll('°', '')
        .replaceAll('dim', '');
    final minorKey = TransposerEngine.isMinorKey(key);
    return switch (clean) {
      '1' => 'Centro tonal. É o acorde que mais passa sensação de casa.',
      '2' =>
        'Grau de preparação. Costuma funcionar antes do 5 ou como passagem para voltar ao 1.',
      'b2' =>
        'Grau cromático fora do campo básico. Pode aparecer como passagem forte ou empréstimo; use com atenção.',
      'b3' =>
        minorKey
            ? 'Terceiro grau do campo menor natural. Ajuda a definir a cor menor da música.'
            : 'Emprestado do tom menor paralelo. Traz cor mais intensa dentro de uma música maior.',
      '3' =>
        'Terceiro grau em tom maior. Define bastante a sensação maior e pode puxar para o 6.',
      '4' =>
        'Subdominante. Abre a harmonia e prepara bem tanto o 1 quanto o 5.',
      '#4/b5' =>
        'Grau de passagem/tensão. Normalmente funciona como ligação, não como repouso.',
      '5' =>
        minorKey
            ? 'Quinto grau. No menor pode aparecer menor ou maior; quando vem maior/V7, a volta para o 1m fica mais forte.'
            : 'Dominante. Cria expectativa e normalmente pede resolução para o 1.',
      'b6' =>
        minorKey
            ? 'Sexto grau do campo menor natural. Muito usado para dar peso emocional.'
            : 'Empréstimo do menor paralelo. Dá cor cinematográfica/worship e pede cuidado.',
      '6' =>
        'Repouso relativo em tom maior. Quando menor, costuma abrir uma parte mais emocional.',
      'b7' =>
        minorKey
            ? 'Sétimo grau do campo menor natural. Dá volta aberta e moderna.'
            : 'Fora do campo maior diatônico; muito usado em pop/worship para voltar ao 4 ou 1.',
      '7' =>
        'Sensível do tom maior. Tem tensão alta e costuma resolver meio tom acima, no 1.',
      _ =>
        'Fora do campo básico. Pode ser empréstimo, passagem cromática, dominante secundário ou escolha da versão.',
    };
  }

  static String explanationForChord(String chord, String key) {
    final clean = chord.replaceAll('*', '').trim();
    final root = rootOf(clean);
    final bass = bassOf(clean);
    final degree = degreeForChord(clean, key);
    final roman = romanForChord(clean, key);
    final function = functionForDegree(degree, key);
    final quality = qualityLabel(clean);
    final bassText = bass.isEmpty
        ? ''
        : ' O baixo está em $bass, então a sensação pode mudar mesmo com a mesma tríade.';
    return 'No tom $key, a raiz $root aparece como $degree ($roman). '
        'Qualidade: $quality. Função provável: $function.'
        '$bassText ${explanationForDegree(degree, key)}';
  }

  static List<String> keyboardNotes(String chord) => _notesForChord(chord);

  static GuitarChordShape? guitarShapeFor(String chord) {
    final clean = chord.replaceAll('*', '').trim();
    final canonical = _canonicalGuitarKey(clean);
    final exact = _guitarShapes[canonical];
    if (exact != null) return exact;

    final root = rootOf(clean);
    final plainMajor = canonical == root;
    final plainMinor = canonical == '${root}m';
    if (!plainMajor && !plainMinor) return null;

    final simple = simplifiedName(clean);
    return _guitarShapes[simple] ??
        _guitarShapes[TransposerEngine.normalizeKey(simple)] ??
        _guitarShapes[root];
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

  static String bassOf(String value) {
    return RegExp(r'/([A-G][#b]?)').firstMatch(value)?.group(1) ?? '';
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
    if (lower.contains('aug') || chord.contains('+')) return 'Aumentado';
    if (lower.contains('sus2')) return 'Suspenso 2';
    if (lower.contains('sus4') || RegExp(r'^[A-G][#b]?4').hasMatch(chord)) {
      return 'Suspenso 4';
    }
    if (_hasMajorSeventh(chord)) return 'Maior com sétima maior';
    if (isMinorChord(chord)) {
      if (lower.contains('7')) return 'Menor com sétima';
      return 'Menor';
    }
    if (lower.contains('7')) return 'Dominante';
    if (lower.contains('6')) return 'Maior com sexta';
    if (lower.contains('9') || lower.contains('add')) return 'Maior com nona';
    return 'Maior';
  }

  static List<String> _notesForChord(String chord) {
    final root = rootOf(chord);
    if (root.isEmpty) return const [];

    final lower = chord.toLowerCase();
    final intervals = <int>[];
    if (lower.contains('m7(b5)') || lower.contains('ø')) {
      intervals.addAll([0, 3, 6, 10]);
    } else if (lower.contains('dim') ||
        chord.contains('°') ||
        chord.contains('º')) {
      intervals.addAll([0, 3, 6]);
      if (lower.contains('7')) intervals.add(9);
    } else if (lower.contains('aug') || chord.contains('+')) {
      intervals.addAll([0, 4, 8]);
    } else if (lower.contains('sus2')) {
      intervals.addAll([0, 2, 7]);
    } else if (lower.contains('sus4') ||
        RegExp(r'^[A-G][#b]?4').hasMatch(chord)) {
      intervals.addAll([0, 5, 7]);
    } else if (isMinorChord(chord)) {
      intervals.addAll([0, 3, 7]);
    } else {
      intervals.addAll([0, 4, 7]);
    }

    if (_hasMajorSeventh(chord)) {
      intervals.add(11);
    } else if (RegExp(r'7').hasMatch(chord) &&
        !lower.contains('m7(b5)') &&
        !lower.contains('dim')) {
      intervals.add(10);
    }
    if (RegExp(r'(?:add9|9|\(9\))').hasMatch(lower)) intervals.add(14);
    if (RegExp(r'(^|[^0-9])6([^0-9]|$)').hasMatch(lower)) intervals.add(9);

    final preferFlats = root.contains('b');
    final rootIndex = _index(root);
    final notes = intervals
        .map(
          (interval) =>
              _formatNote(rootIndex + interval, preferFlats: preferFlats),
        )
        .toList();

    final bass = bassOf(chord);
    if (bass.isNotEmpty) {
      notes.insert(
        0,
        _formatNote(_index(bass), preferFlats: bass.contains('b')),
      );
    }
    return _unique(notes);
  }

  static String _canonicalGuitarKey(String chord) {
    final root = rootOf(chord);
    if (root.isEmpty) return chord;
    final bass = bassOf(chord);
    final lower = chord.toLowerCase();
    if (bass.isNotEmpty) {
      return '$root${isMinorChord(chord) ? 'm' : ''}/$bass';
    }
    if (lower.contains('m7(b5)') || lower.contains('ø')) return '${root}m7(b5)';
    if (_hasMajorSeventh(chord)) return '${root}7M';
    if (isMinorChord(chord) && lower.contains('7')) return '${root}m7';
    if (lower.contains('7')) return '${root}7';
    if (isMinorChord(chord)) return '${root}m';
    if (lower.contains('add9') || RegExp(r'^[A-G][#b]?9').hasMatch(chord)) {
      return '${root}add9';
    }
    if (lower.contains('sus2')) return '${root}sus2';
    if (lower.contains('sus4') || RegExp(r'^[A-G][#b]?4').hasMatch(chord)) {
      return '${root}sus4';
    }
    return root;
  }

  static bool _hasMajorSeventh(String chord) {
    final root = rootOf(chord);
    final body = root.isEmpty ? chord : chord.substring(root.length);
    return body.contains('7M') ||
        body.contains('M7') ||
        body.toLowerCase().contains('maj7');
  }

  static String _romanExtensionSuffix(String chord) {
    final lower = chord.toLowerCase();
    if (_hasMajorSeventh(chord)) return '7M';
    if (lower.contains('7')) return '7';
    if (lower.contains('6')) return '6';
    if (lower.contains('9') || lower.contains('add9')) return '9';
    return '';
  }

  static String _degreeName(int interval) {
    return switch ((interval % 12 + 12) % 12) {
      0 => '1',
      1 => 'b2',
      2 => '2',
      3 => 'b3',
      4 => '3',
      5 => '4',
      6 => '#4/b5',
      7 => '5',
      8 => 'b6',
      9 => '6',
      10 => 'b7',
      11 => '7',
      _ => '-',
    };
  }

  static String _romanBase(String degree) {
    return switch (degree) {
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

class GuitarChordShape {
  const GuitarChordShape(this.positions, {required this.label});

  final List<String> positions;
  final String label;

  int get baseFret {
    final fretted = positions
        .map(int.tryParse)
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (fretted.isEmpty) return 1;
    final minFret = fretted.reduce((a, b) => a < b ? a : b);
    final maxFret = fretted.reduce((a, b) => a > b ? a : b);
    if (maxFret <= 5) return 1;
    return minFret;
  }
}

class ChordInsight {
  const ChordInsight({
    required this.chord,
    required this.simplified,
    required this.root,
    required this.bass,
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
  final String bass;
  final String quality;
  final List<String> notes;
  final String degree;
  final String roman;
  final String function;
  final String explanation;
  final GuitarChordShape? guitarShape;
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
