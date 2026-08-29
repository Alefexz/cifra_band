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
}
