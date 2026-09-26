import 'song_content_quality.dart';

class SongListening {
  static const hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'open.spotify.com',
    'spotify.link',
    'deezer.com',
    'www.deezer.com',
    'link.deezer.com',
    'music.apple.com',
    'soundcloud.com',
    'www.soundcloud.com',
    'on.soundcloud.com',
  };

  static Uri? reference(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        !hosts.contains(uri.host) ||
        uri.path.isEmpty ||
        uri.path == '/') {
      return null;
    }
    return uri;
  }

  static bool hasChord(Map song) =>
      SongContentQuality.hasLyrics(song['content']?.toString() ?? '');

  static Uri? platformLink(String platform, String value) {
    final uri = reference(value);
    if (uri == null) return null;
    if (platform == 'spotify' &&
        uri.host == 'open.spotify.com' &&
        RegExp(r'^/track/[A-Za-z0-9]{22}$').hasMatch(uri.path))
      return uri;
    if (platform == 'youtube' &&
        uri.host == 'www.youtube.com' &&
        uri.path == '/watch' &&
        RegExp(r'^[\w-]{11}$').hasMatch(uri.queryParameters['v'] ?? ''))
      return uri;
    return null;
  }

  static Map<String, Uri> options(Map song) {
    final query = '${song['title'] ?? ''} ${song['artist'] ?? ''}'.trim();
    final exact = reference(song['referenceUrl']?.toString() ?? '');
    return {
      'Abrir link enviado': ?exact,
      'Buscar no YouTube': Uri.https('www.youtube.com', '/results', {
        'search_query': query,
      }),
      'Buscar no Spotify': Uri(
        scheme: 'https',
        host: 'open.spotify.com',
        pathSegments: ['search', query],
      ),
      'Buscar no Deezer': Uri(
        scheme: 'https',
        host: 'www.deezer.com',
        pathSegments: ['search', query],
      ),
    };
  }
}
