// lib/main.dart
import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ⚠️ NOVO IMPORT DO MOTOR DE NOTIFICAÇÕES

import 'core/theme/app_theme.dart';
import 'config/routes/app_router.dart';
import 'firebase_options.dart';

// ⚠️ ESSA FUNÇÃO PRECISA FICAR AQUI FORA DE QUALQUER CLASSE!
// Ela é o robô que acorda e recebe as notificações quando o app está fechado no bolso.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Notificação recebida em background: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
    providerApple: kReleaseMode
        ? const AppleAppAttestProvider()
        : const AppleDebugProvider(),
  );

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ⚠️ AVISA O FIREBASE PARA USAR A FUNÇÃO DE BACKGROUND
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runZonedGuarded(
    () => runApp(const ProviderScope(child: CifraBandApp())),
    (error, stack) =>
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
  );
}

class CifraBandApp extends StatelessWidget {
  const CifraBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cifra Band',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Mantendo o seu tema lindão intacto
      themeMode: ThemeMode.dark,
      routerConfig: appRouter,
    );
  }
}
