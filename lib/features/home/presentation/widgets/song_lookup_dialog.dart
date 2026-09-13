import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cifra_band/features/songs/data/datasources/song_scraper_datasource.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';

class SongLookupOutcome {
  const SongLookupOutcome({this.song, this.reportMessage});
  final SongEntity? song;
  final String? reportMessage;
}

class SongLookupDialog extends StatefulWidget {
  const SongLookupDialog({
    super.key,
    required this.title,
    required this.artist,
    required this.loadSong,
    this.coverUrl = '',
    this.slowAfter = const Duration(seconds: 6),
    this.deadline = const Duration(seconds: 90),
  });

  final String title;
  final String artist;
  final String coverUrl;
  final Future<SongEntity> Function() loadSong;
  final Duration slowAfter;
  final Duration deadline;

  @override
  State<SongLookupDialog> createState() => _SongLookupDialogState();
}

class _SongLookupDialogState extends State<SongLookupDialog> {
  Timer? _slowTimer;
  Timer? _completionTimer;
  String? _error;
  bool _slow = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attempt = ++_attempt;
    _slowTimer?.cancel();
    setState(() {
      _error = null;
      _slow = false;
    });
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted && attempt == _attempt) setState(() => _slow = true);
    });
    try {
      final song = await Future.sync(widget.loadSong).timeout(widget.deadline);
      if (!mounted || attempt != _attempt) return;
      _slowTimer?.cancel();
      _finish(SongLookupOutcome(song: song));
    } catch (error) {
      if (!mounted || attempt != _attempt) return;
      _slowTimer?.cancel();
      setState(() {
        _error = error is SongSearchException
            ? error.message
            : error is TimeoutException
            ? 'A busca demorou mais que o esperado. Confira sua conexão e tente novamente.'
            : 'Não foi possível abrir esta cifra agora. Tente novamente em instantes.';
      });
    }
  }

  void _finish(SongLookupOutcome outcome) {
    if (!mounted) return;
    // Never pop another dialog, especially a mandatory update above this one.
    if (ModalRoute.of(context)?.isCurrent != true) {
      _completionTimer?.cancel();
      _completionTimer = Timer(
        const Duration(milliseconds: 200),
        () => _finish(outcome),
      );
      return;
    }
    Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    _attempt++;
    _slowTimer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _error == null ? colors.primary : colors.error;
    final loading = _error == null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.onSurface.withValues(alpha: 0.12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loading ? 'Buscando cifra' : 'Não foi possível abrir',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: loading ? 'Cancelar busca' : 'Fechar aviso',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: widget.coverUrl.isEmpty
                          ? _artworkFallback(colors)
                          : Image.network(
                              widget.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _artworkFallback(colors),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.artist,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: loading
                      ? CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 3,
                          semanticsLabel: 'Buscando letra e acordes',
                        )
                      : Icon(Icons.error_outline, color: accent, size: 40),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error ??
                      (_slow
                          ? 'A busca está levando mais tempo. Você pode aguardar ou cancelar.'
                          : 'Consultando letra e acordes…'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (loading)
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      _finish(SongLookupOutcome(reportMessage: _error)),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Reportar problema'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _artworkFallback(ColorScheme colors) => ColoredBox(
    color: colors.primary.withValues(alpha: 0.12),
    child: Icon(Icons.music_note, color: colors.primary),
  );
}
