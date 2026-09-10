// lib/features/songs/presentation/screens/cifra_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
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
import '../../domain/song_content_quality.dart';
import '../../data/datasources/song_scraper_datasource.dart';

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
  static const bool _youtubeGuidedEnabled = false;

  late String _originalPitch;
  late String _shapePitch;
  late String _currentPitch;
  late bool _minorToneMode;
  bool _isCapoActive = false;
  bool _isFavorite = false;
  bool _isSimplified = false;
  bool _isStageMode = false;
  _CifraInstrument _selectedInstrument = _CifraInstrument.guitar;

  String get _safeCapo => widget.song.capo ?? '';
  String get _safeShapeKey => widget.song.shapeKey ?? '';
  String get _safeOriginalKey =>
      widget.song.originalKey.isEmpty ? 'C' : widget.song.originalKey;
  String get _safeContent => widget.song.content;

  double _fontSize = 16.0;
  bool _showChords = true;
  bool _showTabs = false;
  bool _repairingContent = false;

  Future<void> _findCompleteVersion() async {
    if (_repairingContent) return;
    setState(() => _repairingContent = true);
    try {
      final uri = Uri.https('cifraband-api.onrender.com', '/searchSong', {
        'artist': widget.song.artist,
        'track': widget.song.title,
      });
      final complete = await SongScraperDatasource().extractSongFromUrl(
        uri.toString(),
      );
      if (mounted) context.push('/cifra', extra: complete);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar outra versão: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _repairingContent = false);
    }
  }

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  Timer? _guidedSyncTimer;
  bool _isPlaying = false;
  double _scrollSpeed = 1.0;
  YoutubePlayerController? _youtubeController;
  bool _isGuidedMode = false;
  bool _guidedAutoScroll = true;
  bool _youtubeBoxMinimized = false;
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
    final savedInstrument = prefs.getString('cifra_instrument');
    if (!mounted) return;
    setState(() {
      _isStageMode = saved ?? widget.embedded;
      _selectedInstrument = _CifraInstrumentX.fromStorage(savedInstrument);
    });
  }

  Future<void> _toggleStageMode() async {
    setState(() => _isStageMode = !_isStageMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cifra_stage_mode', _isStageMode);
  }

  Future<void> _setInstrument(_CifraInstrument instrument) async {
    setState(() => _selectedInstrument = instrument);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cifra_instrument', instrument.storageKey);
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

  bool get _hasYoutubeReference =>
      _youtubeGuidedEnabled && _youtubeVideoId != null;

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
      _youtubeBoxMinimized = false;
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
      _youtubeBoxMinimized = false;
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

  Future<void> _jumpToGuidedLine(int lineIndex, int totalLines) async {
    final controller = _youtubeController;
    if (!_isGuidedMode || controller == null || totalLines <= 0) return;

    final safeLine = lineIndex.clamp(0, totalLines - 1);
    final factor = totalLines <= 1 ? 0.0 : safeLine / (totalLines - 1);
    final sections = _cifraSections;
    var activeSection = 0;

    for (var index = 0; index < sections.length; index++) {
      if (sections[index].lineIndex <= safeLine) {
        activeSection = index;
      }
    }

    setState(() => _activeSectionIndex = activeSection);

    try {
      final duration = await controller.duration;
      if (duration <= 0) return;
      await controller.seekTo(seconds: duration * factor, allowSeekAhead: true);
    } catch (_) {
      // Mantém o toque na cifra inofensivo enquanto o player inicializa.
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

  Widget _buildFloatingYoutubeBox() {
    final controller = _youtubeController;
    if (!_isGuidedMode || controller == null) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = math.min(screenWidth - 28, 292.0);

    return Positioned(
      top: 86,
      right: 14,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _youtubeBoxMinimized ? 58 : panelWidth,
        decoration: BoxDecoration(
          color: _isStageMode
              ? const Color(0xFF151722)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(_youtubeBoxMinimized ? 24 : 18),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isStageMode ? 0.45 : 0.18),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _youtubeBoxMinimized
            ? InkWell(
                onTap: () => setState(() => _youtubeBoxMinimized = false),
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 58,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: 1,
                        height: 1,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: 0.01,
                            child: YoutubePlayer(
                              controller: controller,
                              backgroundColor: Colors.black,
                              aspectRatio: 16 / 9,
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.smart_display_rounded,
                          color: Colors.redAccent,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.smart_display_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Ouvir junto',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              setState(() => _youtubeBoxMinimized = true),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.keyboard_arrow_right_rounded,
                              color: _secondaryText,
                              size: 22,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _disableGuidedMode,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              color: _secondaryText,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: YoutubePlayer(
                        controller: controller,
                        backgroundColor: Colors.black,
                        aspectRatio: 16 / 9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seção ${_activeSectionIndex + 1}/${_cifraSections.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _secondaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(
                            () => _guidedAutoScroll = !_guidedAutoScroll,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _guidedAutoScroll
                                  ? Colors.greenAccent.withValues(alpha: 0.15)
                                  : _controlColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _guidedAutoScroll ? 'Auto ON' : 'Auto OFF',
                              style: TextStyle(
                                color: _guidedAutoScroll
                                    ? Colors.greenAccent
                                    : _secondaryText,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
    final degrees = ChordStudyService.degreeMapForKey(_currentPitch);

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
                  'Tom de referência: $_currentPitch · ${_selectedInstrument.label}',
                  style: TextStyle(
                    color: _secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Text(
                        'Graus do tom',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (degrees.isEmpty)
                        Text(
                          'Não consegui montar o campo harmônico deste tom.',
                          style: TextStyle(color: _secondaryText),
                        )
                      else
                        ...degrees.map(_buildDegreeStudyCard),
                      const SizedBox(height: 18),
                      Text(
                        'Acordes desta cifra',
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (chords.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'Nenhum acorde reconhecido nesta cifra.',
                              style: TextStyle(color: _secondaryText),
                            ),
                          ),
                        )
                      else
                        ...chords.map((chord) {
                          final insight = ChordStudyService.insightFor(
                            chord,
                            _currentPitch,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildChordStudyCard(insight),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDegreeStudyCard(ScaleDegreeInfo degree) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _controlColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              degree.degree,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${degree.chord} · ${degree.roman}',
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _StudyPill(degree.function),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  degree.explanation,
                  style: TextStyle(
                    color: _secondaryText,
                    height: 1.32,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChordStudyCard(ChordInsight insight) {
    return InkWell(
      onTap: () => _showChordDetailSheet(insight.chord),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _controlColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  insight.chord,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                _StudyPill('Grau ${insight.degree}'),
                _StudyPill(insight.roman),
                _StudyPill(insight.function),
              ],
            ),
            const SizedBox(height: 10),
            _buildInstrumentDiagram(insight, compact: true),
            const SizedBox(height: 10),
            Text(
              insight.explanation,
              style: TextStyle(
                color: _secondaryText,
                height: 1.35,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChordDetailSheet(String chord) {
    final insight = ChordStudyService.insightFor(chord, _currentPitch);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: BoxDecoration(
            color: _modalSurfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.chord,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 26,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StudyPill('Grau ${insight.degree}'),
                    _StudyPill(insight.roman),
                    _StudyPill(insight.function),
                    _StudyPill(insight.quality),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstrumentDiagram(insight, compact: false),
                const SizedBox(height: 16),
                Text(
                  insight.notes.isEmpty
                      ? 'Notas ainda não identificadas para este acorde.'
                      : 'Notas: ${insight.notes.join(' - ')}',
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  insight.explanation,
                  style: TextStyle(
                    color: _secondaryText,
                    height: 1.42,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: _CifraInstrument.values.map((instrument) {
                    final selected = instrument == _selectedInstrument;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          selected: selected,
                          label: Center(child: Text(instrument.label)),
                          avatar: Icon(instrument.icon, size: 16),
                          onSelected: (_) async {
                            await _setInstrument(instrument);
                            if (context.mounted) Navigator.pop(context);
                            _showChordDetailSheet(chord);
                          },
                          selectedColor: Colors.blueAccent.withValues(
                            alpha: 0.18,
                          ),
                          backgroundColor: _controlColor,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.blueAccent
                                : _secondaryText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstrumentDiagram(
    ChordInsight insight, {
    required bool compact,
  }) {
    if (_selectedInstrument == _CifraInstrument.keyboard) {
      return _buildKeyboardDiagram(insight, compact: compact);
    }
    return _buildGuitarDiagram(insight, compact: compact);
  }

  Widget _buildGuitarDiagram(ChordInsight insight, {required bool compact}) {
    final shape = insight.guitarShape;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: _isStageMode
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                color: Colors.orangeAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shape == null
                      ? 'Violão/Guitarra · notas do acorde'
                      : 'Violão/Guitarra · ${shape.label}',
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          if (shape != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: compact ? 92 : 132,
              child: CustomPaint(
                painter: _GuitarChordPainter(
                  shape: shape,
                  color: Colors.orangeAccent,
                  textColor: _primaryText,
                  lineColor: _dividerColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              insight.notes.isEmpty
                  ? 'Ainda não há digitação segura cadastrada para este acorde.'
                  : 'Notas: ${insight.notes.join(' - ')}. Digitação não cadastrada com segurança.',
              style: TextStyle(
                color: _secondaryText,
                height: 1.35,
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyboardDiagram(ChordInsight insight, {required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: _isStageMode
            ? Colors.black.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.keyboard_alt_rounded,
                color: Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.notes.isEmpty
                      ? 'Teclado: notas ainda não identificadas'
                      : 'Teclado · ${insight.notes.join(' - ')}',
                  style: TextStyle(
                    color: _primaryText,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 12 : 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: compact ? 72 : 104,
            child: CustomPaint(
              painter: _KeyboardChordPainter(
                notes: insight.notes,
                color: Colors.greenAccent,
                textColor: _primaryText,
                lineColor: _dividerColor,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MODAIS (Configurações e Tom)
  // ==========================================================
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _modalSurfaceColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
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

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Instrumento da cifra',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _CifraInstrument.values.map((instrument) {
                          final selected = instrument == _selectedInstrument;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: InkWell(
                                onTap: () async {
                                  await _setInstrument(instrument);
                                  setModalState(() {});
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.blueAccent.withValues(
                                            alpha: 0.16,
                                          )
                                        : _controlColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: selected
                                          ? Colors.blueAccent
                                          : _dividerColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        instrument.icon,
                                        color: selected
                                            ? Colors.blueAccent
                                            : _secondaryText,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          instrument.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.blueAccent
                                                : _secondaryText,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      Divider(color: _dividerColor, height: 24),

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
                ),
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

                if (_hasYoutubeReference ||
                    (widget.song.bpm?.trim().isNotEmpty ?? false) ||
                    (widget.song.rehearsalNotes?.trim().isNotEmpty ??
                        false)) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_hasYoutubeReference)
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
      return ColoredBox(
        color: _pageBackground,
        child: Stack(children: [page, _buildFloatingYoutubeBox()]),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: Stack(children: [page, _buildFloatingYoutubeBox()]),
      ),
    );
  }

  Widget _buildRichCifra() {
    final lines = _displayedContent.split('\n');
    final widgets = <Widget>[];
    if (!SongContentQuality.hasLyrics(_safeContent)) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Esta versão salva contém pouca ou nenhuma letra.',
                style: TextStyle(color: _primaryText),
              ),
              TextButton.icon(
                onPressed: _repairingContent ? null : _findCompleteVersion,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _repairingContent ? 'Buscando...' : 'Buscar versão com letra',
                ),
              ),
            ],
          ),
        ),
      );
    }
    var sectionIndex = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      if (!_showTabs &&
          RegExp(
            r'^(?:\[Tab\b|Parte\s+\d+\s+de\s+\d+)',
            caseSensitive: false,
          ).hasMatch(line.trim()))
        continue;
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
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _isGuidedMode
                ? () => unawaited(_jumpToGuidedSection(currentSectionIndex))
                : null,
            child: Container(
              margin: const EdgeInsets.only(top: 28, bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActiveSection
                    ? Colors.redAccent.withOpacity(0.13)
                    : _headerBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: isActiveSection
                        ? Colors.redAccent
                        : Colors.blueAccent,
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
                      line
                          .replaceAll('[', '')
                          .replaceAll(']', '')
                          .toUpperCase(),
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
                  if (_isGuidedMode)
                    Icon(
                      Icons.ads_click_rounded,
                      color: isActiveSection
                          ? Colors.redAccent
                          : Colors.blueAccent.withValues(alpha: 0.72),
                      size: 15,
                    ),
                ],
              ),
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
                interactiveChords: true,
              ),
            ),
          );
        continue;
      }

      final lyricLine = SizedBox(
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
      );

      widgets.add(
        _isGuidedMode
            ? GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () =>
                    unawaited(_jumpToGuidedLine(lineIndex, lines.length)),
                child: lyricLine,
              )
            : lyricLine,
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
    bool interactiveChords = false,
  }) {
    final child = interactiveChords
        ? _buildInteractiveChordText(text, style)
        : Text(
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

  Widget _buildInteractiveChordText(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\s+|\S+');

    for (final match in pattern.allMatches(text)) {
      final part = match.group(0) ?? '';
      if (part.trim().isEmpty || !TransposerEngine.isChordToken(part)) {
        spans.add(TextSpan(text: part, style: style));
        continue;
      }

      final cleanChord = part.replaceAll('*', '');
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _showChordDetailSheet(cleanChord),
            child: Text(
              part,
              style: style.copyWith(
                color: Colors.blueAccent,
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.07),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );
    }

    return RichText(
      softWrap: false,
      overflow: TextOverflow.visible,
      text: TextSpan(children: spans),
    );
  }
}

class _StudyPill extends StatelessWidget {
  const _StudyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.12),
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
    );
  }
}

enum _CifraInstrument { guitar, keyboard }

extension _CifraInstrumentX on _CifraInstrument {
  String get storageKey => switch (this) {
    _CifraInstrument.guitar => 'guitar',
    _CifraInstrument.keyboard => 'keyboard',
  };

  String get label => switch (this) {
    _CifraInstrument.guitar => 'Violão',
    _CifraInstrument.keyboard => 'Teclado',
  };

  IconData get icon => switch (this) {
    _CifraInstrument.guitar => Icons.music_note_rounded,
    _CifraInstrument.keyboard => Icons.keyboard_alt_rounded,
  };

  static _CifraInstrument fromStorage(String? value) {
    return switch (value) {
      'keyboard' => _CifraInstrument.keyboard,
      _ => _CifraInstrument.guitar,
    };
  }
}

class _GuitarChordPainter extends CustomPainter {
  const _GuitarChordPainter({
    required this.shape,
    required this.color,
    required this.textColor,
    required this.lineColor,
  });

  final GuitarChordShape shape;
  final Color color;
  final Color textColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final markerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strings = 6;
    final frets = 5;
    final left = size.width * 0.12;
    final right = size.width * 0.88;
    final top = size.height * 0.16;
    final bottom = size.height * 0.84;
    final stringGap = (right - left) / (strings - 1);
    final fretGap = (bottom - top) / frets;

    for (var i = 0; i < strings; i++) {
      final x = left + stringGap * i;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }

    for (var i = 0; i <= frets; i++) {
      final y = top + fretGap * i;
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }

    final nutPaint = Paint()
      ..color = textColor.withValues(alpha: 0.82)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(left, top), Offset(right, top), nutPaint);

    final positions = shape.positions;
    final baseFret = shape.baseFret;
    if (baseFret > 1) {
      _drawCenteredText(
        canvas,
        '$baseFretª',
        Offset(left - 20, top + fretGap * 0.5),
        textColor.withValues(alpha: 0.78),
        10,
        FontWeight.w900,
      );
    }

    for (var i = 0; i < positions.length && i < strings; i++) {
      final value = positions[i];
      final x = left + stringGap * i;
      if (value == 'x' || value == '0') {
        _drawCenteredText(
          canvas,
          value,
          Offset(x, top - 13),
          textColor.withValues(alpha: value == 'x' ? 0.62 : 0.92),
          11,
          FontWeight.w900,
        );
        continue;
      }

      final fret = int.tryParse(value) ?? 1;
      final normalizedFret = baseFret > 1 ? fret - baseFret + 1 : fret;
      if (normalizedFret < 1 || normalizedFret > frets) continue;
      final y = top + fretGap * (normalizedFret - 0.5);
      canvas.drawCircle(Offset(x, y), size.height * 0.055, markerPaint);
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String value,
    Offset center,
    Color color,
    double fontSize,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GuitarChordPainter oldDelegate) {
    return oldDelegate.shape.positions.join(',') != shape.positions.join(',') ||
        oldDelegate.shape.label != shape.label ||
        oldDelegate.color != color ||
        oldDelegate.textColor != textColor ||
        oldDelegate.lineColor != lineColor;
  }
}

class _KeyboardChordPainter extends CustomPainter {
  const _KeyboardChordPainter({
    required this.notes,
    required this.color,
    required this.textColor,
    required this.lineColor,
  });

  static const _whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const _blackNotes = {0: 'C#', 1: 'D#', 3: 'F#', 4: 'G#', 5: 'A#'};

  final List<String> notes;
  final Color color;
  final Color textColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final highlighted = notes.map(_normalize).toSet();
    final whiteWidth = size.width / _whiteNotes.length;
    final whitePaint = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final blackPaint = Paint()..color = const Color(0xFF111827);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    final highlightPaint = Paint()..color = color.withValues(alpha: 0.72);

    for (var i = 0; i < _whiteNotes.length; i++) {
      final rect = Rect.fromLTWH(i * whiteWidth, 0, whiteWidth, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(6)),
        whitePaint,
      );
      canvas.drawRect(rect, linePaint);
      if (highlighted.contains(_whiteNotes[i])) {
        canvas.drawCircle(
          Offset(rect.center.dx, size.height * 0.72),
          size.height * 0.11,
          highlightPaint,
        );
        _drawCenteredText(
          canvas,
          _whiteNotes[i],
          Offset(rect.center.dx, size.height * 0.9),
          Colors.black,
          10,
        );
      }
    }

    _blackNotes.forEach((whiteIndex, note) {
      final x = (whiteIndex + 1) * whiteWidth - whiteWidth * 0.25;
      final rect = Rect.fromLTWH(x, 0, whiteWidth * 0.5, size.height * 0.62);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        blackPaint,
      );
      if (highlighted.contains(note)) {
        canvas.drawCircle(
          Offset(rect.center.dx, rect.bottom - size.height * 0.16),
          size.height * 0.095,
          highlightPaint,
        );
        _drawCenteredText(
          canvas,
          note,
          Offset(rect.center.dx, rect.bottom - size.height * 0.32),
          Colors.white,
          9,
        );
      }
    });
  }

  String _normalize(String note) {
    return note
        .replaceAll('Db', 'C#')
        .replaceAll('Eb', 'D#')
        .replaceAll('Gb', 'F#')
        .replaceAll('Ab', 'G#')
        .replaceAll('Bb', 'A#');
  }

  void _drawCenteredText(
    Canvas canvas,
    String value,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _KeyboardChordPainter oldDelegate) {
    return oldDelegate.notes.join(',') != notes.join(',') ||
        oldDelegate.color != color ||
        oldDelegate.textColor != textColor ||
        oldDelegate.lineColor != lineColor;
  }
}

class _CifraSection {
  const _CifraSection({required this.title, required this.lineIndex});

  final String title;
  final int lineIndex;
}
