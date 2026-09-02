import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cifra_band/core/services/played_history_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';

class PlayedHistoryScreen extends StatelessWidget {
  const PlayedHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Histórico',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Limpar histórico',
            onPressed: user == null
                ? null
                : () => _confirmClearHistory(context),
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Entre na sua conta para ver o histórico.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('played_history')
                  .orderBy('played_at', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Não foi possível carregar o histórico.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _EmptyHistory();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final playedAt = data['played_at'] is Timestamp
                        ? (data['played_at'] as Timestamp).toDate()
                        : null;
                    final song = SongModel(
                      id: docs[index].id,
                      title: data['title']?.toString() ?? 'Sem título',
                      artist:
                          data['artist']?.toString() ?? 'Artista desconhecido',
                      originalKey: data['originalKey']?.toString() ?? 'C',
                      shapeKey: data['shapeKey']?.toString(),
                      capo: data['capo']?.toString(),
                      referenceUrl: data['referenceUrl']?.toString(),
                      rehearsalNotes: data['rehearsalNotes']?.toString(),
                      bpm: data['bpm']?.toString(),
                      content: data['content']?.toString() ?? '',
                      url: data['url']?.toString() ?? '',
                    );

                    return _HistoryTile(
                      docId: docs[index].id,
                      song: song,
                      playedAt: playedAt,
                      onTap: () => context.push('/cifra', extra: song),
                    );
                  },
                );
              },
            ),
    );
  }

  static Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text(
          'Limpar histórico?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Isso remove todas as cifras tocadas recentemente deste aparelho/usuário.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await PlayedHistoryService.clearHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Histórico limpo.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, color: Colors.grey.shade800, size: 80),
          const SizedBox(height: 16),
          const Text(
            'Nada tocado ainda.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'As últimas 20 cifras abertas\naparecerão aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String docId;
  final SongModel song;
  final DateTime? playedAt;
  final VoidCallback onTap;

  const _HistoryTile({
    required this.docId,
    required this.song,
    required this.playedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              song.originalKey.isEmpty ? '-' : song.originalKey,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: PopupMenuButton<String>(
          color: const Color(0xFF20202A),
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          onSelected: (value) async {
            if (value == 'open') {
              onTap();
              return;
            }

            if (value == 'report') {
              context.push(
                '/feedback',
                extra: {
                  'type': 'wrong_chord',
                  'screen': 'Histórico',
                  'message':
                      'Problema na cifra:\n${song.title} - ${song.artist}\nTom: ${song.originalKey}\n\nDescreva o erro: ',
                },
              );
              return;
            }

            if (value == 'delete') {
              await PlayedHistoryService.deleteSongById(docId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${song.title} removida do histórico.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'open',
              child: _HistoryMenuItem(
                icon: Icons.open_in_new_rounded,
                label: 'Abrir cifra',
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: _HistoryMenuItem(
                icon: Icons.report_problem_rounded,
                label: 'Reportar problema',
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: _HistoryMenuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
                danger: true,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String get _subtitle {
    if (playedAt == null) return song.artist;
    final day = playedAt!.day.toString().padLeft(2, '0');
    final month = playedAt!.month.toString().padLeft(2, '0');
    final hour = playedAt!.hour.toString().padLeft(2, '0');
    final minute = playedAt!.minute.toString().padLeft(2, '0');
    return '${song.artist} • $day/$month às $hour:$minute';
  }
}

class _HistoryMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;

  const _HistoryMenuItem({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : Colors.white;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
