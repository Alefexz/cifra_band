import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cifra_band/core/services/account_local_data_service.dart';
import 'package:cifra_band/core/services/offline_setlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'deletion clears only UID data plus legacy downloads and blocks stale writers',
    () async {
      SharedPreferences.setMockInitialValues({
        'legacy_local_data_owner': 'a',
        'favorite_songs_a': <String>['one'],
        'favorite_songs_b': <String>['two'],
        'account_note_a_x': 'private',
        'account_note_b_x': 'keep',
        'offline_v2_a_index': <String>[],
        'offline_v2_a_x': 'private',
        'offline_v2_b_x': 'keep',
        'offline_cult_setlist_legacy': 'old',
      });
      final prefs = await SharedPreferences.getInstance();
      final stale = AccountLocalDataStore(prefs, 'a');
      AccountLocalDataService.setSession('a');
      await AccountLocalDataService.eraseAccount('a');
      expect(AccountLocalDataService.session.value, isNull);
      expect(prefs.containsKey('favorite_songs_a'), isFalse);
      expect(prefs.containsKey('offline_v2_a_x'), isFalse);
      expect(prefs.containsKey('account_note_a_x'), isFalse);
      expect(prefs.containsKey('offline_cult_setlist_legacy'), isFalse);
      expect(prefs.getStringList('favorite_songs_b'), ['two']);
      expect(prefs.getString('account_note_b_x'), 'keep');
      expect(prefs.getString('offline_v2_b_x'), 'keep');
      await stale.saveFavorites(['resurrect']);
      await stale.saveNote('x', 'resurrect');
      expect(prefs.containsKey('favorite_songs_a'), isFalse);
      expect(prefs.containsKey('account_note_a_x'), isFalse);
      await expectLater(
        OfflineSetlistStore(
          prefs,
          'a',
        ).saveCultSetlist(scheduleId: 'x', title: 'X', songs: []),
        throwsStateError,
      );
    },
  );
}
