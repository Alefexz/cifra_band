import 'dart:async';
import 'dart:convert';
import 'package:cifra_band/core/services/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> manifest(int build, {bool required = true}) => {
  'latestVersion': '1.0.$build',
  'latestBuild': build,
  'minimumBuild': required ? build : 1,
  'updateRequired': required,
  'apkUrl': 'https://example.test/build-$build.apk',
  'releaseNotes': 'Build $build',
};

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Test',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'test',
    );
    SharedPreferences.setMockInitialValues({
      'required_app_update': jsonEncode(manifest(6)),
    });
  });

  testWidgets(
    'cached mandatory dialog stays blocked while manifest refreshes live',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold(body: Text('App content'));
            },
          ),
        ),
      );
      final response = Completer<http.Response?>();
      var requests = 0;
      final checking = AppUpdateService.checkForUpdate(
        page,
        fetchVersion: () {
          requests++;
          return response.future;
        },
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(find.text('Disponível: 1.0.6+6'), findsOneWidget);
      expect(find.text('Depois'), findsNothing);
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      response.complete(
        http.Response(jsonEncode(manifest(7, required: false)), 200),
      );
      await tester.pumpAndSettle();
      expect(find.text('Disponível: 1.0.7+7'), findsOneWidget);
      expect(find.text('Depois'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('required_app_update')!);
      expect(saved['latestBuild'], 7);
      expect(saved['minimumBuild'], 6);
      expect(saved['apkUrl'], 'https://example.test/build-7.apk');

      // A resume/check while the dialog is open must also refresh it.
      await AppUpdateService.checkForUpdate(
        page,
        fetchVersion: () async {
          requests++;
          return http.Response(jsonEncode(manifest(8)), 200);
        },
      );
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Disponível: 1.0.8+8'), findsOneWidget);
      expect(
        jsonDecode(prefs.getString('required_app_update')!)['latestBuild'],
        8,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await checking;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final scenario in ['offline', 'invalid', 'older', 'http-error']) {
    testWidgets('$scenario response preserves the cached mandatory block', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: Builder(
            builder: (context) {
              page = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final pending = Completer<http.Response?>();
      final checking = AppUpdateService.checkForUpdate(
        page,
        fetchVersion: () => pending.future,
      );
      await tester.pumpAndSettle();
      if (scenario == 'offline') {
        pending.completeError(StateError('Offline test'));
      } else if (scenario == 'http-error') {
        pending.complete(http.Response('{}', 503));
      } else {
        final data = scenario == 'older'
            ? manifest(5)
            : {...manifest(9), 'apkUrl': 'http://unsafe.test/file.apk'};
        pending.complete(http.Response(jsonEncode(data), 200));
      }
      await tester.pumpAndSettle();
      expect(find.text('Disponível: 1.0.6+6'), findsOneWidget);
      expect(find.text('Depois'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('required_app_update')!)['latestBuild'],
        6,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await checking;
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
