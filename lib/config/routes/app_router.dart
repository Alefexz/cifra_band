// lib/config/routes/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cifra_band/core/services/app_owner_service.dart';

import 'package:cifra_band/features/home/presentation/screens/onboarding_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/home_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/create_ministry_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/event_detail_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/add_friend_screen.dart'; // ⚠️ IMPORTAÇÃO DA NOVA TELA AQUI
import 'package:cifra_band/features/home/presentation/screens/cult_setlist_player_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/availability_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/feedback_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/my_support_screen.dart';
import 'package:cifra_band/features/home/presentation/screens/support_center_screen.dart';

import 'package:cifra_band/features/setlist/domain/entities/setlist_entity.dart';
import 'package:cifra_band/features/setlist/presentation/screens/setlist_detail_screen.dart';
import 'package:cifra_band/features/setlist/presentation/screens/favorite_songs_screen.dart';
import 'package:cifra_band/features/setlist/presentation/screens/played_history_screen.dart';
import 'package:cifra_band/features/setlist/presentation/screens/offline_setlists_screen.dart';

import 'package:cifra_band/features/songs/presentation/screens/add_song_screen.dart';
import 'package:cifra_band/features/songs/presentation/screens/cifra_screen.dart';
import 'package:cifra_band/features/songs/presentation/screens/official_library_screen.dart';
import 'package:cifra_band/features/songs/presentation/screens/official_song_editor_screen.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:cifra_band/features/songs/domain/entities/song_entity.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  observers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final goingToOnboarding = state.matchedLocation == '/';

    if (user != null && goingToOnboarding) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const OnboardingScreen()),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const HomeScreen()),
    ),
    GoRoute(
      path: '/create-ministry',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const CreateMinistryScreen()),
    ),
    GoRoute(
      path: '/event',
      pageBuilder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final isAdmin = args['isAdmin'] as bool? ?? false;
        final scheduleId = args['scheduleId'] as String? ?? '';
        if (scheduleId.isEmpty) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Escala não encontrada',
              message: 'Volte para a agenda e abra a escala novamente.',
            ),
          );
        }
        return _buildFadeTransition(
          context,
          state,
          EventDetailScreen(isAdmin: isAdmin, scheduleId: scheduleId),
        );
      },
    ),
    GoRoute(
      path: '/setlist',
      pageBuilder: (context, state) {
        if (state.extra is! SetlistEntity) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Setlist não encontrada',
              message: 'Volte para repertórios e abra a setlist novamente.',
            ),
          );
        }
        final setlist = state.extra as SetlistEntity;
        return _buildFadeTransition(
          context,
          state,
          SetlistDetailScreen(setlist: setlist),
        );
      },
    ),
    GoRoute(
      path: '/favorites',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const FavoriteSongsScreen()),
    ),
    GoRoute(
      path: '/played-history',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const PlayedHistoryScreen()),
    ),
    GoRoute(
      path: '/offline-setlists',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const OfflineSetlistsScreen()),
    ),
    // ⚠️ NOVA ROTA AQUI!
    GoRoute(
      path: '/add-friend',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const AddFriendScreen()),
    ),
    GoRoute(
      path: '/availability',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const AvailabilityScreen()),
    ),
    GoRoute(
      path: '/feedback',
      pageBuilder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return _buildFadeTransition(
          context,
          state,
          FeedbackScreen(
            initialType: args['type']?.toString(),
            initialScreen: args['screen']?.toString(),
            initialMessage: args['message']?.toString(),
          ),
        );
      },
    ),
    GoRoute(
      path: '/my-support',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const MySupportScreen()),
    ),
    GoRoute(
      path: '/support-center',
      pageBuilder: (context, state) {
        if (!AppOwnerService.isCurrentUserOwner) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Acesso restrito',
              message:
                  'A central global de suporte é exclusiva do dono do Cifra Band.',
            ),
          );
        }
        return _buildFadeTransition(
          context,
          state,
          const SupportCenterScreen(),
        );
      },
    ),
    GoRoute(
      path: '/official-library',
      pageBuilder: (context, state) =>
          _buildFadeTransition(context, state, const OfficialLibraryScreen()),
    ),
    GoRoute(
      path: '/official-song-editor',
      pageBuilder: (context, state) => _buildFadeTransition(
        context,
        state,
        OfficialSongEditorScreen(initialSong: state.extra),
      ),
    ),
    GoRoute(
      path: '/add-song',
      pageBuilder: (context, state) {
        if (state.extra is! String || (state.extra as String).isEmpty) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Destino não encontrado',
              message:
                  'Volte e escolha uma escala ou setlist para adicionar música.',
            ),
          );
        }
        final setlistId = state.extra as String;
        return _buildFadeTransition(
          context,
          state,
          AddSongScreen(setlistId: setlistId),
        );
      },
    ),
    GoRoute(
      path: '/cult-setlist',
      pageBuilder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final title = args['title']?.toString() ?? 'Setlist do Culto';
        final rawSongs = args['songs'];
        final initialIndex = args['initialIndex'] is int
            ? args['initialIndex'] as int
            : 0;

        final songs = rawSongs is List
            ? rawSongs.whereType<SongModel>().toList()
            : <SongModel>[];

        if (songs.isEmpty) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Setlist vazia',
              message:
                  'Aprove músicas no repertório da escala antes de abrir o modo culto.',
            ),
          );
        }

        return _buildFadeTransition(
          context,
          state,
          CultSetlistPlayerScreen(
            title: title,
            songs: songs,
            initialIndex: initialIndex,
          ),
        );
      },
    ),
    GoRoute(
      path: '/cifra',
      pageBuilder: (context, state) {
        final extra = state.extra;
        if (extra is! SongEntity) {
          return _buildFadeTransition(
            context,
            state,
            const _MissingRouteDataScreen(
              title: 'Cifra não encontrada',
              message: 'Volte para a busca e abra a música novamente.',
            ),
          );
        }
        final song = extra is SongModel
            ? extra
            : SongModel(
                id: extra.id,
                title: extra.title,
                artist: extra.artist,
                originalKey: extra.originalKey,
                shapeKey: extra.shapeKey,
                capo: extra.capo,
                referenceUrl: extra.referenceUrl,
                rehearsalNotes: extra.rehearsalNotes,
                bpm: extra.bpm,
                content: extra.content,
                url: extra.url,
              );
        return _buildFadeTransition(context, state, CifraScreen(song: song));
      },
    ),
  ],
);

CustomTransitionPage _buildFadeTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}

class _MissingRouteDataScreen extends StatelessWidget {
  final String title;
  final String message;

  const _MissingRouteDataScreen({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.grey.shade700,
                size: 72,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Voltar ao início',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
