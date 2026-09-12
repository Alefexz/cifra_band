import 'package:fuzzy/fuzzy.dart';

class MusicSearchRanking {
  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[áàãâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòõôö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp("['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\bminha? alma\b'), 'minhalma')
      .replaceAll(RegExp(r'\bpor que\b'), 'porque')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const _stopWords = {
    'a',
    'o',
    'as',
    'os',
    'de',
    'da',
    'do',
    'das',
    'dos',
    'e',
    'em',
    'no',
    'na',
    'para',
    'pra',
    'hino',
    'hc',
  };

  static List<String> _words(String text) => normalize(text)
      .split(' ')
      .where((word) => word.isNotEmpty && !_stopWords.contains(word))
      .toList();

  static String displayTitle(String title) => title
      .replaceAll(
        RegExp(
          r'\s*[\[(](ao vivo|live|remaster(?:ed)?(?: \d+)?)[\])]',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  // Metadata only, verified against the source. This is not a lyrics index.
  static const verifiedHymns = <Map<String, dynamic>>[
    {
      'trackName': 'Porque Ele Vive - 545',
      'artistName': 'Harpa Cristã',
      'searchTrackName': 'Porque Ele Vive',
      'searchAliases': 'Deus enviou',
      'hymnNumber': '545',
      'sourceUrl': 'https://www.cifraclub.com.br/harpa-crista/porque-ele-vive/',
    },
  ];

  static String? hymnNumber(String query) {
    final normalized = normalize(query);
    final numbers = RegExp(r'\b\d+\b').allMatches(normalized).toList();
    if (numbers.length != 1) return null;
    final number = numbers.single.group(0)!;
    final context = RegExp(r'\b(harpa|hino|hc)\b').hasMatch(normalized);
    return context || number.length >= 3 ? number : null;
  }

  static bool artistMatches(String query, String artist) {
    final q = normalize(query);
    final a = normalize(artist);
    return a.isNotEmpty && (q == a || q.startsWith('$a ') || q.endsWith(' $a'));
  }

  static String providerQuery(String query) {
    final ranked = rank(query, verifiedHymns);
    if (ranked.isNotEmpty && hymnNumber(query) != null) {
      return '${ranked.first['searchTrackName']} Harpa Crista ${hymnNumber(query)}';
    }
    if (RegExp(r'^\d{3,}$').hasMatch(query.trim())) {
      return 'Harpa Crista ${query.trim()}';
    }
    return normalize(query);
  }

  static int score(String query, Map<String, dynamic> song) {
    final title = normalize(displayTitle(song['trackName']?.toString() ?? ''));
    final artist = normalize(song['artistName']?.toString() ?? '');
    if (title.isEmpty || artist.isEmpty) return -1;
    final q = normalize(query);
    if (q.isEmpty) return -1;
    final special = RegExp(r'\b(playback|karaoke|instrumental)\b');
    if (special.hasMatch(title) && !special.hasMatch(q)) return -1;

    final number = hymnNumber(query);
    if (number != null &&
        song['hymnNumber'] != number &&
        !RegExp('\\b$number\\b').hasMatch(title)) {
      return -1;
    }

    final words = _words(q);
    if (song['provider'] == 'global_cache' &&
        song['catalogMatch'] == 'lyrics' &&
        normalize(song['matchedQuery']?.toString() ?? '') == q &&
        words.length >= 3) {
      return 90;
    }
    final haystack = _words('$title $artist ${song['searchAliases'] ?? ''}');
    var matched = 0;
    var typos = 0;
    for (final word in words) {
      if (haystack.contains(word) ||
          (!RegExp(r'^\d+$').hasMatch(word) &&
              word.length >= 4 &&
              haystack.any((w) => w.startsWith(word)))) {
        matched++;
      } else if (word.length >= 4 &&
          word.length <= 32 &&
          !RegExp(r'\d').hasMatch(word)) {
        final candidates = haystack
            .where((w) => (w.length - word.length).abs() <= 1)
            .toList();
        final fuzzy = Fuzzy(
          candidates,
          options: FuzzyOptions(threshold: 1 / word.length + 0.01, distance: 0),
        );
        if (fuzzy.search(word).isNotEmpty) {
          matched++;
          typos++;
        }
      }
    }
    if (words.isEmpty ||
        matched != words.length ||
        typos > (words.length >= 4 ? 2 : 1)) {
      return -1;
    }
    if (typos > 0) return 50 - typos;

    var titleQuery = q;
    if (q.startsWith('$artist ')) {
      titleQuery = q.substring(artist.length).trim();
    }
    if (q.endsWith(' $artist')) {
      titleQuery = q.substring(0, q.length - artist.length).trim();
    }
    var result = 100;
    if (title == titleQuery) result += 1000;
    if (title.startsWith('$titleQuery ')) result += 700;
    if (title.contains(titleQuery)) result += 400;
    if (artist == q) result += 600;
    if (artistMatches(query, artist)) result += 2000;
    result += _words(title).where(words.contains).length * 25;
    if (number != null && song['hymnNumber'] == number) result += 1500;
    return result;
  }

  static List<Map<String, dynamic>> rank(
    String query,
    Iterable<Map<String, dynamic>> candidates,
  ) {
    final scored = <({Map<String, dynamic> song, int score, int index})>[];
    var index = 0;
    for (final song in candidates) {
      final value = score(query, song);
      if (value >= 0) {
        scored.add((
          song: {
            ...song,
            'cleanTrackName': displayTitle(song['trackName']?.toString() ?? ''),
            'approximateMatch': value < 90,
          },
          score: value,
          index: index,
        ));
      }
      index++;
    }
    scored.sort(
      (a, b) => a.score == b.score
          ? a.index.compareTo(b.index)
          : b.score.compareTo(a.score),
    );
    final unique = <String, Map<String, dynamic>>{};
    for (final entry in scored) {
      final key =
          '${normalize(entry.song['artistName'].toString())}|'
          '${normalize(entry.song['cleanTrackName'].toString())}';
      final winner = unique[key];
      if (winner == null) {
        unique[key] = entry.song;
      } else {
        for (final field in ['artistId', 'artworkUrl100', 'artistArtwork']) {
          winner[field] ??= entry.song[field];
        }
      }
    }
    return unique.values.toList();
  }
}
