// lib/main.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // ⚠️ NOVO IMPORT DO MOTOR DE NOTIFICAÇÕES

import 'core/theme/app_theme.dart';
import 'config/routes/app_router.dart';
import 'core/services/app_diagnostics_service.dart';
import 'core/services/app_update_service.dart';
import 'core/services/push_notification_service.dart';
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
      FlutterError.onError = (details) {
        AppDiagnosticsService.log(
          'Erro fatal do Flutter',
          level: 'fatal',
          error: details.exception,
          stackTrace: details.stack,
          context: {
            'library': details.library,
            'context': details.context?.toString(),
          },
        );
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppDiagnosticsService.log(
          'Erro fatal de plataforma',
          level: 'fatal',
          error: error,
          stackTrace: stack,
        );
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
      AppDiagnosticsService.log(
        'Erro capturado pela zona principal',
        level: 'fatal',
        error: error,
        stackTrace: stack,
      );
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
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _updateMessageSubscription;
  StreamSubscription<RemoteMessage>? _updateOpenedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateMessageSubscription = FirebaseMessaging.onMessage.listen(
      _onUpdateMessage,
    );
    _updateOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _onUpdateMessage,
    );
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _syncCrashContext,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdateWhenNavigatorIsReady();
    });
  }

  Future<void> _syncCrashContext(User? user) async {
    if (user != null) unawaited(PushNotificationService.syncInstalledVersion());
    try {
      if (user == null) {
        await FirebaseCrashlytics.instance.setUserIdentifier('');
        await FirebaseCrashlytics.instance.setCustomKey('uid', '');
        await FirebaseCrashlytics.instance.setCustomKey('church_id', '');
        await FirebaseCrashlytics.instance.setCustomKey('is_admin', false);
        AppDiagnosticsService.setContext({'auth': 'signed_out'});
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final churchId = '${userData['church_id'] ?? ''}'.trim();
      final isAdmin = userData['is_admin'] == true;

      await FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
      await FirebaseCrashlytics.instance.setCustomKey('uid', user.uid);
      await FirebaseCrashlytics.instance.setCustomKey('church_id', churchId);
      await FirebaseCrashlytics.instance.setCustomKey('is_admin', isAdmin);
      await FirebaseCrashlytics.instance.setCustomKey(
        'user_email',
        user.email ?? '',
      );

      AppDiagnosticsService.setContext({
        'uid': user.uid,
        'email': user.email,
        'church_id': churchId,
        'is_admin': isAdmin,
      });
    } catch (error, stackTrace) {
      AppDiagnosticsService.log(
        'Falha ao sincronizar contexto de diagnostico',
        level: 'warning',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onUpdateMessage(RemoteMessage message) {
    if (message.data['type'] == 'app_update_available') {
      _checkForUpdateWhenNavigatorIsReady();
    }
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
      unawaited(PushNotificationService.syncInstalledVersion());
      BackendWarmupService.wake(reason: 'app_resumed');
      _checkForUpdateWhenNavigatorIsReady();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _updateMessageSubscription?.cancel();
    _updateOpenedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
