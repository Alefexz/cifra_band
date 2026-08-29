// lib/features/home/presentation/screens/home_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'search_screen.dart';
import 'profile_screen.dart';
import 'schedules_screen.dart';
import '../providers/home_providers.dart';
import 'package:cifra_band/features/setlist/presentation/screens/setlist_screen.dart';
// ⚠️ IMPORTA O SEU NOVO SERVIÇO DE REGISTRO DE TOKENS
import 'package:cifra_band/core/services/push_notification_service.dart';
import 'package:cifra_band/core/services/api_notification.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 2;

  @override
  void initState() {
    super.initState();
    // ⚠️ REGISTRA O APARELHO ASSIM QUE A HOME CARREGA
    PushNotificationService.registerDevice();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      resizeToAvoidBottomInset: false,

      body: userProfileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Erro: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        data: (userData) {
          if (userData == null)
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );

          final String? churchId = userData['church_id'];

          final List<Widget> screens = [
            churchId == null
                ? _buildLobby(userData)
                : _buildDashboard(userData, churchId),
            SchedulesScreen(
              churchId: churchId ?? '',
              isAdmin: userData['is_admin'] == true,
            ),
            const SearchScreen(),
            const SetlistScreen(),
            const ProfileScreen(),
          ];

          return IndexedStack(index: _currentIndex, children: screens);
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTabTapped(2),
        backgroundColor: Colors.blueAccent,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF16161E),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
              _buildNavItem(
                Icons.calendar_month_outlined,
                Icons.calendar_month_rounded,
                'Escalas',
                1,
              ),
              const SizedBox(width: 48),
              _buildNavItem(
                Icons.queue_music_outlined,
                Icons.queue_music,
                'Setlists',
                3,
              ),
              _buildNavItem(
                Icons.person_outline,
                Icons.person_rounded,
                'Perfil',
                4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    IconData activeIcon,
    String label,
    int index,
  ) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? Colors.blueAccent : Colors.grey.shade600,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blueAccent : Colors.grey.shade600,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(Map<String, dynamic> userData) {
    final userName = userData['name'] ?? 'Músico';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              'Olá, $userName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Você ainda não faz parte de nenhuma equipe.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
            const Spacer(),
            Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 80,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => context.push('/create-ministry'),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A24), Color(0xFF121218)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_home_work_rounded,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fundar Ministério',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Crie sua equipe e convide a banda',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _JoinMinistryBottomSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Entrar com Código',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Já tem uma equipe? Digite o PIN',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> userData, String churchId) {
    final userName = userData['name'] ?? 'Músico';
    final isAdmin = userData['is_admin'] == true;
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

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

    return SafeArea(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('ministries')
            .doc(churchId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );

          final ministryData = snapshot.data!.data() as Map<String, dynamic>?;
          if (ministryData == null)
            return const Center(
              child: Text(
                'Erro ao carregar Igreja',
                style: TextStyle(color: Colors.redAccent),
              ),
            );

          final churchName = ministryData['name'] ?? 'Igreja Local';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Olá, $userName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bem-vindo de volta',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF282832),
                      child: Text(
                        userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => _MinistryProfileBottomSheet(
                        churchId: churchId,
                        churchName: churchName,
                        isAdmin: isAdmin,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blueAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.church_rounded,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                churchName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ver equipe e histórico musical',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Text(
                  'PRÓXIMA ESCALA',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('schedules')
                      .where('church_id', isEqualTo: churchId)
                      .where(
                        'date',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime.now().subtract(const Duration(hours: 12)),
                        ),
                      )
                      .orderBy('date')
                      .limit(1)
                      .snapshots(),
                  builder: (context, scheduleSnapshot) {
                    if (scheduleSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final futureDocs =
                        scheduleSnapshot.data?.docs.toList() ?? [];

                    final bool hasSchedule = futureDocs.isNotEmpty;
                    Map<String, dynamic>? scheduleData;
                    String scheduleId = '';

                    if (hasSchedule) {
                      scheduleData =
                          futureDocs.first.data() as Map<String, dynamic>;
                      scheduleId = futureDocs.first.id;
                    }

                    bool isUserScheduled = false;
                    String roleInSchedule = '';

                    if (hasSchedule && scheduleData != null) {
                      final List<dynamic> teamList =
                          scheduleData['team_assignments'] ?? [];
                      for (var member in teamList) {
                        if (member['uid'] == currentUserId) {
                          isUserScheduled = true;
                          roleInSchedule = member['role'] ?? 'Membro';
                          break;
                        }
                      }
                    }

                    final scheduleTitle = hasSchedule
                        ? scheduleData!['title']
                        : 'Sem data marcada';
                    String formattedDate = 'Aguardando agendamento';

                    if (hasSchedule && scheduleData!['date'] != null) {
                      final DateTime date = (scheduleData['date'] as Timestamp)
                          .toDate();
                      final day = date.day.toString().padLeft(2, '0');
                      final month = date.month.toString().padLeft(2, '0');
                      final hour = date.hour.toString().padLeft(2, '0');
                      final minute = date.minute.toString().padLeft(2, '0');
                      formattedDate = '$day/$month às $hour:$minute';
                    }

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A24), Color(0xFF121218)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (hasSchedule && isUserScheduled)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green,
                                        size: 14,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'VOCÊ ESCALADO!',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (hasSchedule)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PRÓXIMO EVENTO',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            scheduleTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (hasSchedule)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 12),

                          if (hasSchedule && isUserScheduled)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    getRoleIcon(roleInSchedule),
                                    color: Colors.blueAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sua Função: ',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  roleInSchedule,
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          else if (!hasSchedule && isAdmin)
                            Text(
                              'Agende o próximo culto para a sua equipe.',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                              ),
                            )
                          else if (hasSchedule && !isUserScheduled)
                            Text(
                              'Você não foi escalado(a) neste culto.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),

                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                if (hasSchedule) {
                                  context.push(
                                    '/event',
                                    extra: {
                                      'isAdmin': isAdmin,
                                      'scheduleId': scheduleId,
                                    },
                                  );
                                } else if (isAdmin) {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        _CreateScheduleBottomSheet(
                                          churchId: churchId,
                                        ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Aguardando agendamento.'),
                                      backgroundColor: Colors.blueAccent,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                hasSchedule
                                    ? 'Acessar Escala'
                                    : (isAdmin
                                          ? 'Agendar Culto'
                                          : 'Ver Repertório'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// PERFIL COMPLETO DO MINISTÉRIO (Membros + Histórico)
// ==========================================
class _MinistryProfileBottomSheet extends StatefulWidget {
  final String churchId;
  final String churchName;
  final bool isAdmin;

  const _MinistryProfileBottomSheet({
    required this.churchId,
    required this.churchName,
    required this.isAdmin,
  });

  @override
  State<_MinistryProfileBottomSheet> createState() =>
      _MinistryProfileBottomSheetState();
}

class _MinistryProfileBottomSheetState
    extends State<_MinistryProfileBottomSheet> {
  bool _inviteIndexEnsured = false;

  void _ensureInviteIndex(String inviteCode) {
    if (_inviteIndexEnsured ||
        !widget.isAdmin ||
        inviteCode.isEmpty ||
        inviteCode == '---') {
      return;
    }
    _inviteIndexEnsured = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    unawaited(
      FirebaseFirestore.instance
          .collection('ministry_invites')
          .doc(inviteCode)
          .set({
            'ministry_id': widget.churchId,
            'admin_id': user.uid,
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((e) {
            debugPrint('Falha ao sincronizar convite do ministério: $e');
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D12),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
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

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.church_rounded,
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.churchName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Perfil da Equipe',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (widget.isAdmin) ...[
                    const SizedBox(height: 24),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('ministries')
                          .doc(widget.churchId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final inviteCode =
                            (snapshot.data!.data()
                                as Map<String, dynamic>?)?['invite_code'] ??
                            '---';
                        _ensureInviteIndex(inviteCode);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PIN de Convite:',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    inviteCode,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: inviteCode),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Código copiado!'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            TabBar(
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 3,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
              tabs: const [
                Tab(text: 'EQUIPE'),
                Tab(text: 'HISTÓRICO MUSICAL'),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [_buildTeamTab(), _buildHistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('church_id', isEqualTo: widget.churchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );

        final users = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: users.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Color(0xFF282832), height: 1),
          itemBuilder: (context, index) {
            final userDoc = users[index];
            final userData = userDoc.data() as Map<String, dynamic>;
            final isMemberAdmin = userData['is_admin'] == true;
            final memberName = userData['name'] ?? 'Sem Nome';
            final memberRoles = List<String>.from(userData['roles'] ?? []);
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isMemberAdmin
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.blueAccent.withOpacity(0.2),
                child: Text(
                  memberName[0].toUpperCase(),
                  style: TextStyle(
                    color: isMemberAdmin ? Colors.orange : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(
                    memberName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isMemberAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                memberRoles.isNotEmpty ? memberRoles.join(', ') : 'Membro',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              trailing: userDoc.id == currentUserId
                  ? const Text(
                      'Você',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : (widget.isAdmin
                        ? PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.grey,
                            ),
                            color: const Color(0xFF2C2C2E),
                            onSelected: (value) async {
                              if (value == 'promote') {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userDoc.id)
                                    .update({'is_admin': true});
                              } else if (value == 'demote') {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userDoc.id)
                                    .update({'is_admin': false});
                              } else if (value == 'remove') {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userDoc.id)
                                    .update({
                                      'church_id': null,
                                      'is_admin': false,
                                    });
                              }
                            },
                            itemBuilder: (context) => [
                              if (!isMemberAdmin)
                                const PopupMenuItem(
                                  value: 'promote',
                                  child: Text(
                                    'Tornar Administrador',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              if (isMemberAdmin)
                                const PopupMenuItem(
                                  value: 'demote',
                                  child: Text(
                                    'Remover de Administrador',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text(
                                  'Remover da Equipe',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink()),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('church_id', isEqualTo: widget.churchId)
          .snapshots(),
      builder: (context, scheduleSnapshot) {
        if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = scheduleSnapshot.data?.docs.toList() ?? [];
        final now = DateTime.now().subtract(const Duration(hours: 12));

        final pastDocs = docs.where((doc) {
          final date =
              ((doc.data() as Map<String, dynamic>)['date'] as Timestamp?)
                  ?.toDate();
          return date != null && date.isBefore(now);
        }).toList();

        pastDocs.sort((a, b) {
          final dateA = (a.data() as Map<String, dynamic>)['date'] as Timestamp;
          final dateB = (b.data() as Map<String, dynamic>)['date'] as Timestamp;
          return dateB.compareTo(dateA);
        });

        List<Map<String, dynamic>> recentSongs = [];
        for (var pastDoc in pastDocs) {
          final data = pastDoc.data() as Map<String, dynamic>;
          final approvedSongs = data['approved_songs'] as List<dynamic>? ?? [];
          final date = (data['date'] as Timestamp).toDate();
          final dateStr =
              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

          for (var song in approvedSongs) {
            final songMap = Map<String, dynamic>.from(song);
            songMap['played_date'] = dateStr;
            recentSongs.add(songMap);
          }
        }

        if (recentSongs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_off_rounded,
                  color: Colors.grey.shade700,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sem histórico',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quando a banda tocar, as músicas\naparecerão aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          physics: const BouncingScrollPhysics(),
          itemCount: recentSongs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final song = recentSongs[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      song['key'] ?? '-',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  song['title'] ?? 'Desconhecida',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        song['suggestedBy'] ?? 'Membro',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Tocado em:',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      song['played_date'] ?? '',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ==========================================
// MODAIS DE ENTRADA E CRIAÇÃO
// ==========================================
class _JoinMinistryBottomSheet extends StatefulWidget {
  const _JoinMinistryBottomSheet();
  @override
  State<_JoinMinistryBottomSheet> createState() =>
      _JoinMinistryBottomSheetState();
}

class _JoinMinistryBottomSheetState extends State<_JoinMinistryBottomSheet> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _joinMinistry() async {
    final pin = _pinController.text.trim().toUpperCase();
    if (pin.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final inviteDoc = await firestore
          .collection('ministry_invites')
          .doc(pin)
          .get();

      if (!inviteDoc.exists) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Código inválido.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        return;
      }

      final ministryId = inviteDoc.data()?['ministry_id'];
      if (ministryId is! String || ministryId.isEmpty) {
        throw Exception('Convite inválido.');
      }
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await firestore.collection('users').doc(uid).get();
      final memberName = userDoc.data()?['name']?.toString() ?? 'Novo membro';
      final adminId = inviteDoc.data()?['admin_id'];

      await firestore.collection('users').doc(uid).update({
        'church_id': ministryId,
        'is_admin': false,
      });

      if (adminId is String && adminId.isNotEmpty && adminId != uid) {
        await ApiNotification.notificarNovoMembro([adminId], memberName);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
          children: [
            const Text(
              'Entrar na Equipe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              textAlign: TextAlign.center,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'CÓDIGO',
                hintStyle: TextStyle(
                  color: Colors.grey.shade700,
                  letterSpacing: 4,
                ),
                filled: true,
                fillColor: const Color(0xFF0D0D12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _joinMinistry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Confirmar',
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

class _CreateScheduleBottomSheet extends StatefulWidget {
  final String churchId;
  const _CreateScheduleBottomSheet({required this.churchId});
  @override
  State<_CreateScheduleBottomSheet> createState() =>
      _CreateScheduleBottomSheetState();
}

class _CreateScheduleBottomSheetState
    extends State<_CreateScheduleBottomSheet> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Culto de Celebração',
  );
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF16161E),
              onSurface: Colors.white,
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
      initialTime: const TimeOfDay(hour: 18, minute: 0),
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

  Future<void> _createSchedule() async {
    if (_titleController.text.trim().isEmpty) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escolha o dia e o horário do culto.'),
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

      final docRef = await FirebaseFirestore.instance
          .collection('schedules')
          .add({
            'church_id': widget.churchId,
            'title': _titleController.text.trim(),
            'date': Timestamp.fromDate(finalDateTime),
            'suggested_songs': [],
            'approved_songs': [],
            'team_assignments': [],
            'created_at': FieldValue.serverTimestamp(),
          });

      await docRef.update({'id': docRef.id});

      if (mounted) {
        Navigator.pop(context);
        context.push(
          '/event',
          extra: {'isAdmin': true, 'scheduleId': docRef.id},
        );
      }
    } catch (e) {
      debugPrint('Erro: $e');
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
              'Montar Próxima Escala',
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
                onPressed: _isLoading ? null : _createSchedule,
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
                        'Confirmar e Agendar',
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
