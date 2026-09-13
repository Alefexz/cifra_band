import 'package:cifra_band/features/songs/domain/transposer_engine.dart';
import '../music/chord_shape_catalog.dart';
export '../music/chord_shape_catalog.dart' show GuitarChordShape, GuitarBarre;

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

  static const _guitarShapes = chordShapeCatalog;

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
    final canonical = clean.replaceAll('maj7', '7M').replaceAll('M7', '7M');
    final shape = _guitarShapes[canonical];
    if (shape == null) return null;
    const tuning = [40, 45, 50, 55, 59, 64];
    final pitches = <int>[];
    for (var i = 0; i < 6; i++) {
      final fret = int.tryParse(shape.positions[i]);
      if (fret != null) pitches.add(tuning[i] + fret);
    }
    final expected = _notesForChord(clean).map(_index).toSet();
    final actual = pitches.map((p) => p % 12).toSet();
    if (expected.length != actual.length || !actual.containsAll(expected)) {
      return null;
    }
    final bass = bassOf(clean);
    if (bass.isNotEmpty &&
        pitches.reduce((a, b) => a < b ? a : b) % 12 != _index(bass)) {
      return null;
    }
    return shape;
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
    return RegExp(r'^[A-G][#b]?m(?!aj)').hasMatch(chord);
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
    if (_hasMajorSeventh(chord)) {
      return isMinorChord(chord)
          ? 'Menor com sétima maior'
          : 'Maior com sétima maior';
    }
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
        !lower.contains('dim') &&
        !chord.contains('°') &&
        !chord.contains('º')) {
      intervals.add(10);
    }
    if (lower.contains('b5')) {
      intervals.remove(7);
      intervals.add(6);
    }
    if (lower.contains('#5')) {
      intervals.remove(7);
      intervals.add(8);
    }
    for (final extension in const {9: 14, 11: 17, 13: 21}.entries) {
      final match = RegExp(
        '([b#]?)${extension.key}(?![0-9])',
      ).firstMatch(lower);
      if (match != null) {
        final alteration = match.group(1) == 'b'
            ? -1
            : match.group(1) == '#'
            ? 1
            : 0;
        intervals.add(extension.value + alteration);
      }
    }
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
