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

  test('transposeCifra supports minor source and target keys', () {
    const cifra = 'Am F C G\nGalileu, Galileu';

    final transposed = TransposerEngine.transposeCifra(cifra, 'Am', 'Bbm');

    expect(transposed, 'Bbm Gb Db Ab\nGalileu, Galileu');
  });

  test('transposeCifra handles slash chords and chord extensions', () {
    const cifra = 'C/E D/F# Am7 G/B C7M A7(2)';

    final transposed = TransposerEngine.transposeCifra(cifra, 'C', 'D');

    expect(transposed, 'D/F# E/G# Bm7 A/C# D7M B7(2)');
  });

  test('resolveDisplayedKey infers minor real key from capo shape', () {
    final realKey = TransposerEngine.resolveDisplayedKey(
      originalKey: 'Bb',
      shapeKey: 'Am',
      capo: '1',
    );

    expect(realKey, 'Bbm');
    expect(TransposerEngine.isMinorKey(realKey), isTrue);
    expect(TransposerEngine.toneOptionsForKey(realKey), contains('Bbm'));
    expect(TransposerEngine.toneOptionsForKey(realKey), isNot(contains('Bb')));
  });

  test('normalizeKey extracts minor keys from scraped label text', () {
    expect(TransposerEngine.normalizeKey('Tom: Bbm (com forma de Am)'), 'Bbm');
    expect(TransposerEngine.normalizeKey('Forma: Am'), 'Am');
  });

  test('transposeCifra handles Brazilian minor notation safely', () {
    const cifra = '[Intro] Am* C Dm7* F7M G4 C/E';

    final transposed = TransposerEngine.transposeCifra(cifra, 'Am', 'Bbm');

    expect(transposed, '[Intro] Bbm* Db Ebm7* Gb7M Ab4 Db/F');
  });

  test('simplifyCifra keeps root quality while removing common extensions', () {
    const cifra = '[Intro] Am7 D/F# G7M Cadd9 F#m7(b5) B7(9) G4';

    final simplified = TransposerEngine.simplifyCifra(cifra);

    expect(simplified, '[Intro] Am D G C F#m7(b5) B Gsus4');
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
