import 'package:cifra_band/core/services/offline_setlist_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '21 downloads survive reopening; only explicit deletion removes one',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = OfflineSetlistStore(prefs, 'account-a');
      for (var i = 1; i <= 21; i++) {
        await store.saveCultSetlist(
          scheduleId: '$i',
          title: 'Setlist $i',
          songs: [
            SongModel(
              id: '$i',
              title: 'Song $i',
              artist: 'Test',
              originalKey: 'C',
              content: 'C G\nSynthetic test words',
              url: '',
            ),
          ],
        );
      }
      final reopened = OfflineSetlistStore(prefs, 'account-a');
      expect(await reopened.listSummaries(), hasLength(21));
      for (var i = 1; i <= 21; i++) {
        expect((await reopened.loadCultSetlist('$i'))?.songs.single.id, '$i');
      }
      expect(
        await OfflineSetlistStore(prefs, 'account-b').listSummaries(),
        isEmpty,
      );
      await reopened.deleteCultSetlist('2');
      expect(await reopened.listSummaries(), hasLength(20));
      expect(await reopened.loadCultSetlist('2'), isNull);
      expect(await reopened.loadCultSetlist('1'), isNotNull);
      expect(await reopened.loadCultSetlist('21'), isNotNull);
    },
  );
}
