import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../../domain/song_content_quality.dart';
import '../models/song_model.dart';

/// A device-side fallback for source sites that reject the backend's IP.
/// It accepts only a matching artist/title and a complete lyric-and-chord page.
class DirectChordSource {
  DirectChordSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SongModel?> find({
    required String artist,
    required String track,
    required String id,
  }) async {
    final artistSlug = _slug(artist);
    final titleSlug = _slug(track.split('(').first);
    if (artistSlug.isEmpty || titleSlug.isEmpty) return null;

    final slugs = <String>{titleSlug};
    if (titleSlug.startsWith('medley-')) {
      slugs.add(titleSlug.replaceAll('corinho-', 'corinhos-'));
      slugs.add(titleSlug.replaceAll('corinhos-', 'corinho-'));
    }

    for (final slug in slugs) {
      final uri = Uri.https(
        'www.losacordes.com',
        '/acordes/$artistSlug/$slug/',
      );
      try {
        final response = await _client
            .get(
              uri,
              headers: const {
                'User-Agent': 'Mozilla/5.0 (compatible; CifraBand/1.0)',
                'Accept': 'text/html',
              },
            )
            .timeout(const Duration(seconds: 7));
        if (response.statusCode != 200 ||
            response.bodyBytes.length > 1024 * 1024 ||
            response.request?.url.host != 'www.losacordes.com') {
          continue;
        }
        final song = parsePage(
          latin1.decode(response.bodyBytes),
          artist: artist,
          track: track,
          id: id,
          url: uri.toString(),
        );
        if (song != null) return song;
      } catch (_) {
        // Try the next known title form, then let the regular backend run.
      }
    }
    return null;
  }

  void close() => _client.close();

  static SongModel? parsePage(
    String page, {
    required String artist,
    required String track,
    required String id,
    required String url,
  }) {
    final document = html.parse(page);
    final pageArtist = document.querySelector('#artistname')?.text.trim() ?? '';
    final pageTitle =
        document
            .querySelector('#songtitle')
            ?.text
            .replaceAll(RegExp(r'\s+Acordes\s*$', caseSensitive: false), '')
            .trim() ??
        '';
    final content =
        document.querySelector('pre#core')?.text.replaceAll('\r', '').trim() ??
        '';
    final key = document.querySelector('.actualkey')?.text.trim() ?? '';

    if (_normalize(pageArtist) != _normalize(artist) ||
        !_sameTitle(track, pageTitle) ||
        !SongContentQuality.hasLyrics(content) ||
        (track.toLowerCase().contains('medley') &&
            (content.length < 500 || !_hasMedleyCoverage(track, content)))) {
      return null;
    }

    return SongModel(
      id: id,
      title: pageTitle,
      artist: pageArtist,
      originalKey: RegExp(r'^[A-G](?:#|b)?m?$').hasMatch(key) ? key : '',
      content: content,
      url: url,
    );
  }

  static bool _sameTitle(String requested, String found) {
    final a = _normalize(requested.split('(').first);
    final b = _normalize(found);
    if (a == b) return true;
    final aWords = a.split(' ').where((word) => word.isNotEmpty).toList();
    final bWords = b.split(' ').where((word) => word.isNotEmpty).toList();
    if (aWords.length < 2 || aWords.length != bWords.length) return false;
    var differences = 0;
    for (var i = 0; i < aWords.length; i++) {
      if (aWords[i] == bWords[i]) continue;
      final singularA = aWords[i].length >= 6 && aWords[i].endsWith('s')
          ? aWords[i].substring(0, aWords[i].length - 1)
          : aWords[i];
      final singularB = bWords[i].length >= 6 && bWords[i].endsWith('s')
          ? bWords[i].substring(0, bWords[i].length - 1)
          : bWords[i];
      if (singularA != singularB || ++differences > 1) return false;
    }
    return differences == 1;
  }

  static bool _hasMedleyCoverage(String track, String content) {
    final details = RegExp(r'\(([^)]*)').firstMatch(track)?.group(1);
    if (details == null || !details.contains('/')) return true;
    final contentWords = _normalize(content).split(' ');
    for (final part in details.split('/')) {
      final words = _normalize(
        part,
      ).split(' ').where((word) => word.length >= 3).toList();
      if (words.isEmpty) continue;
      if (!words.every(
        (word) => contentWords.any(
          (candidate) =>
              candidate == word ||
              (word.length >= 5 && candidate.startsWith(word)) ||
              (word.length >= 6 &&
                  word.endsWith('s') &&
                  candidate == word.substring(0, word.length - 1)),
        ),
      )) {
        return false;
      }
    }
    return true;
  }

  static String _slug(String text) => _normalize(text).replaceAll(' ', '-');

  static String _normalize(String text) {
    const from = 'áàãâäçéèêëíìîïóòõôöúùûüýÿ';
    const to = 'aaaaaceeeeiiiiooooouuuuyy';
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final index = from.indexOf(char);
      buffer.write(index >= 0 ? to[index] : char);
    }
    return buffer
        .toString()
        .replaceAll('&', ' e ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
