// lib/core/services/api_notification.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiNotification {
  static const String _url = 'https://cifraband-api.onrender.com/notificar';

  // 1. QUANDO ALGUÉM FOR ESCALADO
  static Future<void> notificarEscalado(
    String uid,
    String nomeCulto,
    String funcao,
  ) async {
    await _enviar(
      userIds: [uid], // Manda só para a pessoa escalada
      title: '🎸 Você foi escalado!',
      body: 'Sua presença foi solicitada no $nomeCulto para tocar $funcao.',
    );
  }

  // 2. QUANDO SUGERIREM UM LOUVOR
  static Future<void> notificarMusicaNova(
    List<String> uidsEquipe,
    String nomeMusica,
    String quemSugeriu,
  ) async {
    await _enviar(
      userIds: uidsEquipe, // Manda para todos da escala
      title: '🎵 Nova sugestão de repertório!',
      body: '$quemSugeriu sugeriu "$nomeMusica". Abra o app e confira!',
    );
  }

  // 3. QUANDO ALGUÉM RECUSAR A ESCALA
  static Future<void> notificarRecusa(
    List<String> uidsAdmins,
    String quemRecusou,
    String nomeCulto,
  ) async {
    await _enviar(
      userIds: uidsAdmins, // Manda só para os líderes/admins
      title: '⚠️ Escala Recusada',
      body: '$quemRecusou informou que não poderá participar do $nomeCulto.',
    );
  }

  // 4. QUANDO ALGUÉM ACEITAR A ESCALA
  static Future<void> notificarAceite(
    List<String> uidsAdmins,
    String quemAceitou,
    String nomeCulto,
  ) async {
    await _enviar(
      userIds: uidsAdmins, // Manda só para os líderes/admins
      title: '✅ Presença Confirmada',
      body: '$quemAceitou confirmou presença no $nomeCulto.',
    );
  }

  // O motor interno que faz a comunicação com o Render
  static Future<void> _enviar({
    required List<String> userIds,
    required String title,
    required String body,
  }) async {
    final targetUserIds = userIds
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    if (targetUserIds.isEmpty) {
      debugPrint('Push ignorado: nenhum UID de destino informado.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Push ignorado: usuário não está logado.');
      return;
    }

    try {
      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userIds': targetUserIds,
          'title': title,
          'body': body,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
          'Erro ao enviar push pro Render (${targetUserIds.length} UIDs): '
          'HTTP ${response.statusCode} ${response.body}',
        );
      } else {
        debugPrint(
          'Push enviado para o Render (${targetUserIds.length} UIDs): '
          '${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Erro ao enviar push pro Render: $e');
    }
  }
}
