import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:cifra_band/features/songs/presentation/screens/cifra_screen.dart';
import 'package:cifra_band/features/songs/presentation/widgets/chord_diagrams/guitar_chord_diagram.dart';
import 'package:cifra_band/features/songs/presentation/widgets/chord_diagrams/keyboard_chord_diagram.dart';

void main() {
  for (final capo in [0, 2]) {
    testWidgets('chord detail uses sounding notes, capo $capo', (tester) async {
      SharedPreferences.setMockInitialValues({'cifra_stage_mode': true});
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CifraScreen(
            recordHistory: false,
            song: SongModel(
              id: 'capo',
              title: 'Capo test',
              artist: 'Test',
              originalKey: capo == 2 ? 'D' : 'C',
              shapeKey: 'C',
              capo: '$capo',
              content: '[Intro] C G Am F\nSynthetic words for a chord test',
              url: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chord = find.text('C', findRichText: true).last;
      await tester.ensureVisible(chord);
      await tester.tap(chord);
      await tester.pumpAndSettle();
      expect(find.text('Grau 1'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('Grau b7'), findsNothing);
      expect(
        find.text(capo == 2 ? 'Notas: D - F# - A' : 'Notas: C - E - G'),
        findsOneWidget,
      );
      final guitar = tester.widget<GuitarChordDiagram>(
        find.byType(GuitarChordDiagram),
      );
      expect(guitar.shape!.positions, ['x', '3', '2', '0', '1', '0']);
      await tester.ensureVisible(find.text('Teclado').last);
      await tester.tap(find.text('Teclado').last);
      await tester.pumpAndSettle();
      final keyboard = tester.widget<KeyboardChordDiagram>(
        find.byType(KeyboardChordDiagram),
      );
      expect(keyboard.notes, capo == 2 ? ['D', 'F#', 'A'] : ['C', 'E', 'G']);
      expect(find.text('Grau 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
