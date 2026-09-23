import 'dart:io';
import 'dart:ui' as ui;
import 'package:cifra_band/core/services/rehearsal_preparation.dart';
import 'package:cifra_band/core/services/rehearsal_service.dart';
import 'package:cifra_band/features/home/presentation/widgets/rehearsal_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final song = <String, dynamic>{
    'title': 'Musica de teste',
    'artist': 'Equipe',
    'originalKey': 'D',
    'capo': '2',
    'shapeKey': 'C',
    'content': 'C G\nTexto de teste',
  };
  RehearsalPreparation ready() => RehearsalPreparation(
    stage: PreparationStage.ready,
    revision: RehearsalPreparation.revisionOf(song),
  );

  test(
    'missing preparation is pending, legacy ready requires revision confirmation',
    () {
      expect(
        RehearsalPreparation.fromMap(null).forSong(song),
        PreparationStage.pending,
      );
      expect(
        RehearsalPreparation.fromMap({'rehearsed': true}).forSong(song),
        PreparationStage.needsReview,
      );
    },
  );
  test('ready requires exact musical revision', () {
    expect(ready().forSong(song), PreparationStage.ready);
    for (final field in [
      'originalKey',
      'key',
      'shapeKey',
      'capo',
      'bpm',
      'content',
      'referenceUrl',
      'rehearsalNotes',
    ]) {
      expect(
        ready().forSong({...song, field: 'changed'}),
        PreparationStage.needsReview,
        reason: field,
      );
    }
  });
  test('non-musical metadata and map ordering do not reset readiness', () {
    expect(
      ready().forSong({
        ...song,
        'votes': ['one'],
        'order': 4,
      }),
      PreparationStage.ready,
    );
    expect(
      ready().forSong(Map.fromEntries(song.entries.toList().reversed)),
      PreparationStage.ready,
    );
  });
  test('state parsing handles all stored values and preserves notes', () {
    for (final stage in PreparationStage.values.where(
      (s) => s != PreparationStage.needsReview,
    )) {
      final parsed = RehearsalPreparation.fromMap({
        'preparation': stage.name,
        'note': 'Entrada do teclado',
        'arrangementRevision': RehearsalPreparation.revisionOf(song),
      });
      expect(parsed.forSong(song), stage);
      expect(parsed.note, 'Entrada do teclado');
    }
  });
  test(
    'team denominator deduplicates roles and excludes declined assignments',
    () {
      final members = RehearsalMember.fromAssignments([
        {'uid': 'a', 'name': 'Ana', 'role': 'Voz'},
        {'uid': 'a', 'name': 'Ana', 'role': 'Teclado'},
        {'uid': 'b', 'status': 'declined'},
        {},
        'invalid',
      ]);
      expect(members.length, 1);
      expect(members.single.roles, ['Voz', 'Teclado']);
    },
  );

  Widget host(Widget child, {double textScale = 1}) => MaterialApp(
    theme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'PreviewFont'),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: const Key('rehearsal-capture'),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('board counts only assigned members and opens exact song', (
    tester,
  ) async {
    Map<String, dynamic>? opened;
    final key = RehearsalService.songKey('Musica de teste', 'Equipe');
    await tester.pumpWidget(
      host(
        RehearsalBoard(
          songs: [song],
          members: const [
            RehearsalMember('a', 'Ana', ['Teclado']),
            RehearsalMember('b', 'Bia', ['Voz']),
          ],
          statuses: {'a_$key': ready(), 'stranger_$key': ready()},
          currentUid: 'a',
          openSong: (value) => opened = value,
          edit: (_, _) {},
        ),
      ),
    );
    expect(find.text('1 de 2 integrantes preparados'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir cifra'));
    expect(opened, song);
  });
  testWidgets('empty repertoire is explicit', (tester) async {
    await tester.pumpWidget(
      host(
        RehearsalBoard(
          songs: const [],
          members: const [],
          statuses: const {},
          currentUid: '',
          openSong: (_) {},
          edit: (_, _) {},
        ),
      ),
    );
    expect(
      find.text('Nenhuma música aprovada para este ensaio.'),
      findsOneWidget,
    );
  });
  for (final size in [const Size(320, 640), const Size(800, 1000)]) {
    testWidgets('board supports $size with large text', (tester) async {
      if (Platform.environment['REHEARSAL_PREVIEW'] == '1' &&
          Platform.isWindows) {
        await tester.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
          await (FontLoader(
            'PreviewFont',
          )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
        });
      }
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          RehearsalBoard(
            songs: [
              {
                ...song,
                'title':
                    'Um titulo bastante longo para verificar quebra de linha',
                'rehearsalNotes': 'Entrada do teclado depois da segunda parte.',
              },
            ],
            members: const [
              RehearsalMember('a', 'Nome comprido do integrante', [
                'Voz',
                'Teclado',
              ]),
            ],
            statuses: const {},
            currentUid: 'a',
            openSong: (_) {},
            edit: (_, _) {},
          ),
          textScale: 1.6,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      if (Platform.environment['REHEARSAL_PREVIEW'] == '1') {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('rehearsal-capture')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/ministry-readiness').create(recursive: true);
          await File(
            'build/ministry-readiness/rehearsal-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
  testWidgets('editing only a note never marks a song ready', (tester) async {
    PreparationStage? savedStage = PreparationStage.ready;
    String? savedNote;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPreparationEditor(
              context,
              song: song,
              current: const RehearsalPreparation(note: 'Anterior'),
              save: (stage, note) async {
                savedStage = stage;
                savedNote = note;
              },
            ),
            child: const Text('Editar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Anterior'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Preciso rever a ponte');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(savedStage, isNull);
    expect(savedNote, 'Preciso rever a ponte');
  });
  testWidgets(
    'small-screen editor supports large text and explicit help status',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PreparationStage? saved;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showPreparationEditor(
                context,
                song: song,
                current: const RehearsalPreparation(),
                save: (stage, _) async => saved = stage,
              ),
              child: const Text('Editar'),
            ),
          ),
          textScale: 1.6,
        ),
      );
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<PreparationStage>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preciso de ajuda').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Salvar'));
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(saved, PreparationStage.needsHelp);
    },
  );
  testWidgets('failed save keeps the note and allows retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPreparationEditor(
              context,
              song: song,
              current: const RehearsalPreparation(),
              save: (_, _) async {
                attempts++;
                if (attempts == 1) throw StateError('offline');
              },
            ),
            child: const Text('Editar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Minha nota');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Minha nota'), findsOneWidget);
    expect(find.textContaining('Não foi possível salvar.'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
