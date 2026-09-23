import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'app_update_direct.dart' as direct;
import 'app_update_play.dart';
export 'app_update_direct.dart' show AppUpdateInfo;

class AppUpdateService {
  // appFlavor is a compile-time constant: the unused updater is tree-shaken.
  static Future<void> checkForUpdate(
    BuildContext context, {
    Future<http.Response?> Function()? fetchVersion,
  }) {
    if (appFlavor == 'play') return PlayAppUpdateService.checkForUpdate();
    return direct.AppUpdateService.checkForUpdate(
      context,
      fetchVersion: fetchVersion,
    );
  }
}
