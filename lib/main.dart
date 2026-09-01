// lib/main.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ⚠️ NOVO IMPORT DO MOTOR DE NOTIFICAÇÕES

import 'core/theme/app_theme.dart';
import 'config/routes/app_router.dart';
import 'core/services/app_update_service.dart';
import 'core/services/backend_warmup_service.dart';
import 'firebase_options.dart';

// ⚠️ ESSA FUNÇÃO PRECISA FICAR AQUI FORA DE QUALQUER CLASSE!
// Ela é o robô que acorda e recebe as notificações quando o app está fechado no bolso.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔔 Notificação recebida em background: ${message.messageId}");
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      BackendWarmupService.wake(reason: 'main_start');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // ⚠️ AVISA O FIREBASE PARA USAR A FUNÇÃO DE BACKGROUND
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      runApp(const ProviderScope(child: CifraBandApp()));
    },
    (error, stack) {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
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
      builder: (context, child) {
        return _StartupHooks(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _StartupHooks extends StatefulWidget {
  const _StartupHooks({required this.child});

  final Widget child;

  @override
  State<_StartupHooks> createState() => _StartupHooksState();
}

class _StartupHooksState extends State<_StartupHooks>
    with WidgetsBindingObserver {
  static const int _maxUpdateCheckAttempts = 8;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdateWhenNavigatorIsReady();
    });
  }

  void _checkForUpdateWhenNavigatorIsReady([int attempt = 0]) {
    if (!mounted) return;

    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext != null && navigatorContext.mounted) {
      AppUpdateService.checkForUpdate(navigatorContext);
      return;
    }

    if (attempt >= _maxUpdateCheckAttempts) {
      debugPrint(
        'Verificacao de atualizacao ignorada: Navigator indisponivel.',
      );
      return;
    }

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _checkForUpdateWhenNavigatorIsReady(attempt + 1);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackendWarmupService.wake(reason: 'app_resumed');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
