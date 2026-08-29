import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/songs/domain/transposer_engine.dart';

void main() {
  test('transposeKey moves semitones while preserving minor keys', () {
    expect(TransposerEngine.transposeKey('C', 2), 'D');
    expect(TransposerEngine.transposeKey('Am', 2), 'Bm');
  });

  test('transposeCifra changes chord lines without changing lyrics', () {
    const cifra = 'C G Am F\nEu canto ao Senhor';

    final transposed = TransposerEngine.transposeCifra(cifra, 'C', 'D');

    expect(transposed, 'D A Bm G\nEu canto ao Senhor');
  });

  test('transposeCifra handles flats and minor chords', () {
    const cifra = 'C G Am F';

    final transposed = TransposerEngine.transposeCifra(cifra, 'C', 'Bb');

    expect(transposed, 'Bb F Gm Eb');
  });

  test('transposeCifra handles slash chords and chord extensions', () {
    const cifra = 'C/E D/F# Am7 G/B C7M A7(2)';

    final transposed = TransposerEngine.transposeCifra(cifra, 'C', 'D');

    expect(transposed, 'D/F# E/G# Bm7 A/C# D7M B7(2)');
  });

  test('transposeCifra keeps tab lines and lyrics untouched', () {
    const cifra = '''
[Intro] C G Am F
E|-------0---------|
A casa do Pai
Em Ti eu vou descansar
''';

    final transposed = TransposerEngine.transposeCifra(cifra, 'C', 'D');

    expect(transposed, '''
[Intro] D A Bm G
E|-------0---------|
A casa do Pai
Em Ti eu vou descansar
''');
  });
}
