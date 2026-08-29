// lib/features/songs/presentation/screens/cifra_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cifra_band/core/services/played_history_service.dart';
import '../../data/models/song_model.dart';
import '../../domain/transposer_engine.dart';

class CifraScreen extends StatefulWidget {
  final SongModel song;
  final bool embedded;
  final bool recordHistory;

  const CifraScreen({
    super.key,
    required this.song,
    this.embedded = false,
    this.recordHistory = true,
  });

  @override
  State<CifraScreen> createState() => _CifraScreenState();
}

class _CifraScreenState extends State<CifraScreen> {
  late String _currentPitch;
  bool _isCapoActive = false;
  bool _isFavorite = false;

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
  bool _isPlaying = false;
  double _scrollSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _isCapoActive = _safeCapo.isNotEmpty && _safeCapo != '0';
    _currentPitch = _safeOriginalKey;

    WakelockPlus.enable();
    _checkIfFavorite();
    if (widget.recordHistory) {
      unawaited(PlayedHistoryService.recordSong(widget.song));
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
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
    if (_safeShapeKey.isEmpty) return _currentPitch;
    int diff = TransposerEngine.getSemitonesDifference(
      _safeOriginalKey,
      _currentPitch,
    );
    if (diff == 0) return _safeShapeKey;
    return TransposerEngine.transposeKey(_safeShapeKey, diff);
  }

  String get _displayedContent {
    String baseContent = _safeContent;
    String baseShape = _safeShapeKey.isNotEmpty
        ? _safeShapeKey
        : _safeOriginalKey;

    if (!_isCapoActive || _safeCapo.isEmpty || _safeCapo == '0') {
      if (baseShape == _currentPitch) return baseContent;
      return TransposerEngine.transposeSong(
        content: baseContent,
        originalKey: baseShape,
        shapeKey: baseShape,
        capo: '',
        targetKey: _currentPitch,
      );
    }

    final currentShape = _currentShape;
    if (baseShape == currentShape) return baseContent;
    return TransposerEngine.transposeSong(
      content: baseContent,
      originalKey: baseShape,
      shapeKey: baseShape,
      capo: '',
      targetKey: currentShape,
    );
  }

  void _toneUp() => _changeToneTo(_getShiftedPitch(1));
  void _toneDown() => _changeToneTo(_getShiftedPitch(-1));

  bool _isMinorPitch(String pitch) {
    return TransposerEngine.normalizeKey(pitch).toLowerCase().endsWith('m');
  }

  List<String> _toneOptionsForCurrentMode() {
    if (_isMinorPitch(_currentPitch)) {
      return const [
        'Am',
        'Bbm',
        'Bm',
        'Cm',
        'C#m',
        'Dm',
        'Ebm',
        'Em',
        'Fm',
        'F#m',
        'Gm',
        'G#m',
      ];
    }

    return const [
      'A',
      'Bb',
      'B',
      'C',
      'Db',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
    ];
  }

