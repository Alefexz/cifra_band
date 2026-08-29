// lib/features/home/presentation/screens/schedules_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SchedulesScreen extends StatefulWidget {
  final String churchId;
  final bool isAdmin;

  const SchedulesScreen({
    super.key,
    required this.churchId,
    required this.isAdmin,
  });

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen>
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12), // Fundo totalmente integrado
        elevation: 0,
        title: const Text(
          'Agenda do Ministério',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
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
            Tab(text: 'PRÓXIMOS CULTOS'),
            Tab(text: 'HISTÓRICO'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSchedulesList(isFuture: true),
          _buildSchedulesList(isFuture: false),
        ],
      ),
    );
  }

  Widget _buildSchedulesList({required bool isFuture}) {
    final threshold = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 12)),
    );
    final schedulesQuery = isFuture
        ? FirebaseFirestore.instance
              .collection('schedules')
              .where('church_id', isEqualTo: widget.churchId)
              .where('date', isGreaterThanOrEqualTo: threshold)
              .orderBy('date')
              .limit(50)
        : FirebaseFirestore.instance
              .collection('schedules')
              .where('church_id', isEqualTo: widget.churchId)
              .where('date', isLessThan: threshold)
              .orderBy('date', descending: true)
              .limit(50);

    return StreamBuilder<QuerySnapshot>(
      stream: schedulesQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar escalas',
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final filteredDocs = snapshot.data?.docs.toList() ?? [];

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFuture
                        ? Icons.event_available_rounded
                        : Icons.history_rounded,
                    size: 64,
                    color: Colors.blueAccent.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isFuture ? 'Nenhum culto agendado' : 'Histórico vazio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isFuture
                      ? 'Aguarde o líder montar a próxima escala.'
                      : 'Seus eventos passados aparecerão aqui.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredDocs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final schedule = filteredDocs[index];
            final data = schedule.data() as Map<String, dynamic>;
            final scheduleId = schedule.id;

            final title = data['title'] ?? 'Culto';
            final date = (data['date'] as Timestamp).toDate();

            // Tratamento de Data Bonito
            final List<String> shortMonths = [
              'JAN',
              'FEV',
              'MAR',
              'ABR',
              'MAI',
              'JUN',
              'JUL',
              'AGO',
              'SET',
              'OUT',
              'NOV',
              'DEZ',
            ];
            final monthStr = shortMonths[date.month - 1];
            final dayStr = date.day.toString().padLeft(2, '0');
            final timeStr =
                '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

            final currentUserId = FirebaseAuth.instance.currentUser!.uid;
            final team = data['team_assignments'] as List<dynamic>? ?? [];

            bool isMeScheduled = false;
            String myRole = '';
            for (var member in team) {
              if (member['uid'] == currentUserId) {
                isMeScheduled = true;
                myRole = member['role'] ?? '';
                break;
              }
            }

            // Variáveis de Estilo Dinâmicas
            final isHighlight = isMeScheduled && isFuture;

            return GestureDetector(
              onTap: () {
                context.push(
                  '/event',
                  extra: {'isAdmin': widget.isAdmin, 'scheduleId': scheduleId},
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isHighlight
                        ? [
                            const Color(0xFF1A1A24),
                            const Color(0xFF121218),
                          ] // Mais brilhante se estiver escalado
                        : [
                            const Color(0xFF16161E),
                            const Color(0xFF16161E),
                          ], // Cinza morto padrão
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isHighlight
                        ? Colors.blueAccent.withOpacity(0.3)
                        : Colors.white.withOpacity(0.05),
                  ),
                  boxShadow: [
                    if (isHighlight)
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BLOCO DE CALENDÁRIO À ESQUERDA
                      Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isHighlight
                              ? Colors.blueAccent.withOpacity(0.15)
                              : const Color(0xFF0D0D12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isHighlight
                                ? Colors.blueAccent.withOpacity(0.5)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              monthStr,
                              style: TextStyle(
                                color: isHighlight
                                    ? Colors.blueAccent
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dayStr,
                              style: TextStyle(
                                color: isHighlight
                                    ? Colors.white
                                    : Colors.grey.shade300,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // DETALHES À DIREITA
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      color: Colors.grey.shade500,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isHighlight)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ESCALADO',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  )
                                else if (!isFuture)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.grey.shade700,
                                    size: 18,
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            const SizedBox(height: 16),

                            // RODAPÉ DO CARD: EQUIPE E FUNÇÃO
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D12).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    color: Colors.grey.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${team.length}',
                                    style: TextStyle(
                                      color: Colors.grey.shade300,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  if (isHighlight) ...[
                                    const Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.blueAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        myRole,
                                        style: const TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else if (!isFuture && isMeScheduled) ...[
                                    Icon(
                                      Icons.music_note_rounded,
                                      color: Colors.grey.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        myRole,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ] else ...[
                                    Expanded(
                                      child: Text(
                                        'Toque para ver a escala',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
