import 'dart:convert';
import 'dart:io';
import 'package:cifra_band/core/services/chord_study_service.dart';

void main() {
  for (final chord in [
    'C',
    'C7M',
    'D/F#',
    'D7/F#',
    'C7(b9)',
    'C7(#9)',
    'Cdim7',
    'Am7M',
  ]) {
    stdout.writeln(
      jsonEncode({
        'chord': chord,
        'keyboardNotes': ChordStudyService.keyboardNotes(chord),
        'guitarShapeLabel': ChordStudyService.guitarShapeFor(chord)?.label,
        'qualityLabel': ChordStudyService.qualityLabel(chord),
      }),
    );
  }
}
