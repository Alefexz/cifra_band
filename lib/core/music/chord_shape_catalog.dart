const Map<String, GuitarChordShape> chordShapeCatalog = {
  'C': GuitarChordShape(['x', '3', '2', '0', '1', '0'], label: 'C'),
  'C#': GuitarChordShape(['x', '4', '6', '6', '6', '4'], label: 'C#'),
  'Db': GuitarChordShape(['x', '4', '6', '6', '6', '4'], label: 'Db'),
  'D': GuitarChordShape(['x', 'x', '0', '2', '3', '2'], label: 'D'),
  'D#': GuitarChordShape(['x', '6', '8', '8', '8', '6'], label: 'D#'),
  'Eb': GuitarChordShape(['x', '6', '8', '8', '8', '6'], label: 'Eb'),
  'E': GuitarChordShape(['0', '2', '2', '1', '0', '0'], label: 'E'),
  'F': GuitarChordShape(
    ['1', '3', '3', '2', '1', '1'],
    label: 'F',
    fingers: [1, 3, 4, 2, 1, 1],
    barres: [GuitarBarre(fret: 1, fromString: 0, endString: 5)],
  ),
  'F#': GuitarChordShape(
    ['2', '4', '4', '3', '2', '2'],
    label: 'F#',
    barres: [GuitarBarre(fret: 2, fromString: 0, endString: 5)],
  ),
  'Gb': GuitarChordShape(
    ['2', '4', '4', '3', '2', '2'],
    label: 'Gb',
    barres: [GuitarBarre(fret: 2, fromString: 0, endString: 5)],
  ),
  'G': GuitarChordShape(['3', '2', '0', '0', '0', '3'], label: 'G'),
  'G#': GuitarChordShape(
    ['4', '6', '6', '5', '4', '4'],
    label: 'G#',
    barres: [GuitarBarre(fret: 4, fromString: 0, endString: 5)],
  ),
  'Ab': GuitarChordShape(
    ['4', '6', '6', '5', '4', '4'],
    label: 'Ab',
    barres: [GuitarBarre(fret: 4, fromString: 0, endString: 5)],
  ),
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
  'Fm': GuitarChordShape(
    ['1', '3', '3', '1', '1', '1'],
    label: 'Fm',
    barres: [GuitarBarre(fret: 1, fromString: 0, endString: 5)],
  ),
  'F#m': GuitarChordShape(
    ['2', '4', '4', '2', '2', '2'],
    label: 'F#m',
    barres: [GuitarBarre(fret: 2, fromString: 0, endString: 5)],
  ),
  'Gbm': GuitarChordShape(
    ['2', '4', '4', '2', '2', '2'],
    label: 'Gbm',
    barres: [GuitarBarre(fret: 2, fromString: 0, endString: 5)],
  ),
  'Gm': GuitarChordShape(
    ['3', '5', '5', '3', '3', '3'],
    label: 'Gm',
    barres: [GuitarBarre(fret: 3, fromString: 0, endString: 5)],
  ),
  'G#m': GuitarChordShape(
    ['4', '6', '6', '4', '4', '4'],
    label: 'G#m',
    barres: [GuitarBarre(fret: 4, fromString: 0, endString: 5)],
  ),
  'Abm': GuitarChordShape(
    ['4', '6', '6', '4', '4', '4'],
    label: 'Abm',
    barres: [GuitarBarre(fret: 4, fromString: 0, endString: 5)],
  ),
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
  'F7': GuitarChordShape(
    ['1', '3', '1', '2', '1', '1'],
    label: 'F7',
    barres: [GuitarBarre(fret: 1, fromString: 0, endString: 5)],
  ),
  'G7': GuitarChordShape(['3', '2', '0', '0', '0', '1'], label: 'G7'),
  'A7': GuitarChordShape(['x', '0', '2', '0', '2', '0'], label: 'A7'),
  'B7': GuitarChordShape(['x', '2', '1', '2', '0', '2'], label: 'B7'),
  'Am7': GuitarChordShape(['x', '0', '2', '0', '1', '0'], label: 'Am7'),
  'Bm7': GuitarChordShape(['x', '2', '4', '2', '3', '2'], label: 'Bm7'),
  'Cm7': GuitarChordShape(['x', '3', '5', '3', '4', '3'], label: 'Cm7'),
  'Dm7': GuitarChordShape(['x', 'x', '0', '2', '1', '1'], label: 'Dm7'),
  'Em7': GuitarChordShape(['0', '2', '0', '0', '0', '0'], label: 'Em7'),
  'F#m7': GuitarChordShape(
    ['2', '4', '2', '2', '2', '2'],
    label: 'F#m7',
    barres: [GuitarBarre(fret: 2, fromString: 0, endString: 5)],
  ),
  'Gm7': GuitarChordShape(
    ['3', '5', '3', '3', '3', '3'],
    label: 'Gm7',
    barres: [GuitarBarre(fret: 3, fromString: 0, endString: 5)],
  ),
  'Cadd9': GuitarChordShape(['x', '3', '2', '0', '3', '0'], label: 'Cadd9'),
  'D/F#': GuitarChordShape(['2', 'x', '0', '2', '3', '2'], label: 'D/F#'),
  'D7/F#': GuitarChordShape(['2', 'x', '0', '2', '1', '2'], label: 'D7/F#'),
  'Cdim7': GuitarChordShape(['x', '3', '4', '2', '4', 'x'], label: 'Cdim7'),
  'Am7M': GuitarChordShape(['x', '0', '2', '1', '1', '0'], label: 'Am7M'),
  'C7(b9)': GuitarChordShape(['x', '3', '2', '3', '2', '3'], label: 'C7(b9)'),
  'C7(#9)': GuitarChordShape(['x', '3', '2', '3', '4', '3'], label: 'C7(#9)'),
  'C/E': GuitarChordShape(['0', '3', '2', '0', '1', '0'], label: 'C/E'),
  'G/B': GuitarChordShape(['x', '2', '0', '0', '3', '3'], label: 'G/B'),
  'A/C#': GuitarChordShape(['x', '4', '2', '2', '2', '0'], label: 'A/C#'),
  'E/G#': GuitarChordShape(['4', '2', '2', '1', '0', '0'], label: 'E/G#'),
  'F/A': GuitarChordShape(['x', '0', '3', '2', '1', '1'], label: 'F/A'),
  'Am/G': GuitarChordShape(['3', '0', '2', '2', '1', '0'], label: 'Am/G'),
};

class GuitarChordShape {
  const GuitarChordShape(
    this.positions, {
    required this.label,
    this.fingers,
    this.barres = const [],
  });

  final List<String> positions;
  final String label;
  final List<int?>? fingers;
  final List<GuitarBarre> barres;

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

class GuitarBarre {
  const GuitarBarre({
    required this.fret,
    required this.fromString,
    required this.endString,
  });
  final int fret;
  // Zero-based strings, low E to high e.
  final int fromString;
  final int endString;
}
