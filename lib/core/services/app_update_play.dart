import 'package:flutter/services.dart';

class PlayAppUpdateService {
  static const channel = MethodChannel('cifra_band/play_updates');
  static bool _checking = false;
  static Future<void> checkForUpdate() async {
    if (_checking) return;
    _checking = true;
    try {
      await channel.invokeMethod<void>('checkForUpdate');
    } on PlatformException {
      // Offline, unavailable Play, or installation not owned by this Play account.
      // Never fall back to an APK installer in the Play distribution.
    } on MissingPluginException {
      // Non-Android previews do not have Play Services.
    } finally {
      _checking = false;
    }
  }
}
