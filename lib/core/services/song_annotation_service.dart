import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SongAnnotationService {
  SongAnnotationService._();

  static String _key(String title, String artist) {
    return 'song_note_${OfficialLibraryService.buildSongKey(title, artist)}';
  }

  static Future<String> load(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(title, artist)) ?? '';
  }

  static Future<void> save(String title, String artist, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(title, artist);
    if (note.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, note.trim());
    }
  }
}
