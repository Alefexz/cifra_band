// lib/features/songs/presentation/screens/cifra_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cifra_band/core/services/chord_study_service.dart';
import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cifra_band/core/services/played_history_service.dart';
import 'package:cifra_band/core/services/song_annotation_service.dart';
import '../../data/models/song_model.dart';
import '../../domain/transposer_engine.dart';

class CifraScreen extends StatefulWidget {
  final SongModel song;
  final bool embedded;
  final bool recordHistory;
  final bool allowHorizontalCifraScroll;

  const CifraScreen({
    super.key,
    required this.song,
    this.embedded = false,
    this.recordHistory = true,
    this.allowHorizontalCifraScroll = true,
  });

  @override
  State<CifraScreen> createState() => _CifraScreenState();
}

class _CifraScreenState extends State<CifraScreen> {
  late String _originalPitch;
  late String _shapePitch;
  late String _currentPitch;
  late bool _minorToneMode;
  bool _isCapoActive = false;
  bool _isFavorite = false;
  bool _isSimplified = false;
  bool _isStageMode = false;

  String get _safeCapo => widget.song.capo ?? '';
  String get _safeShapeKey => widget.song.shapeKey ?? '';
  String get _safeOriginalKey =>
      widget.song.originalKey.isEmpty ? 'C' : widget.song.originalKey;
  String get _safeContent => widget.song.content;

  double _fontSize = 16.0;
  bool _showChords = true;
  bool _showTabs = true;

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  Timer? _guidedSyncTimer;
  bool _isPlaying = false;
  double _scrollSpeed = 1.0;
  YoutubePlayerController? _youtubeController;
  bool _isGuidedMode = false;
  bool _guidedAutoScroll = true;
  int _activeSectionIndex = 0;

