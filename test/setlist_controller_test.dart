import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cifra_band/features/home/presentation/providers/home_providers.dart';
import 'package:cifra_band/features/setlist/domain/entities/setlist_entity.dart';
import 'package:cifra_band/features/setlist/domain/repositories/setlist_repository.dart';
import 'package:cifra_band/features/setlist/presentation/controllers/setlist_controller.dart';
import 'package:cifra_band/features/setlist/presentation/providers/setlist_providers.dart';

class TestUser implements User {
  TestUser(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRepository implements SetlistRepository {
  final streams = <String, StreamController<List<SetlistEntity>>>{};
  bool failCreate = false;
  final watched = <String>[];
  @override
  Stream<List<SetlistEntity>> watchSetlistsByUser(String uid) {
    watched.add(uid);
    return (streams[uid] ??= StreamController.broadcast()).stream;
  }

  @override
  Future<List<SetlistEntity>> getSetlistsByUser(String uid) =>
      throw StateError('The screen must subscribe, not fetch once.');

  @override
  Future<void> createSetlist(SetlistEntity setlist) async {
    if (failCreate) throw StateError('Save failed');
    streams[setlist.ownerId]!.add([setlist]);
  }

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

SetlistEntity playlist({
  String title = 'Domingo',
  List<String> songs = const [],
}) => SetlistEntity(
  id: 'list',
  title: title,
  ownerId: 'a',
  sharedWith: [],
  songIds: songs,
  updatedAt: DateTime(2026),
);

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestRepository repo;
  late StreamController<User?> auth;
  late ProviderContainer container;

  setUp(() async {
    repo = TestRepository();
    auth = StreamController<User?>();
    container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWith((ref) => auth.stream),
        setlistRepositoryProvider.overrideWithValue(repo),
      ],
    );
    container.listen(
      setlistControllerProvider,
      (_, _) {},
      fireImmediately: true,
    );
    auth.add(TestUser('a'));
    await flush();
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
    await repo.close();
  });

  test(
    'count, name and removal update without refresh or navigation',
    () async {
      repo.streams['a']!.add([playlist()]);
      await flush();
      expect(
        container.read(setlistControllerProvider).requireValue.single.songIds,
        isEmpty,
      );
      repo.streams['a']!.add([
        playlist(title: 'Ensaio', songs: ['one', 'two']),
      ]);
      await flush();
      final updated = container
          .read(setlistControllerProvider)
          .requireValue
          .single;
      expect(updated.songIds.length, 2);
      expect(updated.title, 'Ensaio');
      repo.streams['a']!.add([]);
      await flush();
      expect(container.read(setlistControllerProvider).requireValue, isEmpty);
      expect(repo.watched, ['a']);
    },
  );

  test('account change cancels old listener and logout clears lists', () async {
    repo.streams['a']!.add([playlist()]);
    await flush();
    auth.add(TestUser('b'));
    await flush();
    expect(repo.streams['a']!.hasListener, isFalse);
    repo.streams['b']!.add([]);
    repo.streams['a']!.add([
      playlist(songs: ['private']),
    ]);
    await flush();
    expect(container.read(setlistControllerProvider).requireValue, isEmpty);
    auth.add(null);
    await flush();
    expect(repo.streams['b']!.hasListener, isFalse);
    expect(container.read(setlistControllerProvider).requireValue, isEmpty);
  });

  test(
    'create uses live result and write failure does not replace lists',
    () async {
      await container
          .read(setlistControllerProvider.notifier)
          .addSetlist(playlist());
      await flush();
      expect(
        container.read(setlistControllerProvider).requireValue.single.title,
        'Domingo',
      );
      repo.failCreate = true;
      await expectLater(
        container
            .read(setlistControllerProvider.notifier)
            .addSetlist(playlist()),
        throwsStateError,
      );
      expect(
        container.read(setlistControllerProvider).requireValue.single.title,
        'Domingo',
      );
    },
  );

  test('stream error is visible and subsequent snapshots recover', () async {
    repo.streams['a']!.addError(StateError('Permission denied'));
    await flush();
    expect(container.read(setlistControllerProvider).hasError, isTrue);
    repo.streams['a']!.add([
      playlist(songs: ['one']),
    ]);
    await flush();
    expect(
      container
          .read(setlistControllerProvider)
          .requireValue
          .single
          .songIds
          .length,
      1,
    );
  });
}