  String _canonicalPitchForUi(String pitch) {
    final options = _isMinorPitch(pitch)
        ? const [
            'Am',
            'Bbm',
            'Bm',
            'Cm',
            'C#m',
            'Dm',
            'Ebm',
            'Em',
            'Fm',
            'F#m',
            'Gm',
            'G#m',
          ]
        : const [
            'A',
            'Bb',
            'B',
            'C',
            'Db',
            'D',
            'Eb',
            'E',
            'F',
            'F#',
            'G',
            'Ab',
          ];

    for (final option in options) {
      if (TransposerEngine.getSemitonesDifference(option, pitch) == 0 &&
          _isMinorPitch(option) == _isMinorPitch(pitch)) {
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
          _isMinorPitch(tone) == _isMinorPitch(_currentPitch),
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
              decoration: const BoxDecoration(
                color: Color(0xFF16161E),
                borderRadius: BorderRadius.only(
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
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_safeCapo.isNotEmpty && _safeCapo != '0') ...[
                    SwitchListTile(
                      title: const Text(
                        'Usar Capotraste',
                        style: TextStyle(color: Colors.white, fontSize: 16),
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
                    const Divider(color: Color(0xFF282832), height: 16),
                  ],

                  SwitchListTile(
                    title: const Text(
                      'Mostrar Acordes',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _showChords,
                    onChanged: (val) {
                      setState(() => _showChords = val);
                      setModalState(() {});
                    },
                  ),
                  const Divider(color: Color(0xFF282832), height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Mostrar Tablaturas',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    activeColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                    value: _showTabs,
                    onChanged: (val) {
                      setState(() => _showTabs = val);
                      setModalState(() {});
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
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
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
                      color: Colors.grey.shade700,
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
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                '-1/2 tom',
                                style: TextStyle(
                                  color: Colors.white,
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
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                '+1/2 tom',
                                style: TextStyle(
                                  color: Colors.white,
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
                                ? Colors.white
                                : const Color(0xFF2C2C2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              t,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade400,
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
                      _changeToneTo(_safeOriginalKey);
                      uiPitch = _canonicalPitchForUi(_safeOriginalKey);
                      setModalState(() {});
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: const Color(0xFF2C2C2E),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            color: Colors.grey,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Restaurar',
                            style: TextStyle(
                              color: Colors.grey,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(100),
      ),
      // ⚠️ ADICIONADO: Scroll Horizontal para a barra caber em telas pequenas
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.grey, size: 20),
                  onPressed: _toneDown,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                InkWell(
                  onTap: _showToneSelector,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tom',
                          style: TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                        Text(
                          _currentPitch,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.grey, size: 20),
                  onPressed: _toneUp,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),

            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),

            Row(
              children: [
                IconButton(
                  icon: const Text(
                    'T-',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => setState(
                    () => _fontSize = (_fontSize - 1).clamp(12.0, 30.0),
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                Text(
                  '${_fontSize.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                IconButton(
                  icon: const Text(
                    'T+',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => setState(
                    () => _fontSize = (_fontSize + 1).clamp(12.0, 30.0),
                  ),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),

            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),

            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: _isPlaying ? Colors.orangeAccent : Colors.grey,
                    size: 28,
                  ),
                  onPressed: _toggleAutoScroll,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                InkWell(
                  onTap: _changeSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _scrollSpeed > 1.0
                          ? Colors.blueAccent.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_scrollSpeed}x',
                      style: TextStyle(
                        color: _scrollSpeed > 1.0
                            ? Colors.blueAccent
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            Container(
              width: 1,
              height: 24,
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),

            IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: _showSettingsPanel,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ),
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
          ],
        ),
      ],
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

                Text(
                  widget.song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.song.artist,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    InkWell(
                      onTap: _showToneSelector,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tom Real: $_currentPitch',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    if (_safeCapo.isNotEmpty && _safeCapo != '0') ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _showSettingsPanel,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isCapoActive
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isCapoActive
                                    ? Icons.link_rounded
                                    : Icons.link_off_rounded,
                                color: _isCapoActive
                                    ? Colors.orange
                                    : Colors.grey,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isCapoActive
                                    ? 'Capo $_safeCapo (Forma $_currentShape)'
                                    : 'Sem Capo',
                                style: TextStyle(
                                  color: _isCapoActive
                                      ? Colors.orange
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

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
                          avatar: const Icon(
                            Icons.sticky_note_2_outlined,
                            color: Colors.grey,
                          ),
                          label: Text(widget.song.rehearsalNotes!),
                          backgroundColor: Colors.white.withOpacity(0.06),
                          labelStyle: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                _buildRichCifra(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF0D0D12), child: page);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(child: page),
    );
  }

  Widget _buildRichCifra() {
    final lines = _displayedContent.split('\n');
    final widgets = <Widget>[];

    for (String line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: _fontSize * 0.8));
        continue;
      }
      if (TransposerEngine.isTabLine(line)) {
        if (_showTabs)
          widgets.add(
            Text(
              line,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
                fontSize: _fontSize - 2,
              ),
            ),
          );
        continue;
      }
      if (TransposerEngine.isHeaderLine(line)) {
        widgets.add(
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.blueAccent, width: 3),
              ),
            ),
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
            child: Text(
              line.replaceAll('[', '').replaceAll(']', '').toUpperCase(),
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: _fontSize - 2,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
        continue;
      }
      if (TransposerEngine.isChordLine(line)) {
        if (_showChords)
          widgets.add(
            Text(
              line,
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                fontSize: _fontSize,
              ),
            ),
          );
        continue;
      }

      widgets.add(
        Text(
          line,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'monospace',
            fontSize: _fontSize,
            height: 1.5,
          ),
        ),
      );
    }

    // ⚠️ ADICIONADO: Scroll Horizontal para a tablatura não quebrar de linha no celular
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}
