// lib/features/songs/data/datasources/song_scraper_datasource.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/services/app_diagnostics_service.dart';
import '../../domain/transposer_engine.dart';
import '../../domain/song_content_quality.dart';
import '../models/song_model.dart';

class SongSearchException implements Exception {
  const SongSearchException({
    required this.message,
    this.code,
    this.reason,
    this.statusCode,
    this.diagnostics,
  });

  final String message;
  final String? code;
  final String? reason;
  final int? statusCode;
  final Map<String, dynamic>? diagnostics;

  @override
  String toString() => message;
}

class SongScraperDatasource {
  static const Duration _timeout = Duration(seconds: 45);

  // Mesma ideia de normalização usada no backend (tirar acento antes de
  // montar a chave) — sem isso, cliente e servidor podem gerar chaves
  // diferentes pra mesma música, e o cache deixa de bater com o backend.
  static String _removeAccents(String value) {
    const from = 'áàãâäåæçéèêëíìîïñóòõôöúùûüýÿÁÀÃÂÄÅÆÇÉÈÊËÍÌÎÏÑÓÒÕÔÖÚÙÛÜÝŸ';
    const to = 'aaaaaaaceeeeiiiinooooouuuuyyAAAAAAACEEEEIIIINOOOOOUUUUYY';
    String result = value;
    for (int i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  static String _buildDocId(String artist, String track) {
    final normalized = _removeAccents('${artist}_$track').toLowerCase();
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<SongModel> extractSongFromUrl(String apiUrl) async {
    debugPrint('');
    debugPrint('════════════════════════════════════════');
    debugPrint('🎸 [CIFRA BAND] INICIANDO BUSCA');
    debugPrint('════════════════════════════════════════');
    debugPrint('🌐 URL Recebida: $apiUrl');

    final uri = Uri.parse(apiUrl.replaceAll('+', '%20'));
    final artist = uri.queryParameters['artist'] ?? '';
    final track = uri.queryParameters['track'] ?? '';
    final docId = _buildDocId(artist, track);
    final docRef = FirebaseFirestore.instance
        .collection('global_cifras')
        .doc(docId);

    // ============================================================
    // 1. CACHE GLOBAL NO FIRESTORE
    // ============================================================
    // Uma falha aqui (rede, permissão) não pode travar a busca — só
    // loga e segue como se fosse cache miss.
    try {
      debugPrint('🔍 Verificando cache global: $docId');
      final snapshot = await docRef.get().timeout(const Duration(seconds: 5));

      if (snapshot.exists) {
        debugPrint('⚡ Encontrada no cache global — resposta instantânea.');
        _wakeRenderInBackground(apiUrl);
        final data = snapshot.data()!;
        final originalKey = _normalizeKey(_clean(data['originalKey']));
        final shapeKey = _normalizeKey(_clean(data['shapeKey']));
        final capo = _normalizeCapo(_clean(data['capo']));
        final content = _clean(data['content']);
        SongContentQuality.requireLyrics(content);
        final resolvedShapeKey = TransposerEngine.resolveShapeKey(
          originalKey: originalKey,
          shapeKey: shapeKey,
          capo: capo,
          content: content,
        );
        final resolvedOriginalKey = TransposerEngine.resolveDisplayedKey(
          originalKey: originalKey,
          shapeKey: resolvedShapeKey,
          capo: capo,
          content: content,
        );
        return SongModel(
          id: data['id'] ?? docId,
          title: data['title'] ?? track,
          artist: data['artist'] ?? artist,
          originalKey: resolvedOriginalKey,
          shapeKey: resolvedShapeKey.isEmpty ? null : resolvedShapeKey,
          capo: capo.isEmpty ? null : capo,
          referenceUrl: _clean(data['referenceUrl']).isEmpty
              ? null
              : _clean(data['referenceUrl']),
          content: content,
          url: data['url'] ?? '',
        );
      }
      debugPrint('ℹ️ Não estava no cache global.');
      AppDiagnosticsService.log(
        'Cifra nao encontrada no cache global',
        context: {'artist': artist, 'track': track, 'cacheId': docId},
      );
    } catch (e) {
      debugPrint('⚠️ Falha ao consultar cache global (seguindo sem ele): $e');
      AppDiagnosticsService.log(
        'Falha ao consultar cache global',
        level: 'warning',
        error: e,
        context: {'artist': artist, 'track': track, 'cacheId': docId},
      );
    }

    // ============================================================
    // 2. BUSCA NO SERVIDOR RENDER
    // ============================================================
    debugPrint('🌐 Buscando no servidor...');
    final SongModel song;
    try {
      final response = await http
          .get(uri, headers: await _authHeaders())
          .timeout(_timeout);
      debugPrint('📊 HTTP STATUS: ${response.statusCode}');

      if (response.statusCode != 200) {
        final searchError = _parseSearchError(
          response,
          artist: artist,
          track: track,
        );
        AppDiagnosticsService.log(
          'Busca de cifra falhou no backend',
          level: response.statusCode == 404 ? 'warning' : 'error',
          context: {
            'artist': artist,
            'track': track,
            'statusCode': response.statusCode,
            'code': searchError.code,
            'reason': searchError.reason,
            'diagnostics': searchError.diagnostics,
          },
        );
        throw searchError;
      }

      final dynamic decoded = json.decode(response.body);

      final String title = _clean(decoded['title']);
      final String artistName = _clean(decoded['artist']);
      final String originalKey = _normalizeKey(_clean(decoded['originalKey']));
      final String shapeKey = _normalizeKey(_clean(decoded['shapeKey']));
      final String capo = _normalizeCapo(_clean(decoded['capo']));
      final String content = _clean(decoded['content']);
      SongContentQuality.requireLyrics(content);
      final String url = _clean(decoded['url']);
      final String referenceUrl = _clean(decoded['referenceUrl']);
      final String resolvedShapeKey = TransposerEngine.resolveShapeKey(
        originalKey: originalKey,
        shapeKey: shapeKey,
        capo: capo,
        content: content,
      );
      final String resolvedOriginalKey = TransposerEngine.resolveDisplayedKey(
        originalKey: originalKey,
        shapeKey: resolvedShapeKey,
        capo: capo,
        content: content,
      );

      song = SongModel(
        id: docId,
        title: title.isEmpty ? 'Desconhecido' : title,
        artist: artistName.isEmpty ? 'Desconhecido' : artistName,
        originalKey: resolvedOriginalKey,
        shapeKey: resolvedShapeKey.isEmpty ? null : resolvedShapeKey,
        capo: capo.isEmpty ? null : capo,
        referenceUrl: referenceUrl.isEmpty ? null : referenceUrl,
        content: content,
        url: url,
      );
    } catch (e) {
      debugPrint('❌ Erro buscando no servidor: $e');
      if (e is! SongSearchException) {
        AppDiagnosticsService.log(
          'Erro inesperado ao buscar cifra',
          level: 'error',
          error: e,
          context: {'artist': artist, 'track': track},
        );
      }
      rethrow;
    }

    debugPrint('✅ Processo concluído!');
    debugPrint('');

    return song;
  }

  static void _wakeRenderInBackground(String apiUrl) {
    final uri = Uri.parse(apiUrl.replaceAll('+', '%20'));

    unawaited(
      (() async {
        try {
          final response = await http
              .get(uri, headers: await _authHeaders())
              .timeout(const Duration(seconds: 60));
          debugPrint(
            '🌐 Render acordado em segundo plano: HTTP ${response.statusCode}',
          );
        } catch (e) {
          debugPrint('⚠️ Ping em segundo plano para o Render falhou: $e');
        }
      })(),
    );
  }

  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static SongSearchException _parseSearchError(
    http.Response response, {
    required String artist,
    required String track,
  }) {
    Map<String, dynamic> decoded = const <String, dynamic>{};

    try {
      final dynamic body = json.decode(response.body);
      if (body is Map<String, dynamic>) decoded = body;
    } catch (_) {
      decoded = const <String, dynamic>{};
    }

    final message = _clean(decoded['userMessage'] ?? decoded['message']);
    final diagnostics = decoded['diagnostics'] is Map<String, dynamic>
        ? decoded['diagnostics'] as Map<String, dynamic>
        : null;

    return SongSearchException(
      message: message.isEmpty
          ? 'Nao encontrei uma cifra confiavel para "$track" de $artist.'
          : message,
      code: _clean(decoded['error']),
      reason: _clean(decoded['reason']),
      statusCode: response.statusCode,
      diagnostics: diagnostics,
    );
  }

  static String _clean(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _normalizeCapo(String value) {
    if (value.isEmpty) return '';
    String capo = value
        .toLowerCase()
        .replaceAll('ª', '')
        .replaceAll('º', '')
        .replaceAll('casa', '')
        .replaceAll('capotraste', '')
        .trim();
    final match = RegExp(r'\d+').firstMatch(capo);
    if (match != null) return match.group(0)!;
    return capo;
  }

  static String _normalizeKey(String value) {
    if (value.isEmpty) return '';
    String key = value.trim();
    key = key.replaceAll('♯', '#').replaceAll('♭', 'b');
    key = key.replaceFirst(RegExp(r'^tom\s*:\s*', caseSensitive: false), '');
    final match = RegExp(
      r'(?:^|[^A-Za-z])([A-Ga-g])([#b])?(m)?(?=$|[^A-Za-z])',
    ).firstMatch(key);
    if (match == null) return key.trim();

    final root = match.group(1)!.toUpperCase();
    final accidental = match.group(2) ?? '';
    final minor = match.group(3) == null ? '' : 'm';
    var normalized = '$root$accidental';

    if (normalized == 'A#') normalized = 'Bb';
    if (normalized == 'D#') normalized = 'Eb';
    if (normalized == 'G#') normalized = 'Ab';

    return '$normalized$minor';
  }
}
