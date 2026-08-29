import 'dart:async';

import 'package:cifra_band/core/services/played_history_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:cifra_band/features/songs/presentation/screens/cifra_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CultSetlistPlayerScreen extends StatefulWidget {
  final String title;
  final List<SongModel> songs;
  final int initialIndex;

  const CultSetlistPlayerScreen({
    super.key,
    required this.title,
    required this.songs,
    this.initialIndex = 0,
  });

  @override
  State<CultSetlistPlayerScreen> createState() =>
      _CultSetlistPlayerScreenState();
}

class _CultSetlistPlayerScreenState extends State<CultSetlistPlayerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final safeInitialIndex = widget.songs.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.songs.length - 1).toInt();
    _currentIndex = safeInitialIndex;
    _pageController = PageController(initialPage: safeInitialIndex);
    if (widget.songs.isNotEmpty) {
      unawaited(
        PlayedHistoryService.recordSong(widget.songs[safeInitialIndex]),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    unawaited(PlayedHistoryService.recordSong(widget.songs[index]));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.songs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D0D12),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'Nenhuma música aprovada ainda.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final currentSong = widget.songs[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_currentIndex + 1}/${widget.songs.length} • ${currentSong.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _SetlistDots(
              total: widget.songs.length,
              currentIndex: _currentIndex,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.songs.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return CifraScreen(
                    song: widget.songs[index],
                    embedded: true,
                    recordHistory: false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetlistDots extends StatelessWidget {
  final int total;
  final int currentIndex;

  const _SetlistDots({required this.total, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (index) {
          final isActive = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: isActive ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? Colors.blueAccent : const Color(0xFF3A3A44),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
