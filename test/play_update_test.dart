import 'dart:async';
import 'package:cifra_band/core/services/app_update_play.dart';
import 'package:cifra_band/core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () =>
        messenger.setMockMethodCallHandler(PlayAppUpdateService.channel, null),
  );
  test('Play checks coalesce and do not throw on unavailable Play', () async {
    var calls = 0;
    final pending = Completer<void>();
    messenger.setMockMethodCallHandler(PlayAppUpdateService.channel, (_) async {
      calls++;
      await pending.future;
      throw PlatformException(code: 'PLAY_UNAVAILABLE');
    });
    final first = PlayAppUpdateService.checkForUpdate();
    final second = PlayAppUpdateService.checkForUpdate();
    pending.complete();
    await Future.wait([first, second]);
    expect(calls, 1);
  });
  testWidgets('Play facade never consults the Render APK manifest', (
    tester,
  ) async {
    var calls = 0;
    messenger.setMockMethodCallHandler(PlayAppUpdateService.channel, (_) async {
      calls++;
      return null;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppUpdateService.checkForUpdate(
              context,
              fetchVersion: () async =>
                  throw StateError('External APK path reached'),
            ),
            child: const Text('Check'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  }, skip: appFlavor != 'play');
}
