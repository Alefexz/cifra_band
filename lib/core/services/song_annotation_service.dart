import 'package:cifra_band/core/services/official_library_service.dart';
import 'account_local_data_service.dart';

class SongAnnotationService {
  SongAnnotationService._();

  static String _key(String title, String artist) {
    return OfficialLibraryService.buildSongKey(title, artist);
  }

  static Future<String> load(String title, String artist) async {
    return AccountLocalDataService.current?.loadNote(_key(title, artist)) ?? '';
  }

  static Future<void> save(String title, String artist, String note) async {
    final store = AccountLocalDataService.current;
    if (store == null) {
      throw StateError('Entre na conta para salvar anotações.');
    }
    await store.saveNote(_key(title, artist), note);
  }
}
