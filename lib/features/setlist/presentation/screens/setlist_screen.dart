// lib/features/setlist/presentation/screens/setlist_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cifra_band/features/home/presentation/providers/home_providers.dart';
import '../../domain/entities/setlist_entity.dart';
import '../controllers/setlist_controller.dart';
import '../widgets/create_setlist_modal.dart';
import '../widgets/setlist_card.dart';

enum _SetlistFilter { all, mine, shared }

class SetlistScreen extends ConsumerStatefulWidget {
  const SetlistScreen({super.key});

  @override
  ConsumerState<SetlistScreen> createState() => _SetlistScreenState();
}

class _SetlistScreenState extends ConsumerState<SetlistScreen> {
  _SetlistFilter _filter = _SetlistFilter.all;

  @override
  Widget build(BuildContext context) {
    final setlistsAsyncValue = ref.watch(setlistControllerProvider);
    final userData = ref.watch(userProfileProvider).value;
    final churchId = userData?['church_id']?.toString();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        title: const Text(
          'Repertórios',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.blueAccent,
                size: 24,
              ),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const CreateSetlistModal(),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.blueAccent,
        backgroundColor: const Color(0xFF16161E),
        onRefresh: () async => ref.invalidate(setlistControllerProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Acesso Rápido',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  _buildQuickAccessCard(
                    title: 'Cifras Favoritas',
                    subtitle: 'Salvas neste aparelho',
                    icon: Icons.favorite_rounded,
                    iconColor: Colors.redAccent,
                    onTap: () => context.push('/favorites'),
                  ),
                  _buildQuickAccessCard(
                    title: 'Histórico',
                    subtitle: 'Últimas 20 tocadas',
                    icon: Icons.history_rounded,
                    iconColor: Colors.blueAccent,
                    onTap: () => context.push('/played-history'),
                  ),
                  _buildQuickAccessCard(
                    title: 'Offline',
                    subtitle: 'Setlists baixadas',
                    icon: Icons.offline_pin_rounded,
                    iconColor: Colors.green,
                    onTap: () => context.push('/offline-setlists'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildActiveSchedulesSection(churchId),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _filterTitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  PopupMenuButton<_SetlistFilter>(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: _filter == _SetlistFilter.all
                          ? Colors.grey.shade600
                          : Colors.blueAccent,
                      size: 22,
                    ),
                    color: const Color(0xFF282832),
                    onSelected: (value) => setState(() => _filter = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _SetlistFilter.all,
                        child: Text(
                          'Todas',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem(
                        value: _SetlistFilter.mine,
                        child: Text(
                          'Criadas por mim',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      PopupMenuItem(
                        value: _SetlistFilter.shared,
                        child: Text(
                          'Compartilhadas comigo',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              setlistsAsyncValue.when(
                data: (setlists) {
                  final visibleSetlists = _applyFilter(setlists, currentUserId);

                  if (visibleSetlists.isEmpty) {
                    return _buildEmptySetlists();
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleSetlists.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return SetlistCard(setlist: visibleSetlists[index]);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                ),
                error: (error, stack) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Não foi possível carregar suas setlists.',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  String get _filterTitle {
    switch (_filter) {
      case _SetlistFilter.mine:
        return 'SETLISTS CRIADAS POR MIM';
      case _SetlistFilter.shared:
        return 'SETLISTS COMPARTILHADAS COMIGO';
      case _SetlistFilter.all:
        return 'MINHAS SETLISTS';
    }
  }

  List<SetlistEntity> _applyFilter(
    List<SetlistEntity> setlists,
    String? currentUserId,
  ) {
    final sorted = [...setlists]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (currentUserId == null) return sorted;

    switch (_filter) {
      case _SetlistFilter.mine:
        return sorted
            .where((setlist) => setlist.ownerId == currentUserId)
            .toList();
      case _SetlistFilter.shared:
        return sorted
            .where((setlist) => setlist.sharedWith.contains(currentUserId))
            .toList();
      case _SetlistFilter.all:
        return sorted;
    }
  }

  Widget _buildActiveSchedulesSection(String? churchId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escalas Ativas',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        if (churchId == null || churchId.isEmpty)
          _buildInfoBox(
            icon: Icons.groups_rounded,
            text: 'Entre em uma equipe para ver as escalas ativas.',
          )
        else
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildInfoBox(
                  icon: Icons.error_outline_rounded,
                  text: 'Não foi possível carregar as escalas ativas.',
                );
              }

              final schedules = snapshot.data?.docs ?? [];
              if (schedules.isEmpty) {
                return _buildInfoBox(
                  icon: Icons.event_busy_rounded,
                  text: 'Nenhuma escala ativa no momento.',
                );
              }

              return Column(
                children: schedules.map((doc) {
                  final data = doc.data();
                  final title = data['title']?.toString() ?? 'Culto';
                  final date = data['date'] is Timestamp
                      ? (data['date'] as Timestamp).toDate()
                      : null;

                  return _ActiveScheduleTile(
                    title: title,
                    date: date,
                    onTap: () => context.push(
                      '/event',
                      extra: {'isAdmin': false, 'scheduleId': doc.id},
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildInfoBox({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySetlists() {
    final message = switch (_filter) {
      _SetlistFilter.mine => 'Você ainda não criou nenhuma setlist.',
      _SetlistFilter.shared => 'Nenhuma setlist foi compartilhada com você.',
      _SetlistFilter.all => 'Sua biblioteca está vazia.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_rounded,
            color: Colors.grey.shade700,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Crie pastas para organizar seu repertório.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveScheduleTile extends StatelessWidget {
  final String title;
  final DateTime? date;
  final VoidCallback onTap;

  const _ActiveScheduleTile({
    required this.title,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.event_available_rounded,
            color: Colors.blueAccent,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _formattedDate,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  String get _formattedDate {
    if (date == null) return 'Data não informada';
    final day = date!.day.toString().padLeft(2, '0');
    final month = date!.month.toString().padLeft(2, '0');
    final hour = date!.hour.toString().padLeft(2, '0');
    final minute = date!.minute.toString().padLeft(2, '0');
    return '$day/$month às $hour:$minute';
  }
}
