import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifra_band/core/services/chord_study_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:cifra_band/features/songs/presentation/screens/cifra_screen.dart';
import 'package:cifra_band/features/songs/presentation/widgets/chord_diagrams/guitar_chord_diagram.dart';
import 'package:cifra_band/features/songs/presentation/widgets/chord_diagrams/keyboard_chord_diagram.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['CHORD_PREVIEW'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/chord-previews').create(recursive: true);
    await File(
      'build/chord-previews/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.isWindows) {
      final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      await (FontLoader(
        'PreviewFont',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  test(
    'catalogue preserves exact bass, explicit barre and unknown fingering',
    () {
      expect(ChordStudyService.guitarShapeFor('F')!.barres.single.fret, 1);
      expect(ChordStudyService.guitarShapeFor('F')!.barres.single.endString, 5);
      expect(ChordStudyService.guitarShapeFor('G')!.fingers, isNull);
      expect(ChordStudyService.guitarShapeFor('D/F#')!.positions.first, '2');
      expect(ChordStudyService.guitarShapeFor('C#7'), isNull);
    },
  );
  for (final dark in [true, false]) {
    for (final compact in [true, false]) {
      testWidgets('diagrams dark=$dark compact=$compact', (tester) async {
        tester.view.physicalSize = const Size(360, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final text = dark ? Colors.white : Colors.black;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'PreviewFont'),
            home: RepaintBoundary(
              key: const Key('capture'),
              child: Scaffold(
                backgroundColor: dark ? const Color(0xFF16161E) : Colors.white,
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final chord in ['G', 'F', 'D/F#', 'C#7', 'G#']) ...[
                        Text(chord, style: TextStyle(color: text)),
                        GuitarChordDiagram(
                          shape: ChordStudyService.guitarShapeFor(chord),
                          notes: ChordStudyService.keyboardNotes(chord),
                          compact: compact,
                          color: Colors.orangeAccent,
                          textColor: text,
                          lineColor: Colors.grey,
                        ),
                      ],
                      KeyboardChordDiagram(
                        notes: const ['G', 'B', 'D'],
                        color: Colors.greenAccent,
                        textColor: text,
                        lineColor: Colors.grey,
                        compact: compact,
                      ),
                      KeyboardChordDiagram(
                        notes: const ['F#', 'D', 'A'],
                        color: Colors.greenAccent,
                        textColor: text,
                        lineColor: Colors.grey,
                        compact: compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is GuitarChordPainter,
          ),
          findsNWidgets(4),
        );
        expect(find.textContaining('Digitação não cadastrada'), findsOneWidget);
        await capture(tester, 'diagrams-$dark-$compact');
      });
    }
  }
  testWidgets('empty notes and missing shape do not paint a grid', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            GuitarChordDiagram(
              shape: null,
              notes: [],
              color: Colors.orange,
              textColor: Colors.black,
              lineColor: Colors.grey,
            ),
            KeyboardChordDiagram(
              notes: [],
              color: Colors.green,
              textColor: Colors.black,
              lineColor: Colors.grey,
            ),
          ],
        ),
      ),
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            (w.painter is GuitarChordPainter ||
                w.painter is KeyboardChordPainter),
      ),
      findsNothing,
    );
  });

  for (final dark in [true, false]) {
    testWidgets(
      'real cifra screen chord modal is scrollable on a small display $dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'cifra_stage_mode': dark});
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'PreviewFont'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: RepaintBoundary(key: const Key('capture'), child: child!),
            ),
            home: const CifraScreen(
              recordHistory: false,
              song: SongModel(
                id: 'diagram-test',
                title: 'Teste de acordes',
                artist: 'Validação local',
                originalKey: 'C',
                content:
                    '[Intro] G F D/F# C#7\nLinha de teste para os diagramas',
                url: '',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Adicionar à setlist'), findsOneWidget);
        expect(find.text('Tom Real: C'), findsOneWidget);
        expect(find.text('Simplificada'), findsOneWidget);
        expect(find.text('Anotação'), findsOneWidget);
        expect(find.text(dark ? 'Modo Palco' : 'Modo Claro'), findsOneWidget);
        expect(find.byTooltip('Reportar problema nesta cifra'), findsNothing);
        await capture(tester, 'cifra-header-$dark');
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Reportar problema nesta cifra'), findsOneWidget);
        await tester.ensureVisible(find.text('Reportar problema nesta cifra'));
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(find.text('Reportar problema nesta cifra'), findsNothing);
        final card = find.text('F', findRichText: true).last;
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'modal-F-$dark');
        await tester.ensureVisible(find.text('Teclado').last);
        await tester.tap(find.text('Teclado').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(tester, 'modal-keyboard-$dark');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