  Color get _pageBackground =>
      _isStageMode ? const Color(0xFF0D0D12) : const Color(0xFFF7F9FC);
  Color get _surfaceColor =>
      _isStageMode ? const Color(0xFF1A1A24) : Colors.white;
  Color get _modalSurfaceColor =>
      _isStageMode ? const Color(0xFF16161E) : Colors.white;
  Color get _controlColor =>
      _isStageMode ? const Color(0xFF2C2C2E) : const Color(0xFFF0F4FA);
  Color get _primaryText =>
      _isStageMode ? Colors.white : const Color(0xFF101828);
  Color get _secondaryText =>
      _isStageMode ? Colors.grey.shade500 : const Color(0xFF667085);
  Color get _bodyText =>
      _isStageMode ? Colors.white.withOpacity(0.92) : const Color(0xFF1F2937);
  Color get _mutedText =>
      _isStageMode ? Colors.grey.shade500 : const Color(0xFF6B7280);
  Color get _dividerColor =>
      _isStageMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E7EB);
  Color get _headerBackground => _isStageMode
      ? Colors.blueAccent.withOpacity(0.08)
      : const Color(0xFFEAF2FF);

  @override
  void initState() {
    super.initState();
    _isCapoActive = _safeCapo.isNotEmpty && _safeCapo != '0';
    _shapePitch = TransposerEngine.resolveShapeKey(
      originalKey: _safeOriginalKey,
      shapeKey: _safeShapeKey,
      capo: _safeCapo,
      content: _safeContent,
    );
    _originalPitch = TransposerEngine.resolveDisplayedKey(
      originalKey: _safeOriginalKey,
      shapeKey: _shapePitch.isEmpty ? _safeShapeKey : _shapePitch,
      capo: _safeCapo,
      content: _safeContent,
    );
    _currentPitch = _originalPitch;
    _minorToneMode =
        TransposerEngine.isMinorKey(_originalPitch) ||
        TransposerEngine.isMinorKey(_shapePitch);

    WakelockPlus.enable();
    _loadCifraDisplayMode();
    _checkIfFavorite();
    if (widget.recordHistory) {
      unawaited(PlayedHistoryService.recordSong(widget.song));
    }
  }

  Future<void> _loadCifraDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('cifra_stage_mode');
    if (!mounted) return;
    setState(() => _isStageMode = saved ?? widget.embedded);
  }

  Future<void> _toggleStageMode() async {
    setState(() => _isStageMode = !_isStageMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cifra_stage_mode', _isStageMode);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _guidedSyncTimer?.cancel();
    _youtubeController?.close();
    _scrollController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _checkIfFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteList = prefs.getStringList('favorite_songs') ?? [];
    setState(() {
      _isFavorite = favoriteList.any((songJson) {
        final decoded = json.decode(songJson);
        return decoded['id'] == widget.song.id;
      });
    });
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteList = prefs.getStringList('favorite_songs') ?? [];

    final currentSongMap = {
      'id': widget.song.id,
      'title': widget.song.title,
      'artist': widget.song.artist,
      'originalKey': widget.song.originalKey,
      'content': widget.song.content,
      'capo': widget.song.capo,
      'shapeKey': widget.song.shapeKey,
      'referenceUrl': widget.song.referenceUrl,
      'rehearsalNotes': widget.song.rehearsalNotes,
      'bpm': widget.song.bpm,
      'url': widget.song.url,
    };
    final currentSongJson = json.encode(currentSongMap);

    if (_isFavorite) {
      favoriteList.removeWhere((songJson) {
        final decoded = json.decode(songJson);
        return decoded['id'] == widget.song.id;
      });
      setState(() => _isFavorite = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removida dos favoritos offline.'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } else {
      favoriteList.add(currentSongJson);
      setState(() => _isFavorite = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salva offline! Acesse em "Cifras Favoritas".'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    await prefs.setStringList('favorite_songs', favoriteList);
  }

  void _toggleAutoScroll() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_scrollController.hasClients) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          double currentScroll = _scrollController.position.pixels;
          double jump = 1.5 * _scrollSpeed;
          if (currentScroll < maxScroll) {
            _scrollController.jumpTo(currentScroll + jump);
          } else {
            _toggleAutoScroll();
          }
        }
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  void _changeSpeed() {
    setState(() {
      if (_scrollSpeed == 1.0)
        _scrollSpeed = 1.5;
      else if (_scrollSpeed == 1.5)
        _scrollSpeed = 2.0;
      else
        _scrollSpeed = 1.0;
    });
  }

  // ==========================================================
  // LÓGICA DE TRANSPOSIÇÃO
  // ==========================================================
  String get _currentShape {
    if (_shapePitch.isEmpty) return _currentPitch;
    int diff = TransposerEngine.getSemitonesDifference(
      _originalPitch,
      _currentPitch,
    );
    if (diff == 0) return _shapePitch;
    return TransposerEngine.transposeKey(_shapePitch, diff);
  }

  String get _displayedContent {
    String baseContent = _safeContent;
    String baseShape = _shapePitch.isNotEmpty ? _shapePitch : _originalPitch;
    String content;

    if (!_isCapoActive || _safeCapo.isEmpty || _safeCapo == '0') {
      if (baseShape == _currentPitch) {
        content = baseContent;
      } else {
        content = TransposerEngine.transposeSong(
          content: baseContent,
          originalKey: baseShape,
          shapeKey: baseShape,
          capo: '',
          targetKey: _currentPitch,
        );
      }
      return _isSimplified ? TransposerEngine.simplifyCifra(content) : content;
    }

    final currentShape = _currentShape;
    if (baseShape == currentShape) {
      content = baseContent;
    } else {
      content = TransposerEngine.transposeSong(
        content: baseContent,
        originalKey: baseShape,
        shapeKey: baseShape,
        capo: '',
        targetKey: currentShape,
      );
    }
    return _isSimplified ? TransposerEngine.simplifyCifra(content) : content;
  }

  void _toneUp() => _changeToneTo(_getShiftedPitch(1));
  void _toneDown() => _changeToneTo(_getShiftedPitch(-1));

  List<String> _toneOptionsForCurrentMode() {
    return _minorToneMode
        ? TransposerEngine.minorToneOptions
        : TransposerEngine.majorToneOptions;
  }

  String _canonicalPitchForUi(String pitch) {
    final options = _toneOptionsForCurrentMode();

    for (final option in options) {
      if (TransposerEngine.getSemitonesDifference(option, pitch) == 0 &&
          TransposerEngine.isMinorKey(option) ==
              TransposerEngine.isMinorKey(pitch)) {
        return option;
      }
    }
    return pitch;
  }

  String _getShiftedPitch(int diff) {
    final options = _toneOptionsForCurrentMode();
    int idx = options.indexWhere(
      (tone) =>
          TransposerEngine.getSemitonesDifference(tone, _currentPitch) == 0 &&
          TransposerEngine.isMinorKey(tone) ==
              TransposerEngine.isMinorKey(_currentPitch),
    );
    if (idx == -1) idx = 0;
    int newIdx = (idx + diff) % 12;
    if (newIdx < 0) newIdx += 12;
    return options[newIdx];
  }

  void _changeToneTo(String targetPitch) {
    if (targetPitch.isEmpty) return;
    if (targetPitch == _currentPitch) return;
    setState(() => _currentPitch = targetPitch);
  }

  Future<void> _openReferenceUrl() async {
    final value = widget.song.referenceUrl?.trim() ?? '';
    if (value.isEmpty) return;

    final uri = Uri.tryParse(
      value.startsWith('http://') || value.startsWith('https://')
          ? value
          : 'https://$value',
    );

    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir a referência.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? get _youtubeVideoId {
    final value = widget.song.referenceUrl?.trim() ?? '';
    if (value.isEmpty) return null;
    return YoutubePlayerController.convertUrlToId(value);
  }

  bool get _hasYoutubeReference => _youtubeVideoId != null;

  List<_CifraSection> get _cifraSections {
    final sections = <_CifraSection>[];
    final lines = _displayedContent.split('\n');

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (!TransposerEngine.isHeaderLine(line)) continue;
      final cleanTitle = line
          .replaceAll('[', '')
          .replaceAll(']', '')
          .trim()
          .toUpperCase();
      sections.add(
        _CifraSection(
          title: cleanTitle.isEmpty
              ? 'TRECHO ${sections.length + 1}'
              : cleanTitle,
          lineIndex: index,
        ),
      );
    }

    if (sections.isNotEmpty) return sections;

    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).length;
    final estimatedSections = nonEmptyLines <= 24
        ? 2
        : nonEmptyLines <= 56
        ? 4
        : 6;

    return List.generate(
      estimatedSections,
      (index) => _CifraSection(title: 'TRECHO ${index + 1}', lineIndex: index),
    );
  }

  Future<void> _toggleGuidedMode() async {
    if (_isGuidedMode) {
      _disableGuidedMode();
      return;
    }
    await _enableGuidedMode();
  }

  Future<void> _enableGuidedMode() async {
    final videoId = _youtubeVideoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa cifra ainda não tem um link do YouTube salvo.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _guidedSyncTimer?.cancel();
    await _youtubeController?.close();
    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        interfaceLanguage: 'pt',
      ),
    );

    if (!mounted) {
      await controller.close();
      return;
    }

    setState(() {
      _youtubeController = controller;
      _isGuidedMode = true;
      _activeSectionIndex = 0;
    });
    _startGuidedSync();
  }

  void _disableGuidedMode() {
    _guidedSyncTimer?.cancel();
    _guidedSyncTimer = null;
    final controller = _youtubeController;
    _youtubeController = null;
    unawaited(controller?.close());
    if (!mounted) return;
    setState(() {
      _isGuidedMode = false;
      _activeSectionIndex = 0;
    });
  }

  void _startGuidedSync() {
    _guidedSyncTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) => unawaited(_syncGuidedScroll()),
    );
  }

  Future<void> _syncGuidedScroll() async {
    final controller = _youtubeController;
    if (!_isGuidedMode || controller == null || !_scrollController.hasClients) {
      return;
    }

    try {
      final duration = await controller.duration;
      final currentTime = await controller.currentTime;
      final sections = _cifraSections;
      if (!mounted || duration <= 0 || sections.isEmpty) return;

      final progress = (currentTime / duration).clamp(0.0, 1.0);
      final nextIndex = (progress * sections.length).floor().clamp(
        0,
        sections.length - 1,
      );

      if (nextIndex != _activeSectionIndex) {
        setState(() => _activeSectionIndex = nextIndex);
        if (_guidedAutoScroll) {
          _scrollToSectionIndex(nextIndex, sections.length);
        }
      }
    } catch (_) {
      // O WebView pode demorar alguns segundos para liberar duração/posição.
    }
  }

  Future<void> _jumpToGuidedSection(int index) async {
    final sections = _cifraSections;
    if (sections.isEmpty) return;
    final safeIndex = index.clamp(0, sections.length - 1);
    final controller = _youtubeController;

    setState(() => _activeSectionIndex = safeIndex);
    _scrollToSectionIndex(safeIndex, sections.length);

    if (controller == null) return;
    try {
      final duration = await controller.duration;
      if (duration <= 0 || sections.length <= 1) return;
      final targetSeconds = duration * (safeIndex / (sections.length - 1));
      await controller.seekTo(seconds: targetSeconds, allowSeekAhead: true);
    } catch (_) {
      // Se o vídeo ainda não estiver pronto, mantém pelo menos a navegação da cifra.
    }
  }

  void _scrollToSectionIndex(int index, int totalSections) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final factor = totalSections <= 1 ? 0.0 : index / (totalSections - 1);
    final target = (position.maxScrollExtent * factor).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildGuidedModePanel() {
    final controller = _youtubeController;
    if (!_isGuidedMode || controller == null) return const SizedBox.shrink();

    final sections = _cifraSections;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isStageMode ? const Color(0xFF131923) : const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.redAccent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  color: Colors.redAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Culto Guiado',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'A cifra acompanha o YouTube por trechos.',
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fechar Culto Guiado',
                onPressed: _disableGuidedMode,
                icon: Icon(Icons.close_rounded, color: _secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: YoutubePlayer(
              controller: controller,
              backgroundColor: Colors.black,
              aspectRatio: 16 / 9,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  sections.isEmpty
                      ? 'Sem marcações nesta cifra'
                      : 'Seção ${_activeSectionIndex + 1} de ${sections.length}',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilterChip(
                selected: _guidedAutoScroll,
                onSelected: (value) =>
                    setState(() => _guidedAutoScroll = value),
                label: const Text('Rolagem inteligente'),
                avatar: const Icon(Icons.auto_mode_rounded, size: 16),
                selectedColor: Colors.greenAccent.withOpacity(0.18),
                backgroundColor: _isStageMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white,
                checkmarkColor: Colors.greenAccent,
                labelStyle: TextStyle(
                  color: _guidedAutoScroll
                      ? Colors.greenAccent
                      : _secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isActive = index == _activeSectionIndex;
                  return ChoiceChip(
                    selected: isActive,
                    onSelected: (_) => unawaited(_jumpToGuidedSection(index)),
                    label: Text(sections[index].title),
                    selectedColor: Colors.redAccent.withOpacity(0.18),
                    backgroundColor: _isStageMode
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.redAccent : _secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isActive
                            ? Colors.redAccent
                            : _dividerColor.withOpacity(0.8),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveOfficialVersion() async {
    try {
      await OfficialLibraryService.saveFromSong(widget.song);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cifra salva como versão oficial da igreja.'),
          backgroundColor: Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não consegui salvar na biblioteca: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _reportWrongChord() {
    final message = StringBuffer()
      ..writeln('Problema nesta cifra:')
      ..writeln('${widget.song.title} - ${widget.song.artist}')
      ..writeln('Tom atual: $_currentPitch')
      ..writeln('Tom original: ${widget.song.originalKey}')
      ..writeln(
        'Fonte: ${widget.song.url.isEmpty ? 'sem URL' : widget.song.url}',
      )
      ..writeln()
      ..write('Descreva onde o acorde/letra está errado: ');

    context.push(
      '/feedback',
      extra: {
        'type': 'wrong_chord',
        'screen': 'Cifra',
        'message': message.toString(),
      },
    );
  }

  Future<void> _showAnnotationSheet() async {
    final controller = TextEditingController(
      text: await SongAnnotationService.load(
        widget.song.title,
        widget.song.artist,
      ),
    );
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _modalSurfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Anotação pessoal',
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 8,
                    style: TextStyle(color: _primaryText, height: 1.35),
                    decoration: InputDecoration(
                      hintText: 'Ex: entrar suave no refrão, pad em D...',
                      hintStyle: TextStyle(color: _secondaryText),
                      filled: true,
                      fillColor: _controlColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await SongAnnotationService.save(
                        widget.song.title,
                        widget.song.artist,
                        controller.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Salvar anotação'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  void _showChordStudySheet() {
    final chords = ChordStudyService.uniqueChords(_displayedContent);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: _modalSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Acordes e graus',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: _secondaryText),
                    ),
                  ],
                ),
                Text(
                  'Tom de referência: $_currentPitch',
                  style: TextStyle(
                    color: _secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                if (chords.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Nenhum acorde reconhecido nesta cifra.',
                        style: TextStyle(color: _secondaryText),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: chords.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final chord = chords[index];
                        final simple = ChordStudyService.simplifiedName(chord);
                        final notes = ChordStudyService.keyboardNotes(simple);
                        final degree = ChordStudyService.degreeForChord(
                          simple,
                          _currentPitch,
                        );
                        final guitar =
                            ChordStudyService.guitarShapes[simple] ??
                            ChordStudyService
                                .guitarShapes[TransposerEngine.normalizeKey(
                              simple,
                            )];

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _controlColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    chord,
                                    style: const TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  _StudyPill('Grau $degree'),
                                  if (simple != chord) ...[
                                    const SizedBox(width: 8),
                                    _StudyPill('Simplifica: $simple'),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                notes.isEmpty
                                    ? 'Teclado: notas não identificadas'
                                    : 'Teclado: ${notes.join(' - ')}',
                                style: TextStyle(
                                  color: _primaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                guitar == null
                                    ? 'Violão: formato ainda não cadastrado'
                                    : 'Violão: E A D G B e = ${guitar.join(' ')}',
                                style: TextStyle(
                                  color: _secondaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // MODAIS (Configurações e Tom)
  // ==========================================================
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _modalSurfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SwitchListTile(
                    title: Text(
                      'Modo Palco',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    subtitle: Text(
                      _isStageMode
                          ? 'Fundo escuro para culto e ensaio.'
                          : 'Modo claro para leitura normal da cifra.',
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _isStageMode,
                    onChanged: (val) async {
                      setState(() => _isStageMode = val);
                      setModalState(() {});
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('cifra_stage_mode', val);
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),

                  if (_safeCapo.isNotEmpty && _safeCapo != '0') ...[
                    SwitchListTile(
                      title: Text(
                        'Usar Capotraste',
                        style: TextStyle(color: _primaryText, fontSize: 16),
                      ),
                      subtitle: Text(
                        'Posição: $_safeCapo',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                        ),
                      ),
                      activeColor: Colors.orangeAccent,
                      contentPadding: EdgeInsets.zero,
                      value: _isCapoActive,
                      onChanged: (val) {
                        setState(() => _isCapoActive = val);
                        setModalState(() {});
                      },
                    ),
                    Divider(color: _dividerColor, height: 16),
                  ],

                  SwitchListTile(
                    title: Text(
                      'Cifra Simplificada',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    subtitle: Text(
                      'Remove extensoes comuns e deixa os acordes mais diretos.',
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                    activeColor: Colors.greenAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _isSimplified,
                    onChanged: (val) {
                      setState(() => _isSimplified = val);
                      setModalState(() {});
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  SwitchListTile(
                    title: Text(
                      'Mostrar Acordes',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _showChords,
                    onChanged: (val) {
                      setState(() => _showChords = val);
                      setModalState(() {});
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  SwitchListTile(
                    title: Text(
                      'Mostrar Tablaturas',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _showTabs,
                    onChanged: (val) {
                      setState(() => _showTabs = val);
                      setModalState(() {});
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.library_add_check_rounded,
                      color: Colors.greenAccent,
                    ),
                    title: Text(
                      'Salvar na Biblioteca Oficial',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    subtitle: Text(
                      'Administra a versão que a igreja vai usar.',
                      style: TextStyle(color: _secondaryText, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _saveOfficialVersion();
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.school_rounded,
                      color: Colors.blueAccent,
                    ),
                    title: Text(
                      'Acordes, teclado e graus',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showChordStudySheet();
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.edit_note_rounded,
                      color: Colors.orangeAccent,
                    ),
                    title: Text(
                      'Anotação pessoal',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showAnnotationSheet();
                    },
                  ),
                  Divider(color: _dividerColor, height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.report_problem_rounded,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      'Reportar problema nesta cifra',
                      style: TextStyle(color: _primaryText, fontSize: 16),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _reportWrongChord();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showToneSelector() {
    final List<String> tones = _toneOptionsForCurrentMode();
    String uiPitch = _canonicalPitchForUi(_currentPitch);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _modalSurfaceColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _toneDown();
                            uiPitch = _canonicalPitchForUi(_currentPitch);
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _controlColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '-1/2 tom',
                                style: TextStyle(
                                  color: _primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _toneUp();
                            uiPitch = _canonicalPitchForUi(_currentPitch);
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _controlColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '+1/2 tom',
                                style: TextStyle(
                                  color: _primaryText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: tones.map((t) {
                      bool isSelected = t == uiPitch;
                      return InkWell(
                        onTap: () {
                          _changeToneTo(t);
                          uiPitch = t;
                          setModalState(() {});
                        },
                        child: Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (_isStageMode
                                      ? Colors.white
                                      : Colors.blueAccent)
                                : _controlColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: isSelected
                                    ? (_isStageMode
                                          ? Colors.black
                                          : Colors.white)
                                    : _secondaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  InkWell(
                    onTap: () {
                      _changeToneTo(_originalPitch);
                      uiPitch = _canonicalPitchForUi(_originalPitch);
                      setModalState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: _dividerColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: _secondaryText,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Restaurar',
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // UI PRINCIPAL
  // ==========================================================
  Widget _buildTopControlBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _dividerColor),
        boxShadow: [
          if (!_isStageMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Row(
        children: [
          Expanded(flex: 10, child: _buildToneControls()),
          _buildControlDivider(),
          Expanded(flex: 9, child: _buildFontControls()),
          _buildControlDivider(),
          Expanded(flex: 8, child: _buildScrollControls()),
          _buildControlDivider(),
          _buildCompactIconButton(
            icon: Icons.settings_rounded,
            onTap: _showSettingsPanel,
          ),
        ],
      ),
    );
  }

  Widget _buildToneControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactIconButton(icon: Icons.remove_rounded, onTap: _toneDown),
        Flexible(
          child: InkWell(
            onTap: _showToneSelector,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tom',
                    maxLines: 1,
                    style: TextStyle(color: _secondaryText, fontSize: 9),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _currentPitch,
                      maxLines: 1,
                      style: TextStyle(
                        color: _primaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildCompactIconButton(icon: Icons.add_rounded, onTap: _toneUp),
      ],
    );
  }

  Widget _buildFontControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactTextButton(
          label: 'T-',
          onTap: () =>
              setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 30.0)),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_fontSize.toInt()}',
              maxLines: 1,
              style: TextStyle(
                color: _primaryText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        _buildCompactTextButton(
          label: 'T+',
          onTap: () =>
              setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 30.0)),
        ),
      ],
    );
  }

  Widget _buildScrollControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildCompactIconButton(
          icon: _isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_fill_rounded,
          color: _isPlaying ? Colors.orangeAccent : _secondaryText,
          size: 27,
          onTap: _toggleAutoScroll,
        ),
        Flexible(
          child: InkWell(
            onTap: _changeSpeed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: _scrollSpeed > 1.0
                    ? Colors.blueAccent.withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_scrollSpeed}x',
                  maxLines: 1,
                  style: TextStyle(
                    color: _scrollSpeed > 1.0
                        ? Colors.blueAccent
                        : _primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
    double size = 21,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 30,
        height: 38,
        child: Icon(icon, color: color ?? _secondaryText, size: size),
      ),
    );
  }

  Widget _buildCompactTextButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 30,
        height: 38,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlDivider() {
    return Container(
      width: 1,
      height: 24,
      color: _dividerColor,
      margin: const EdgeInsets.symmetric(horizontal: 3),
    );
  }

  Widget _buildTitleAndActionsBar() {
    if (widget.embedded) {
      return Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _toggleFavorite,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: _isFavorite ? Colors.redAccent : Colors.blueAccent,
              size: 22,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text(
                  'Voltar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        Row(
          children: [
            InkWell(
              onTap: _saveOfficialVersion,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.library_add_check_rounded,
                  color: Colors.greenAccent,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _reportWrongChord,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.report_problem_outlined,
                  color: Colors.orangeAccent,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _toggleFavorite,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavorite ? Colors.redAccent : Colors.blueAccent,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCifraInfoChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
    bool selected = true,
  }) {
    final foreground = selected ? color : _secondaryText;
    final background = selected
        ? color.withOpacity(0.14)
        : (_isStageMode ? Colors.white.withOpacity(0.06) : Colors.white);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: foreground.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: 15),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = Column(
      children: [
        _buildTopControlBar(),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleAndActionsBar(),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.song.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _primaryText,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.song.artist,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondaryText, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 18),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildCifraInfoChip(
                      label: 'Tom Real: $_currentPitch',
                      color: Colors.blueAccent,
                      onTap: _showToneSelector,
                    ),

                    if (_safeCapo.isNotEmpty && _safeCapo != '0')
                      _buildCifraInfoChip(
                        label: _isCapoActive
                            ? 'Capo $_safeCapo (Forma $_currentShape)'
                            : 'Sem Capo',
                        color: _isCapoActive ? Colors.orange : Colors.grey,
                        icon: _isCapoActive
                            ? Icons.link_rounded
                            : Icons.link_off_rounded,
                        onTap: _showSettingsPanel,
                      ),

                    _buildCifraInfoChip(
                      label: 'Simplificada',
                      color: Colors.greenAccent,
                      icon: _isSimplified
                          ? Icons.check_circle_rounded
                          : Icons.tune_rounded,
                      selected: _isSimplified,
                      onTap: () =>
                          setState(() => _isSimplified = !_isSimplified),
                    ),

                    _buildCifraInfoChip(
                      label: _isStageMode ? 'Modo Palco' : 'Modo Claro',
                      color: _isStageMode
                          ? Colors.deepPurpleAccent
                          : Colors.blueGrey,
                      icon: _isStageMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      onTap: _toggleStageMode,
                    ),
                    if (_hasYoutubeReference)
                      _buildCifraInfoChip(
                        label: _isGuidedMode
                            ? 'Culto Guiado ON'
                            : 'Culto Guiado',
                        color: Colors.redAccent,
                        icon: Icons.smart_display_rounded,
                        selected: _isGuidedMode,
                        onTap: _toggleGuidedMode,
                      ),
                    _buildCifraInfoChip(
                      label: 'Acordes/Graus',
                      color: Colors.orangeAccent,
                      icon: Icons.school_rounded,
                      onTap: _showChordStudySheet,
                    ),
                    _buildCifraInfoChip(
                      label: 'Anotação',
                      color: Colors.purpleAccent,
                      icon: Icons.edit_note_rounded,
                      onTap: _showAnnotationSheet,
                    ),
                  ],
                ),

                _buildGuidedModePanel(),

                if ((widget.song.referenceUrl?.trim().isNotEmpty ?? false) ||
                    (widget.song.bpm?.trim().isNotEmpty ?? false) ||
                    (widget.song.rehearsalNotes?.trim().isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.song.referenceUrl?.trim().isNotEmpty ?? false)
                        ActionChip(
                          avatar: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Referência'),
                          backgroundColor: Colors.blueAccent.withOpacity(0.14),
                          labelStyle: const TextStyle(color: Colors.blueAccent),
                          onPressed: _openReferenceUrl,
                        ),
                      if (widget.song.bpm?.trim().isNotEmpty ?? false)
                        Chip(
                          avatar: const Icon(
                            Icons.speed_rounded,
                            color: Colors.orange,
                          ),
                          label: Text('${widget.song.bpm} BPM'),
                          backgroundColor: Colors.orange.withOpacity(0.12),
                          labelStyle: const TextStyle(color: Colors.orange),
                        ),
                      if (widget.song.rehearsalNotes?.trim().isNotEmpty ??
                          false)
                        Chip(
                          avatar: Icon(
                            Icons.sticky_note_2_outlined,
                            color: _secondaryText,
                          ),
                          label: Text(widget.song.rehearsalNotes!),
                          backgroundColor: _isStageMode
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white,
                          labelStyle: TextStyle(color: _secondaryText),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 30),
                _buildRichCifra(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: _pageBackground, child: page);
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(child: page),
    );
  }

  Widget _buildRichCifra() {
    final lines = _displayedContent.split('\n');
    final widgets = <Widget>[];
    var sectionIndex = 0;

    for (String line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: _fontSize * 0.95));
        continue;
      }
      if (TransposerEngine.isTabLine(line)) {
        if (_showTabs)
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _buildCifraLine(
                line,
                style: TextStyle(
                  color: _mutedText,
                  fontFamily: 'monospace',
                  fontSize: _fontSize - 2,
                  height: 1.32,
                ),
                keepOnOneLine: true,
              ),
            ),
          );
        continue;
      }
      if (TransposerEngine.isHeaderLine(line)) {
        final currentSectionIndex = sectionIndex++;
        final isActiveSection =
            _isGuidedMode && currentSectionIndex == _activeSectionIndex;
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 28, bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActiveSection
                  ? Colors.redAccent.withOpacity(0.13)
                  : _headerBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(
                  color: isActiveSection ? Colors.redAccent : Colors.blueAccent,
                  width: isActiveSection ? 4 : 3,
                ),
              ),
            ),
            child: Row(
              children: [
                if (isActiveSection) ...[
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.redAccent,
                    size: 17,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    line.replaceAll('[', '').replaceAll(']', '').toUpperCase(),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: isActiveSection
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: _fontSize - 2,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      if (TransposerEngine.isChordLine(line)) {
        if (_showChords)
          widgets.add(
            Padding(
              padding: EdgeInsets.only(top: _fontSize * 0.35),
              child: _buildCifraLine(
                line.trimRight(),
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: _fontSize,
                  height: 1.28,
                ),
                keepOnOneLine: true,
              ),
            ),
          );
        continue;
      }

      widgets.add(
        SizedBox(
          width: double.infinity,
          child: _buildCifraLine(
            line,
            style: TextStyle(
              color: _bodyText,
              fontFamily: 'monospace',
              fontSize: _fontSize,
              height: 1.55,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }

  Widget _buildCifraLine(
    String text, {
    required TextStyle style,
    bool keepOnOneLine = false,
  }) {
    final child = Text(
      text,
      softWrap: !keepOnOneLine || !widget.allowHorizontalCifraScroll,
      overflow: TextOverflow.visible,
      style: style,
    );

    if (!keepOnOneLine || !widget.allowHorizontalCifraScroll) {
      return child;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }
}

class _StudyPill extends StatelessWidget {
  const _StudyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.blueAccent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CifraSection {
  const _CifraSection({required this.title, required this.lineIndex});

  final String title;
  final int lineIndex;
}
