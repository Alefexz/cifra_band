// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
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

  // ⚠️ AVISA O FIREBASE PARA USAR A FUNÇÃO DE BACKGROUND
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: CifraBandApp()));
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