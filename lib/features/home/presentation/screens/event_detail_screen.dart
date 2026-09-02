// lib/features/home/presentation/screens/event_detail_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart'; // ⚠️ IMPORT CRUCIAL
import 'package:cifra_band/core/services/api_notification.dart';
import 'package:cifra_band/core/services/availability_service.dart';
import 'package:cifra_band/core/services/offline_setlist_service.dart';
import 'package:cifra_band/core/services/rehearsal_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class EventDetailScreen extends StatefulWidget {
  final bool isAdmin;
  final String scheduleId;

  const EventDetailScreen({
    super.key,
    required this.isAdmin,
    required this.scheduleId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text(
          'Excluir Culto?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Isso apagará a escala e todas as sugestões de louvor.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final docRef = FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.scheduleId);
      final snapshot = await docRef.get();
      final data = snapshot.data() ?? {};
      final title = data['title']?.toString() ?? 'culto';
      final teamUids = _extractTeamUids(data['team_assignments'] ?? []);

      await docRef.delete();
      await ApiNotification.notificarEscalaCancelada(
        teamUids,
        title,
        widget.scheduleId,
      );
      if (mounted) context.pop();
    }
  }

  // ⚠️ NOVO: LÓGICA DE EDITAR O CULTO!
  void _editSchedule(String currentTitle, Timestamp? currentDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditScheduleBottomSheet(
        scheduleId: widget.scheduleId,
        currentTitle: currentTitle,
        currentDate: currentDate,
      ),
    );
  }

  Future<void> _removeMemberFromSchedule(
    Map<String, dynamic> memberAssignment,
    String scheduleTitle,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.scheduleId);
    await docRef.update({
      'team_assignments': FieldValue.arrayRemove([memberAssignment]),
      'team_uids': FieldValue.arrayRemove([memberAssignment['uid']]),
    });

    final uid = memberAssignment['uid']?.toString();
    final role = memberAssignment['role']?.toString() ?? 'Membro';
    if (uid != null && uid.isNotEmpty) {
      await ApiNotification.notificarRemovidoDaEscala(
        uid,
        scheduleTitle,
        role,
        widget.scheduleId,
      );
    }
  }

  Future<void> _respondToAssignment({
    required Map<String, dynamic> assignment,
    required String status,
    required String churchId,
    required String scheduleTitle,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || assignment['uid'] != currentUser.uid) return;

    final docRef = FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.scheduleId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? {};
        final team = List<dynamic>.from(data['team_assignments'] ?? []);
        final index = team.indexWhere((item) {
          if (item is! Map) return false;
          return item['uid'] == currentUser.uid &&
              item['role'] == assignment['role'];
        });

        if (index == -1) return;

        final updatedAssignment = Map<String, dynamic>.from(team[index] as Map);
        updatedAssignment['status'] = status;
        updatedAssignment['responded_at'] = Timestamp.now();
        team[index] = updatedAssignment;

        transaction.update(docRef, {'team_assignments': team});
      });

      final adminUids = await _getAdminUids(churchId);
      final name = assignment['name']?.toString() ?? 'Membro';

      if (status == 'accepted') {
        await ApiNotification.notificarAceite(
          adminUids,
          name,
          scheduleTitle,
          widget.scheduleId,
        );
      } else {
        await ApiNotification.notificarRecusa(
          adminUids,
          name,
          scheduleTitle,
          widget.scheduleId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'accepted'
                  ? 'Presença confirmada!'
                  : 'Recusa enviada ao líder.',
            ),
            backgroundColor: status == 'accepted'
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível registrar sua resposta.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<List<String>> _getAdminUids(String churchId) async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('church_id', isEqualTo: churchId)
        .where('is_admin', isEqualTo: true)
        .get();

    final adminUids = usersSnapshot.docs.map((doc) => doc.id).toSet();

    final ministryDoc = await FirebaseFirestore.instance
        .collection('ministries')
        .doc(churchId)
        .get();

    final ministryAdminId = ministryDoc.data()?['admin_id'];
    if (ministryAdminId is String && ministryAdminId.isNotEmpty) {
      adminUids.add(ministryAdminId);
    }

    return adminUids.toList();
  }

  List<String> _extractTeamUids(List<dynamic> teamAssignments) {
    return teamAssignments
        .map((assignment) {
          if (assignment is Map<String, dynamic>) return assignment['uid'];
          if (assignment is Map) return assignment['uid'];
          return null;
        })
        .whereType<String>()
        .toSet()
        .toList();
  }

  Future<void> _removeApprovedSong(Map<String, dynamic> songMap) async {
    final docRef = FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.scheduleId);
    final snapshot = await docRef.get();
    final teamUids = _extractTeamUids(
      List<dynamic>.from(snapshot.data()?['team_assignments'] ?? []),
    );
    await docRef.update({
      'approved_songs': FieldValue.arrayRemove([songMap]),
    });
    await ApiNotification.notificarMusicaRemovida(
      teamUids,
      songMap['title']?.toString() ?? 'Uma música',
      widget.scheduleId,
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Música removida do repertório oficial.'),
          backgroundColor: Colors.redAccent,
        ),
      );
  }

  Future<void> _saveApprovedSongsOffline(
    String scheduleTitle,
    List<SongModel> songs,
  ) async {
    if (songs.isEmpty) return;

    await OfflineSetlistService.saveCultSetlist(
      scheduleId: widget.scheduleId,
      title: scheduleTitle,
      songs: songs,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${songs.length} músicas salvas para tocar offline.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _reorderApprovedSongs(
    List<dynamic> approved,
    int oldIndex,
    int newIndex,
  ) async {
    if (!widget.isAdmin) return;
    if (newIndex > oldIndex) newIndex -= 1;

    final updated = List<dynamic>.from(approved);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.scheduleId)
        .update({'approved_songs': updated});
  }

  Future<void> _castVote(Map<String, dynamic> song, bool isUpvote) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance
        .collection('schedules')
        .doc(widget.scheduleId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      List<dynamic> suggested = snapshot.data()?['suggested_songs'] ?? [];

      int index = suggested.indexWhere(
        (s) => s['title'] == song['title'] && s['artist'] == song['artist'],
      );
      if (index == -1) return;

      Map<String, dynamic> targetSong = Map<String, dynamic>.from(
        suggested[index],
      );
      List<String> upvotes = List<String>.from(targetSong['upvotes'] ?? []);
      List<String> downvotes = List<String>.from(targetSong['downvotes'] ?? []);

      bool wasUpvoted = upvotes.contains(uid);
      bool wasDownvoted = downvotes.contains(uid);

      upvotes.remove(uid);
      downvotes.remove(uid);

      if (isUpvote) {
        if (!wasUpvoted) upvotes.add(uid);
      } else {
        if (!wasDownvoted) downvotes.add(uid);
      }

      targetSong['upvotes'] = upvotes;
      targetSong['downvotes'] = downvotes;
      suggested[index] = targetSong;
      transaction.update(docRef, {'suggested_songs': suggested});
    });
  }

  Future<void> _shareToWhatsApp(
    String title,
    String dateStr,
    List<dynamic> team,
    List<dynamic> songs,
  ) async {
    final text = Uri.encodeComponent(
      _buildSetlistShareText(title, dateStr, team, songs),
    );
    final url = Uri.parse('https://wa.me/?text=$text');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp não encontrado neste dispositivo.'),
            backgroundColor: Colors.orange,
          ),
        );
    }
  }

  String _buildSetlistShareText(
    String title,
    String dateStr,
    List<dynamic> team,
    List<dynamic> songs,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('*ESCALA: $title*');
    buffer.writeln('*Data:* $dateStr\n');

    buffer.writeln('*EQUIPE ESCALADA:*');
    if (team.isEmpty) {
      buffer.writeln('Nenhum membro escalado ainda.');
    } else {
      for (var member in team) {
        buffer.writeln('- ${member['name']} - ${member['role']}');
      }
    }
    buffer.writeln('');

    buffer.writeln('*REPERTORIO OFICIAL:*');
    if (songs.isEmpty) {
      buffer.writeln('Nenhum louvor aprovado ainda.');
    } else {
      for (int i = 0; i < songs.length; i++) {
        final s = songs[i];
        final bpm = s['bpm']?.toString().trim() ?? '';
        final note = s['rehearsalNotes']?.toString().trim() ?? '';
        buffer.writeln(
          '${i + 1}. ${s['title']} - ${s['artist']} (Tom: ${s['key']})${bpm.isEmpty ? '' : ' - $bpm BPM'}',
        );
        if (note.isNotEmpty) buffer.writeln('   Obs: $note');
      }
    }

    buffer.writeln('\nGerado pelo app Cifra Band');
    return buffer.toString();
  }

  Future<void> _copySetlist(
    String title,
    String dateStr,
    List<dynamic> team,
    List<dynamic> songs,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: _buildSetlistShareText(title, dateStr, team, songs)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Setlist copiada para colar no WhatsApp ou PDF.'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Future<void> _exportSetlistPdf(
    String title,
    String dateStr,
    List<dynamic> team,
    List<dynamic> songs,
  ) async {
    final pdf = pw.Document();
    final text = _buildSetlistShareText(
      title,
      dateStr,
      team,
      songs,
    ).replaceAll('*', '');

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(dateStr),
          pw.SizedBox(height: 18),
          pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safeTitle = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final file = File(
      '${dir.path}/setlist-${safeTitle.isEmpty ? 'culto' : safeTitle}.pdf',
    );
    await file.writeAsBytes(await pdf.save(), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Setlist $title - Cifra Band',
      ),
    );
  }

  Future<void> _toggleRehearsed(
    Map<String, dynamic> songMap,
    bool currentValue,
  ) async {
    final title = songMap['title']?.toString() ?? '';
    final artist = songMap['artist']?.toString() ?? '';
    final key = RehearsalService.songKey(title, artist);
    await RehearsalService.saveMyStatus(
      scheduleId: widget.scheduleId,
      songKey: key,
      title: title,
      artist: artist,
      rehearsed: !currentValue,
    );
  }

  Future<void> _showMySongObservation(Map<String, dynamic> songMap) async {
    final title = songMap['title']?.toString() ?? '';
    final artist = songMap['artist']?.toString() ?? '';
    final key = RehearsalService.songKey(title, artist);
    final controller = TextEditingController();

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
            decoration: const BoxDecoration(
              color: Color(0xFF16161E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 7,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Ex: preciso revisar ponte, segunda voz ou entrada.',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      filled: true,
                      fillColor: const Color(0xFF0D0D12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await RehearsalService.saveMyStatus(
                        scheduleId: widget.scheduleId,
                        songKey: key,
                        title: title,
                        artist: artist,
                        rehearsed: true,
                        note: controller.text,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Salvar observação'),
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

  Future<void> _openReferenceUrl(String rawUrl) async {
    final value = rawUrl.trim();
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

  void _showAddMemberModal(
    String churchId,
    List<dynamic> currentAssignments,
    String scheduleTitle,
    DateTime? scheduleDate,
  ) {
    final availableRoles = [
      'Voz',
      'Violão',
      'Guitarra',
      'Baixo',
      'Teclado',
      'Bateria',
      'Percussão',
      'Saxofone',
      'Líder de Louvor',
    ];
    String? selectedRole;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF16161E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
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
                  'Escalar Membro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedRole == null
                      ? '1. Escolha a função que precisa preencher:'
                      : '2. Escolha quem vai tocar $selectedRole:',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
                const SizedBox(height: 24),

                if (selectedRole == null)
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: availableRoles.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFF282832), height: 1),
                      itemBuilder: (context, index) {
                        final role = availableRoles[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.blueAccent,
                          ),
                          onTap: () => setModalState(() => selectedRole = role),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('church_id', isEqualTo: churchId)
                          .where('roles', arrayContains: selectedRole)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blueAccent,
                            ),
                          );

                        final users = snapshot.data?.docs ?? [];

                        return FutureBuilder<Set<String>>(
                          future: scheduleDate == null
                              ? Future.value(<String>{})
                              : AvailabilityService.unavailableUserIds(
                                  uids: users.map((user) => user.id),
                                  date: scheduleDate,
                                ),
                          builder: (context, availabilitySnapshot) {
                            if (availabilitySnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.blueAccent,
                                ),
                              );
                            }

                            final unavailableUids =
                                availabilitySnapshot.data ?? <String>{};
                            final availableUsers = users.where((user) {
                              final alreadyAssigned = currentAssignments.any(
                                (assignment) => assignment['uid'] == user.id,
                              );
                              final unavailable = unavailableUids.contains(
                                user.id,
                              );
                              return !alreadyAssigned && !unavailable;
                            }).toList();

                            if (availableUsers.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_off_rounded,
                                      size: 64,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Ninguém disponível',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Todos já estão escalados, marcaram indisponibilidade\nou não têm essa função no perfil.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 24),
                                    TextButton(
                                      onPressed: () => setModalState(
                                        () => selectedRole = null,
                                      ),
                                      child: const Text(
                                        'Voltar para Funções',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => setModalState(
                                      () => selectedRole = null,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.blueAccent,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Voltar',
                                      style: TextStyle(
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: availableUsers.length,
                                    separatorBuilder: (context, index) =>
                                        const Divider(
                                          color: Color(0xFF282832),
                                          height: 1,
                                        ),
                                    itemBuilder: (context, index) {
                                      final user = availableUsers[index];
                                      final userName = user['name'] ?? 'Membro';

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blueAccent
                                              .withOpacity(0.2),
                                          child: Text(
                                            userName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.blueAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('schedules')
                                                  .doc(widget.scheduleId)
                                                  .update({
                                                    'team_assignments':
                                                        FieldValue.arrayUnion([
                                                          {
                                                            'uid': user.id,
                                                            'name': userName,
                                                            'role':
                                                                selectedRole,
                                                            'status': 'pending',
                                                          },
                                                        ]),
                                                    'team_uids':
                                                        FieldValue.arrayUnion([
                                                          user.id,
                                                        ]),
                                                  });
                                              await ApiNotification.notificarEscalado(
                                                user.id,
                                                scheduleTitle,
                                                selectedRole ?? 'Membro',
                                                widget.scheduleId,
                                              );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  this.context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      '$userName escalado(a)!',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  this.context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Erro ao escalar: $e',
                                                    ),
                                                    backgroundColor:
                                                        Colors.redAccent,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Escalar',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.scheduleId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D12),
            body: Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D0D12),
            body: Center(
              child: Text(
                'Culto não encontrado.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final title = data['title'] ?? 'Culto';
        final churchId = data['church_id'] ?? '';
        Timestamp? timestampDate = data['date'] as Timestamp?;

        String formattedDate = '';
        if (timestampDate != null) {
          final DateTime date = timestampDate.toDate();
          formattedDate =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        }

        final List<dynamic> approvedSongs = data['approved_songs'] ?? [];
        final List<dynamic> suggestedSongs = data['suggested_songs'] ?? [];
        final List<dynamic> teamAssignments = data['team_assignments'] ?? [];

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D12),
          appBar: AppBar(
            backgroundColor: const Color(0xFF16161E),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => context.pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.ios_share_rounded,
                  color: Colors.greenAccent,
                ),
                color: const Color(0xFF282832),
                onSelected: (value) {
                  if (value == 'whatsapp') {
                    _shareToWhatsApp(
                      title,
                      formattedDate,
                      teamAssignments,
                      approvedSongs,
                    );
                  }
                  if (value == 'copy') {
                    _copySetlist(
                      title,
                      formattedDate,
                      teamAssignments,
                      approvedSongs,
                    );
                  }
                  if (value == 'pdf') {
                    _exportSetlistPdf(
                      title,
                      formattedDate,
                      teamAssignments,
                      approvedSongs,
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'whatsapp',
                    child: Text(
                      'Enviar no WhatsApp',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(
                      'Copiar texto',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text(
                      'Gerar PDF',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              if (widget.isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings_rounded, color: Colors.grey),
                  color: const Color(0xFF282832),
                  onSelected: (value) {
                    if (value == 'delete') _deleteSchedule();
                    // ⚠️ CHAMA A EDIÇÃO SE ESCOLHER EDIT
                    if (value == 'edit') _editSchedule(title, timestampDate);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text(
                        'Editar Culto',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Excluir Escala',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'REPERTÓRIO'),
                Tab(text: 'EQUIPE'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildRepertorioTab(
                approvedSongs,
                suggestedSongs,
                teamAssignments,
                title,
              ),
              _buildEquipeTab(churchId, teamAssignments, title, timestampDate),
            ],
          ),

          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              context.push('/add-song', extra: widget.scheduleId);
            },
            backgroundColor: Colors.blueAccent,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Sugerir Louvor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRepertorioTab(
    List<dynamic> approved,
    List<dynamic> suggested,
    List<dynamic> teamAssignments,
    String scheduleTitle,
  ) {
    final approvedSongModels = approved
        .whereType<Map>()
        .map((song) => _songModelFromScheduleSong(song))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text(
          'APROVADOS OFICIAIS',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        if (approved.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: Text(
              'Nenhum louvor aprovado ainda.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/cult-setlist',
                    extra: {
                      'title': scheduleTitle,
                      'songs': approvedSongModels,
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_play_rounded),
                  label: Text(
                    'Tocar Setlist do Culto (${approvedSongModels.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _saveApprovedSongsOffline(
                    scheduleTitle,
                    approvedSongModels,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: BorderSide(color: Colors.green.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.download_done_rounded),
                  label: const Text(
                    'Baixar Setlist Offline',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<bool>(
                  future: OfflineSetlistService.isCultSetlistSaved(
                    widget.scheduleId,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.offline_pin_rounded,
                            color: Colors.greenAccent,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Setlist offline baixada neste aparelho',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (widget.isAdmin && approved.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Segure e arraste as músicas para ajustar a ordem do culto.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (widget.isAdmin && approved.length > 1)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: approved.length,
              onReorder: (oldIndex, newIndex) =>
                  _reorderApprovedSongs(approved, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final song = approved[index] as Map<String, dynamic>;
                return ReorderableDragStartListener(
                  key: ValueKey(
                    '${song['title']}_${song['artist']}_${song['suggestedBy']}_$index',
                  ),
                  index: index,
                  child: _buildSongCard(
                    songMap: song,
                    isApproved: true,
                    team: teamAssignments,
                    orderNumber: index + 1,
                    canDrag: true,
                  ),
                );
              },
            )
          else
            ...approved.asMap().entries.map(
              (entry) => _buildSongCard(
                songMap: entry.value as Map<String, dynamic>,
                isApproved: true,
                team: teamAssignments,
                orderNumber: entry.key + 1,
              ),
            ),
        ],

        const SizedBox(height: 24),

        const Text(
          'SUGESTÕES EM VOTAÇÃO',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),

        if (suggested.isEmpty)
          const Text(
            'Nenhuma sugestão enviada.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else
          ...suggested.map(
            (song) => _buildSongCard(
              songMap: song as Map<String, dynamic>,
              isApproved: false,
              team: teamAssignments,
            ),
          ),
      ],
    );
  }

  SongModel _songModelFromScheduleSong(Map<dynamic, dynamic> songMap) {
    final title = songMap['title']?.toString() ?? 'Música desconhecida';
    final artist = songMap['artist']?.toString() ?? 'Artista desconhecido';
    return SongModel(
      id: songMap['id']?.toString() ?? '${title}_${artist}',
      title: title,
      artist: artist,
      originalKey:
          songMap['originalKey']?.toString() ??
          songMap['key']?.toString() ??
          'C',
      referenceUrl: songMap['referenceUrl']?.toString(),
      rehearsalNotes: songMap['rehearsalNotes']?.toString(),
      bpm: songMap['bpm']?.toString(),
      content:
          songMap['content']?.toString() ??
          '⚠️ ERRO: A cifra não foi salva no banco de dados da Escala.\n\nExclua esta música e adicione novamente para corrigir este problema!',
      capo: songMap['capo']?.toString() ?? '0',
      shapeKey: songMap['shapeKey']?.toString() ?? '',
      url: songMap['url']?.toString() ?? '',
    );
  }

  Widget _buildEquipeTab(
    String churchId,
    List<dynamic> teamAssignments,
    String scheduleTitle,
    Timestamp? scheduleTimestamp,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        if (teamAssignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF16161E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Equipe Vazia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum membro foi escalado para este culto ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ...teamAssignments.map(
            (assignment) =>
                _buildTeamMember(assignment, churchId, scheduleTitle),
          ),

        const SizedBox(height: 24),

        if (widget.isAdmin)
          OutlinedButton.icon(
            onPressed: () => _showAddMemberModal(
              churchId,
              teamAssignments,
              scheduleTitle,
              scheduleTimestamp?.toDate(),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blueAccent,
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.person_add_rounded),
            label: const Text(
              'Adicionar Membro na Escala',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required int count,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isActive ? activeColor : Colors.grey.shade800,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : Colors.grey.shade400,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? activeColor : Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard({
    required Map<String, dynamic> songMap,
    required bool isApproved,
    required List<dynamic> team,
    int? orderNumber,
    bool canDrag = false,
  }) {
    final title = songMap['title'] ?? 'Música desconhecida';
    final artist = songMap['artist'] ?? 'Artista desconhecido';
    final keyNote = songMap['key'] ?? 'C';
    final suggestedBy = songMap['suggestedBy'] ?? 'Membro';
    final referenceUrl = songMap['referenceUrl']?.toString().trim() ?? '';
    final bpm = songMap['bpm']?.toString().trim() ?? '';
    final notes = songMap['rehearsalNotes']?.toString().trim() ?? '';

    final List<dynamic> upvotes = songMap['upvotes'] ?? [];
    final List<dynamic> downvotes = songMap['downvotes'] ?? [];

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final bool didIUpvote = upvotes.contains(uid);
    final bool didIDownvote = downvotes.contains(uid);

    // ⚠️ AGORA A MÚSICA É CLICÁVEL E ABRE A CIFRA REAL!
    return GestureDetector(
      onTap: () {
        final songModel = _songModelFromScheduleSong(songMap);
        context.push('/cifra', extra: songModel);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isApproved
                ? Colors.blueAccent.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        keyNote,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          artist,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (orderNumber != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '#$orderNumber',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (canDrag) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.drag_handle_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ],
                  if (isApproved && widget.isAdmin)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeApprovedSong(songMap),
                    )
                  else if (isApproved)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.blueAccent,
                    ),
                ],
              ),

              if (referenceUrl.isNotEmpty ||
                  bpm.isNotEmpty ||
                  notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (referenceUrl.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.play_circle_outline_rounded),
                        label: const Text('Referência'),
                        backgroundColor: Colors.blueAccent.withOpacity(0.14),
                        labelStyle: const TextStyle(color: Colors.blueAccent),
                        onPressed: () => _openReferenceUrl(referenceUrl),
                      ),
                    if (bpm.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.speed_rounded,
                          color: Colors.orange,
                        ),
                        label: Text('$bpm BPM'),
                        backgroundColor: Colors.orange.withOpacity(0.12),
                        labelStyle: const TextStyle(color: Colors.orange),
                      ),
                    if (notes.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.sticky_note_2_outlined,
                          color: Colors.grey,
                        ),
                        label: Text(notes),
                        backgroundColor: Colors.white.withOpacity(0.06),
                        labelStyle: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
              ],

              if (isApproved) ...[
                const SizedBox(height: 12),
                StreamBuilder<RehearsalStatus>(
                  stream: RehearsalService.watchMyStatus(
                    scheduleId: widget.scheduleId,
                    songKey: RehearsalService.songKey(
                      title.toString(),
                      artist.toString(),
                    ),
                  ),
                  builder: (context, snapshot) {
                    final rehearsed = snapshot.data?.rehearsed == true;
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _toggleRehearsed(songMap, rehearsed),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: rehearsed
                                  ? Colors.greenAccent
                                  : Colors.grey,
                              side: BorderSide(
                                color: rehearsed
                                    ? Colors.green.withValues(alpha: 0.55)
                                    : Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            icon: Icon(
                              rehearsed
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                            ),
                            label: Text(
                              rehearsed ? 'Já ensaiei' : 'Marcar ensaiada',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Observação da música',
                          onPressed: () => _showMySongObservation(songMap),
                          icon: const Icon(
                            Icons.sticky_note_2_outlined,
                            color: Colors.orangeAccent,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],

              if (!isApproved) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF282832), height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: Colors.grey.shade500,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Por: $suggestedBy',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    Row(
                      children: [
                        _buildVoteButton(
                          icon: Icons.thumb_up_rounded,
                          count: upvotes.length,
                          isActive: didIUpvote,
                          activeColor: Colors.blueAccent,
                          onTap: () => _castVote(songMap, true),
                        ),
                        const SizedBox(width: 8),
                        _buildVoteButton(
                          icon: Icons.thumb_down_rounded,
                          count: downvotes.length,
                          isActive: didIDownvote,
                          activeColor: Colors.redAccent,
                          onTap: () => _castVote(songMap, false),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamMember(
    Map<String, dynamic> assignment,
    String churchId,
    String scheduleTitle,
  ) {
    final name = assignment['name'] ?? 'Membro';
    final role = assignment['role'] ?? 'Função Oculta';
    final status = assignment['status']?.toString() ?? 'pending';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = assignment['uid'] == currentUserId;

    IconData getRoleIcon(String roleName) {
      if (roleName.toLowerCase().contains('voz') ||
          roleName.toLowerCase().contains('cantor'))
        return Icons.mic_rounded;
      if (roleName.toLowerCase().contains('violão') ||
          roleName.toLowerCase().contains('guitarra') ||
          roleName.toLowerCase().contains('baixo'))
        return Icons.music_note_rounded;
      if (roleName.toLowerCase().contains('bateria') ||
          roleName.toLowerCase().contains('percussão'))
        return Icons.album_rounded;
      if (roleName.toLowerCase().contains('teclado') ||
          roleName.toLowerCase().contains('piano'))
        return Icons.piano_rounded;
      return Icons.person_rounded;
    }

    Color statusColor() {
      if (status == 'accepted') return Colors.green;
      if (status == 'declined') return Colors.orange;
      return Colors.grey;
    }

    String statusText() {
      if (status == 'accepted') return 'CONFIRMADO';
      if (status == 'declined') return 'RECUSADO';
      return 'PENDENTE';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF282832),
                child: Icon(
                  getRoleIcon(role),
                  color: Colors.blueAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      role,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor().withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText(),
                  style: TextStyle(
                    color: statusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  onPressed: () =>
                      _removeMemberFromSchedule(assignment, scheduleTitle),
                ),
            ],
          ),
          if (isCurrentUser && status != 'accepted') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _respondToAssignment(
                      assignment: assignment,
                      status: 'declined',
                      churchId: churchId,
                      scheduleTitle: scheduleTitle,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respondToAssignment(
                      assignment: assignment,
                      status: 'accepted',
                      churchId: churchId,
                      scheduleTitle: scheduleTitle,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Aceitar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// ⚠️ NOVO: MODAL PARA EDITAR NOME E DATA DO CULTO
// ==========================================
class _EditScheduleBottomSheet extends StatefulWidget {
  final String scheduleId;
  final String currentTitle;
  final Timestamp? currentDate;

  const _EditScheduleBottomSheet({
    required this.scheduleId,
    required this.currentTitle,
    required this.currentDate,
  });

  @override
  State<_EditScheduleBottomSheet> createState() =>
      _EditScheduleBottomSheetState();
}

class _EditScheduleBottomSheetState extends State<_EditScheduleBottomSheet> {
  late TextEditingController _titleController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);

    if (widget.currentDate != null) {
      final date = widget.currentDate!.toDate();
      _selectedDate = date;
      _selectedTime = TimeOfDay(hour: date.hour, minute: date.minute);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF16161E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _pickTime();
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF16161E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _updateSchedule() async {
    if (_titleController.text.trim().isEmpty) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escolha o dia e o horário.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final docRef = FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.scheduleId);
      final snapshot = await docRef.get();
      final teamAssignments = List<dynamic>.from(
        snapshot.data()?['team_assignments'] ?? [],
      );
      final teamUids = teamAssignments
          .map((assignment) {
            if (assignment is Map<String, dynamic>) return assignment['uid'];
            if (assignment is Map) return assignment['uid'];
            return null;
          })
          .whereType<String>()
          .toSet()
          .toList();
      final updatedTitle = _titleController.text.trim();

      await docRef.update({
        'title': updatedTitle,
        'date': Timestamp.fromDate(finalDateTime),
      });

      await ApiNotification.notificarEscalaAtualizada(
        teamUids,
        updatedTitle,
        widget.scheduleId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Culto atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    String dateTimeText = 'Escolher Dia e Horário';
    if (_selectedDate != null && _selectedTime != null) {
      dateTimeText =
          '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')} às ${_selectedTime!.format(context)}';
    }

    return SingleChildScrollView(
      child: Container(
        margin: EdgeInsets.only(bottom: bottomInset),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar Culto',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome do Evento',
                labelStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFF0D0D12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(dateTimeText, style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Salvar Alterações',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
