import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/home/presentation/widgets/song_lookup_dialog.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';
import 'package:cifra_band/features/songs/data/datasources/song_scraper_datasource.dart';

const sample = SongEntity(
  id: 'sample',
  title: 'Porque Ele Vive - 545',
  artist: 'Harpa Cristã',
  originalKey: 'A',
  content: 'A D\nLetra de teste',
  url: '',
);

Future<void> openLookup(
  WidgetTester tester,
  Future<SongEntity> Function() loader, {
  ValueChanged<SongLookupOutcome?>? onDone,
  Size size = const Size(390, 844),
  double scale = 1,
  Brightness brightness = Brightness.dark,
  Duration deadline = const Duration(seconds: 90),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: brightness == Brightness.dark
            ? const ColorScheme.dark(
                primary: Color(0xff00ff7f),
                surface: Color(0xff1e1e1e),
              )
            : const ColorScheme.light(primary: Color(0xff236ad5)),
        fontFamily: 'PreviewFont',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: const Key('capture'), child: child!),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<SongLookupOutcome>(
                context: context,
                barrierDismissible: false,
                builder: (_) => SongLookupDialog(
                  title: sample.title,
                  artist: sample.artist,
                  loadSong: loader,
                  deadline: deadline,
                ),
              );
              onDone?.call(result);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('shows immediate loading, slow message and cancellation', (
    tester,
  ) async {
    final pending = Completer<SongEntity>();
    await openLookup(tester, () => pending.future);
    expect(find.text('Buscando cifra'), findsOneWidget);
    expect(find.text(sample.title), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('levando mais tempo'), findsOneWidget);
    expect(find.textContaining('acordando'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    pending.complete(sample);
    await tester.pumpAndSettle();
    expect(find.byType(SongLookupDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns song and closes on success', (tester) async {
    SongLookupOutcome? result;
    await openLookup(
      tester,
      () async => sample,
      onDone: (value) => result = value,
    );
    await tester.pumpAndSettle();
    expect(result?.song, same(sample));
    expect(find.byType(SongLookupDialog), findsNothing);
  });

  testWidgets('error stays visible and retry succeeds without another dialog', (
    tester,
  ) async {
    var count = 0;
    await openLookup(tester, () async {
      if (++count == 1) throw StateError('internal-secret');
      return sample;
    });
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('internal-secret'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(count, 2);
    expect(find.byType(SongLookupDialog), findsNothing);
  });

  testWidgets('search error can be returned for contextual support', (
    tester,
  ) async {
    SongLookupOutcome? outcome;
    await openLookup(
      tester,
      () async => throw const SongSearchException(
        message: 'Nenhuma versão confiável nas fontes consultadas.',
      ),
      onDone: (value) => outcome = value,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar problema'));
    await tester.pumpAndSettle();
    expect(outcome?.reportMessage, contains('fontes consultadas'));
  });

  testWidgets('deadline releases spinner and ignores late completion', (
    tester,
  ) async {
    final pending = Completer<SongEntity>();
    await openLookup(
      tester,
      () => pending.future,
      deadline: const Duration(seconds: 2),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Tentar novamente'), findsOneWidget);
    pending.complete(sample);
    await tester.pumpAndSettle();
    expect(find.byType(SongLookupDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar aviso'));
    await tester.pumpAndSettle();
  });

  testWidgets('back cancels without late navigation', (tester) async {
    final pending = Completer<SongEntity>();
    await openLookup(tester, () => pending.future);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    pending.completeError(StateError('late failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets('completion does not dismiss a dialog above the lookup', (
    tester,
  ) async {
    final pending = Completer<SongEntity>();
    await openLookup(tester, () => pending.future);
    final context = tester.element(find.byType(SongLookupDialog));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Atualização'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Concluir'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    pending.complete(sample);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Atualização'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(SongLookupDialog), findsNothing);
  });

  testWidgets('loading preview at normal phone size', (tester) async {
    if (Platform.isWindows) {
      await tester.runAsync(() async {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        await (FontLoader(
          'PreviewFont',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
    }
    final pending = Completer<SongEntity>();
    await openLookup(tester, () => pending.future);
    expect(tester.takeException(), isNull);
    if (Platform.environment['POPUP_PREVIEW'] == '1') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/popup-busca.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    pending.complete(sample);
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'responsive popup ${brightness.name}, large text and screenshot',
      (tester) async {
        if (Platform.isWindows) {
          await tester.runAsync(() async {
            final icons = FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
            await icons.load();
            final bytes = await File(
              'C:/Windows/Fonts/arial.ttf',
            ).readAsBytes();
            await (FontLoader(
              'PreviewFont',
            )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
          });
        }
        await openLookup(
          tester,
          () async => throw StateError('network'),
          size: const Size(320, 640),
          scale: 1.5,
          brightness: brightness,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['POPUP_PREVIEW'] == '1') {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const Key('capture')),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/popup-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Reportar problema'));
        await tester.tap(find.text('Reportar problema'));
        await tester.pumpAndSettle();
      },
    );
  }
}
