// lib/features/setlist/presentation/screens/setlist_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cifra_band/features/songs/domain/entities/song_destination.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/setlist_entity.dart';
import '../controllers/setlist_controller.dart';
import '../../../songs/data/models/song_model.dart';

class SetlistDetailScreen extends ConsumerStatefulWidget {
  final SetlistEntity setlist;

  const SetlistDetailScreen({super.key, required this.setlist});

  @override
  ConsumerState<SetlistDetailScreen> createState() =>
      _SetlistDetailScreenState();
}

class _SetlistDetailScreenState extends ConsumerState<SetlistDetailScreen> {
  bool _isDeleting = false;

  Widget _loadFailure(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );

  Future<void> _deleteSetlist() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('setlists')
          .doc(widget.setlist.id)
          .delete();
      if (mounted) {
        Navigator.pop(context);
        context.pop();
        ref.invalidate(setlistControllerProvider);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Setlist apagada com sucesso!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao apagar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'Excluir Setlist?',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Tem certeza que deseja apagar essa setlist? Essa ação não pode ser desfeita.',
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isDeleting ? null : _deleteSetlist,
            child: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Excluir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    final TextEditingController renameController = TextEditingController(
      text: widget.setlist.title,
    );
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Renomear Setlist',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: TextField(
          controller: renameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Novo nome',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            filled: true,
            fillColor: const Color(0xFF1A1A24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final newName = renameController.text.trim();
              if (newName.isNotEmpty && newName != widget.setlist.title) {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('setlists')
                      .doc(widget.setlist.id)
                      .update({'title': newName});
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Setlist renomeada! Saia e volte para ver o novo nome.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erro ao renomear: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Salvar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
              ),
              title: const Text(
                'Renomear Setlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog();
              },
            ),
            const Divider(color: Color(0xFF282832)),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Colors.redAccent,
                ),
              ),
              title: const Text(
                'Excluir Setlist',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _shareSetlist() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSetlistModal(setlistId: widget.setlist.id),
    );
  }

  Future<void> _leaveSetlist() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('setlists')
          .doc(widget.setlist.id)
          .update({
            'sharedWith': FieldValue.arrayRemove([currentUser.uid]),
          });
      if (mounted) {
        context.pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Você saiu do repertório.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        messenger.showSnackBar(
          SnackBar(
            content: Text('Erro ao sair: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _fetchSongsByIds(
    List<dynamic> rawSongIds,
  ) async {
    final songIds = rawSongIds
        .map((id) => id.toString())
        .where((id) => id.trim().isNotEmpty)
        .toList();

    if (songIds.isEmpty) return [];

    final songsById = <String, DocumentSnapshot<Map<String, dynamic>>>{};

    for (var index = 0; index < songIds.length; index += 10) {
      final chunk = songIds.skip(index).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('songs')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        songsById[doc.id] = doc;
      }
    }

    return songIds
        .map((id) => songsById[id])
        .whereType<DocumentSnapshot<Map<String, dynamic>>>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final setlistName = widget.setlist.title;
    final currentUser = FirebaseAuth.instance.currentUser;
    // ⚠️ REGRA DO CHEFE: Sou o dono dessa Setlist?
    final bool isOwner = currentUser?.uid == widget.setlist.ownerId;

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
        title: Text(
          setlistName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // ESCONDE O BOTÃO DE COMPARTILHAR E EDITAR SE NÃO FOR O DONO!
          if (isOwner)
            IconButton(
              icon: const Icon(
                Icons.ios_share_rounded,
                color: Colors.blueAccent,
              ),
              onPressed: _shareSetlist,
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
              onPressed: _showEditOptions,
            ),
          if (!isOwner)
            IconButton(
              icon: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.redAccent,
              ),
              onPressed: _leaveSetlist,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ⚠️ AVISO PARA QUEM RECEBEU A SETLIST EMPRESTADA
          if (!isOwner)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.blueAccent.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    color: Colors.blueAccent,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Este repertório está sendo compartilhado com você. Você pode visualizar e adicionar cifras.',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('setlists')
                  .doc(widget.setlist.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _loadFailure(
                    'Não foi possível carregar esta setlist. Verifique a conexão e o compartilhamento.',
                  );
                }
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );

                final data = snapshot.data!.data() as Map<String, dynamic>?;
                if (data == null)
                  return const Center(
                    child: Text(
                      'Setlist não encontrada.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );

                final List<dynamic> songIds = data['songIds'] ?? [];

                if (songIds.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music_rounded,
                          color: Colors.grey.shade800,
                          size: 80,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Setlist: $setlistName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Adicione músicas clicando no +',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<
                  List<DocumentSnapshot<Map<String, dynamic>>>
                >(
                  future: _fetchSongsByIds(songIds),
                  builder: (context, futureSnapshot) {
                    if (futureSnapshot.hasError) {
                      return _loadFailure(
                        'Não foi possível carregar as músicas. Verifique a conexão e tente novamente.',
                      );
                    }
                    if (!futureSnapshot.hasData)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                        ),
                      );

                    final songs = futureSnapshot.data!;

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: songs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final songData = songs[index].data() ?? {};
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF16161E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.blueAccent,
                              ),
                            ),
                            title: Text(
                              songData['title'] ?? 'Sem título',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${songData['artist'] ?? 'Artista desconhecido'} • Tom: ${songData['key'] ?? '-'}',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              final songModel = SongModel(
                                id: songs[index].id,
                                title: songData['title'] ?? '',
                                artist: songData['artist'] ?? '',
                                originalKey:
                                    songData['key'] ??
                                    songData['originalKey'] ??
                                    '',
                                content: songData['content'] ?? '',
                                capo: songData['capo'] ?? '',
                                shapeKey: songData['shapeKey'] ?? '',
                                referenceUrl: songData['referenceUrl'],
                                bpm: songData['bpm']?.toString(),
                                rehearsalNotes: songData['rehearsalNotes'],
                                url: songData['url'] ?? '',
                              );
                              context.push('/cifra', extra: songModel);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/add-song',
          extra: SongDestination.setlist(widget.setlist.id),
        ),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Adicionar Música',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ==========================================
// MODAL DE COMPARTILHAMENTO INTELIGENTE (Tornado Público)
// ==========================================
class ShareSetlistModal extends StatefulWidget {
  final String setlistId;
  const ShareSetlistModal({super.key, required this.setlistId});

  @override
  State<ShareSetlistModal> createState() => _ShareSetlistModalState();
}

class _ShareSetlistModalState extends State<ShareSetlistModal> {
  Future<void> _toggleShare(String friendId, bool isShared) async {
    final setlistRef = FirebaseFirestore.instance
        .collection('setlists')
        .doc(widget.setlistId);

    if (isShared) {
      await setlistRef.update({
        'sharedWith': FieldValue.arrayRemove([friendId]),
      });
    } else {
      await setlistRef.update({
        'sharedWith': FieldValue.arrayUnion([friendId]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16161E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Compartilhar Setlist',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione os amigos que terão acesso a este repertório.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),

          const SizedBox(height: 32),
          const Text(
            'SEUS AMIGOS',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;
                final List<dynamic> friendsList = userData?['friends'] ?? [];

                if (friendsList.isEmpty) {
                  return const Center(
                    child: Text(
                      'Você ainda não tem amigos adicionados.\nVá no seu Perfil para adicionar contatos!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('setlists')
                      .doc(widget.setlistId)
                      .snapshots(),
                  builder: (context, setlistSnapshot) {
                    if (!setlistSnapshot.hasData)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                        ),
                      );

                    final setlistData =
                        setlistSnapshot.data!.data() as Map<String, dynamic>?;
                    final List<dynamic> sharedWithList =
                        setlistData?['sharedWith'] ?? [];

                    return ListView.builder(
                      itemCount: friendsList.length,
                      itemBuilder: (context, index) {
                        final friendId = friendsList[index] as String;
                        final isShared = sharedWithList.contains(friendId);

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(friendId)
                              .get(),
                          builder: (context, friendSnapshot) {
                            if (!friendSnapshot.hasData)
                              return const SizedBox.shrink();

                            final friendData =
                                friendSnapshot.data!.data()
                                    as Map<String, dynamic>?;
                            if (friendData == null)
                              return const SizedBox.shrink();

                            final friendName = friendData['name'] ?? 'Músico';

                            return _buildFriendTile(
                              friendId,
                              friendName,
                              isShared,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Concluir',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(String friendId, String name, bool isShared) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'M',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: isShared,
            onChanged: (val) => _toggleShare(friendId, isShared),
            activeColor: Colors.blueAccent,
            activeTrackColor: Colors.blueAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade800,
          ),
        ],
      ),
    );
  }
}
