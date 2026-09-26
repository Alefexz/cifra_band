import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/member_actions_service.dart';
import '../../data/models/song_model.dart';
import '../../domain/entities/song_entity.dart';
import '../../domain/song_listening.dart';
import '../providers/song_providers.dart';

Future<void> showSongListening(
  BuildContext context,
  Map song, {
  required String scheduleId,
}) {
  final repository = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(songRepositoryProvider);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SongListeningSheet(
      song: song,
      loadChord: () async {
        if (SongListening.hasChord(song)) {
          return SongModel.fromMap({
            ...Map<String, dynamic>.from(song),
            'originalKey': song['originalKey'] ?? song['key'] ?? '',
          }, song['id']?.toString() ?? '${song['title']}_${song['artist']}');
        }
        return repository.extractSongFromUrl(
          Uri.https('cifraband-api.onrender.com', '/searchSong', {
            'artist': '${song['artist']}',
            'track': '${song['title']}',
          }).toString(),
        );
      },
      loadLink: (platform) => MemberActionsService.send('song-links', {
        'scheduleId': scheduleId,
        'title': song['title'],
        'artist': song['artist'],
        'platform': platform,
      }),
      openChord: (chord) {
        Navigator.pop(context);
        context.push('/cifra', extra: chord);
      },
    ),
  );
}

class SongListeningSheet extends StatefulWidget {
  const SongListeningSheet({
    super.key,
    required this.song,
    required this.loadChord,
    required this.loadLink,
    required this.openChord,
    this.openLink,
  });
  final Map song;
  final Future<SongEntity> Function() loadChord;
  final Future<Map<String, dynamic>> Function(String) loadLink;
  final void Function(SongEntity) openChord;
  final Future<bool> Function(Uri)? openLink;
  @override
  State<SongListeningSheet> createState() => _SongListeningSheetState();
}

class _SongListeningSheetState extends State<SongListeningSheet> {
  final _busy = <String>{};
  final _results = <String, Map<String, dynamic>>{};
  SongEntity? _chord;
  @override
  void initState() {
    super.initState();
    for (final key in ['cifra', 'youtube', 'spotify']) {
      _load(key);
    }
  }

  Future<void> _load(String key) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      Map<String, dynamic> result;
      if (key == 'cifra') {
        final chord = await widget.loadChord().timeout(
          const Duration(seconds: 35),
        );
        if (!SongListening.hasChord({'content': chord.content})) {
          throw StateError('incomplete_chord');
        }
        _chord = chord;
        result = {'status': 'found'};
      } else {
        result = await widget
            .loadLink(key)
            .timeout(const Duration(seconds: 30));
        if (result['status'] == 'found' &&
            SongListening.platformLink(key, '${result['url']}') == null) {
          throw StateError('invalid_media_link');
        }
      }
      if (mounted) setState(() => _results[key] = result);
    } catch (_) {
      if (mounted) setState(() => _results[key] = {'status': 'unavailable'});
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _open(String key) async {
    if (key == 'cifra') {
      widget.openChord(_chord!);
      return;
    }
    final uri = SongListening.platformLink(key, '${_results[key]?['url']}');
    if (uri == null) return;
    try {
      final opened =
          await (widget.openLink?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened) return;
    } catch (_) {
      /* Keep the panel available for retry. */
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir. Tente novamente.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.song['title']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${widget.song['artist']}'),
          const SizedBox(height: 16),
          for (final entry in {
            'cifra': 'Cifra',
            'youtube': 'YouTube',
            'spotify': 'Spotify',
          }.entries)
            ListTile(
              leading: Icon(
                entry.key == 'cifra'
                    ? Icons.library_music_outlined
                    : Icons.play_circle_outline,
              ),
              title: Text(entry.value),
              subtitle: Text(
                _busy.contains(entry.key)
                    ? 'Buscando...'
                    : _results[entry.key]?['status'] == 'found'
                    ? (_results[entry.key]?['title']?.toString() ??
                          'Disponível')
                    : _results[entry.key]?['status'] == 'configuration_required'
                    ? 'Serviço ainda não configurado'
                    : 'Referência não confirmada',
              ),
              trailing: _busy.contains(entry.key)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _results[entry.key]?['status'] == 'found'
                  ? const Icon(Icons.open_in_new)
                  : IconButton(
                      tooltip: 'Tentar novamente: ${entry.value}',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _load(entry.key),
                    ),
              onTap:
                  !_busy.contains(entry.key) &&
                      _results[entry.key]?['status'] == 'found'
                  ? () => _open(entry.key)
                  : null,
            ),
        ],
      ),
    ),
  );
}
