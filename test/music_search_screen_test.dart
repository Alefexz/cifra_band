import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cifra_band/features/home/data/music_search_service.dart';
import 'package:cifra_band/features/home/presentation/screens/search_screen.dart';
import 'music_search_test.dart' show song, response;

Future<void> mount(
  WidgetTester tester,
  MockClient client, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'PreviewFont',
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const Key('preview'),
          child: SearchScreen(
            searchService: MusicSearchService(client: client),
            loadDiscovery: false,
          ),
        ),
      ),
    ),
  );
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hymn result visible first; artist repertoire cannot bury it', (
    tester,
  ) async {
    if (Platform.isWindows) {
      await tester.runAsync(() async {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
        final font = FontLoader('PreviewFont')
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await font.load();
      });
    }
    await mount(
      tester,
      MockClient(
        (_) async => response([
          song('Porque Ele Vive', 'Dunamis Music'),
          song('Porque Ele Vive - HC 545', 'Nossa Harpa', 2),
          song('Nao Ter', 'Sandy e Junior'),
        ]),
      ),
    );
    await search(tester, 'por que ele vive 545');
    expect(find.text('Porque Ele Vive - 545'), findsOneWidget);
    expect(find.text('Dunamis Music'), findsNothing);
    expect(find.text('TOP MÚSICAS'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Porque Ele Vive - 545')).dy,
      lessThan(tester.getTopLeft(find.text('Porque Ele Vive - HC 545')).dy),
    );
    expect(tester.takeException(), isNull);
    if (Platform.environment['SEARCH_PREVIEW'] == '1') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/search-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets(
    'artist and albums load only on click; unrelated songs not on music tab',
    (tester) async {
      var lookups = 0;
      await mount(
        tester,
        MockClient((r) async {
          if (r.url.path == '/lookup') {
            lookups++;
            return response([song('Faz Chover', 'Fernandinho')]);
          }
          return response([song('Galileu', 'Fernandinho')]);
        }),
      );
      await search(tester, 'Galileu Fernandinho');
      expect(lookups, 0);
      expect(
        tester.getTopLeft(find.text('Galileu')).dy,
        lessThan(tester.getTopLeft(find.text('Ver músicas')).dy),
      );
      expect(find.text('Faz Chover'), findsNothing);
      await tester.tap(find.text('Ver músicas'));
      await tester.pumpAndSettle();
      expect(lookups, 1);
      expect(find.text('Faz Chover'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale error cannot replace a newer query or show snackbar', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    await mount(
      tester,
      MockClient(
        (r) => r.url.queryParameters['term'] == 'antiga'
            ? old.future
            : Future.value(response([song('Galileu', 'Fernandinho')])),
      ),
    );
    await tester.enterText(find.byType(TextField), 'antiga');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField), 'Galileu');
    old.complete(http.Response('', 503));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Galileu'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      find.text('Não foi possível consultar o catálogo agora.'),
      findsNothing,
    );
  });

  testWidgets('small viewport and larger text render without overflow', (
    tester,
  ) async {
    await mount(
      tester,
      MockClient(
        (_) async =>
            response([song('Porque Ele Vive - HC 545', 'Nossa Harpa')]),
      ),
      size: const Size(320, 700),
      scale: 1.5,
    );
    await search(tester, 'por que ele vive 545');
    expect(tester.takeException(), isNull);
  });

  testWidgets('no match stays empty instead of showing discovery songs', (
    tester,
  ) async {
    await mount(tester, MockClient((_) async => response([])));
    await search(tester, 'inexistente');
    expect(find.text('Nenhum resultado relevante nesta aba.'), findsOneWidget);
    expect(find.text('Gospel em destaque hoje'), findsNothing);
  });
}
