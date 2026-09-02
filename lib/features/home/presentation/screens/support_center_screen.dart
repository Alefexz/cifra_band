import 'package:cifra_band/core/services/support_ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  String _status = 'open';
  String _type = 'all';
  String _severity = 'all';
  late Future<List<SupportTicket>> _ticketsFuture;

  static const _statusFilters = [
    _StatusFilter(value: 'open', label: 'Abertos'),
    _StatusFilter(value: 'resolved', label: 'Resolvidos'),
    _StatusFilter(value: 'closed', label: 'Fechados'),
    _StatusFilter(value: 'all', label: 'Todos'),
  ];

  static const _typeFilters = [
    _StatusFilter(value: 'all', label: 'Tudo'),
    _StatusFilter(value: 'bug', label: 'Bug'),
    _StatusFilter(value: 'wrong_chord', label: 'Cifra'),
    _StatusFilter(value: 'notification', label: 'Notif.'),
    _StatusFilter(value: 'update', label: 'Atualiz.'),
    _StatusFilter(value: 'question', label: 'Dúvida'),
    _StatusFilter(value: 'suggestion', label: 'Sugestão'),
  ];

  static const _severityFilters = [
    _StatusFilter(value: 'all', label: 'Todas'),
    _StatusFilter(value: 'critical', label: 'Crítico'),
    _StatusFilter(value: 'high', label: 'Alto'),
    _StatusFilter(value: 'medium', label: 'Médio'),
    _StatusFilter(value: 'low', label: 'Baixo'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  void _loadTickets() {
    _ticketsFuture = SupportTicketService.fetchTickets(
      status: _status,
      type: _type,
      severity: _severity,
    );
  }

  Future<void> _refresh() async {
    setState(_loadTickets);
    await _ticketsFuture;
  }

  Future<void> _changeStatus(
    SupportTicket ticket,
    String status, {
    String? reply,
  }) async {
    try {
      await SupportTicketService.updateTicketStatus(
        ticketId: ticket.id,
        status: status,
        reply: reply,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback marcado como ${_statusLabel(status)}.'),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(_loadTickets);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não consegui atualizar: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTicketDetails(SupportTicket ticket) {
    final replyController = TextEditingController(
      text: ticket.adminReplyMessage,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111118),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.typeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Pill(
                      label: ticket.statusLabel,
                      color: _statusColor(ticket.status),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ticket.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                _SupportMessageTimeline(ticket: ticket),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.person_rounded,
                  label: 'Usuário',
                  value: ticket.userName,
                ),
                _DetailRow(
                  icon: Icons.mail_rounded,
                  label: 'E-mail',
                  value: '${ticket.user['email'] ?? 'Não informado'}',
                ),
                _DetailRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Aparelho',
                  value: ticket.deviceLabel,
                ),
                _DetailRow(
                  icon: Icons.apps_rounded,
                  label: 'App',
                  value:
                      '${ticket.app['version'] ?? '-'}+${ticket.app['build_number'] ?? '-'}',
                ),
                _DetailRow(
                  icon: Icons.dashboard_rounded,
                  label: 'Tela',
                  value: ticket.screen ?? 'Não informada',
                ),
                _DetailRow(
                  icon: Icons.flag_rounded,
                  label: 'Prioridade',
                  value: ticket.severityLabel,
                ),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Criado',
                  value: _formatDate(ticket.createdAt),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replyController,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1200,
                  style: const TextStyle(color: Colors.white, height: 1.35),
                  cursorColor: Colors.blueAccent,
                  decoration: InputDecoration(
                    labelText: 'Resposta para o usuário',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    hintText:
                        'Ex: obrigado pelo aviso. Corrigimos isso na versão 1.1.1.',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    counterStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: ticket.status == 'open'
                            ? null
                            : () => _changeStatus(
                                ticket,
                                'open',
                                reply: replyController.text,
                              ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reabrir'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: ticket.status == 'resolved'
                            ? null
                            : () => _changeStatus(
                                ticket,
                                'resolved',
                                reply: replyController.text,
                              ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Resolver'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: ticket.status == 'closed'
                        ? null
                        : () => _changeStatus(
                            ticket,
                            'closed',
                            reply: replyController.text,
                          ),
                    icon: const Icon(Icons.archive_rounded),
                    label: const Text('Fechar sem ação'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(replyController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
        ),
        title: const Text(
          'Central de Suporte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Feedbacks enviados pela equipe',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
            SizedBox(
              height: 44,
              child: _FilterStrip(
                filters: _statusFilters,
                selected: _status,
                onSelected: (value) {
                  setState(() {
                    _status = value;
                    _loadTickets();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: _FilterStrip(
                filters: _typeFilters,
                selected: _type,
                onSelected: (value) {
                  setState(() {
                    _type = value;
                    _loadTickets();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: _FilterStrip(
                filters: _severityFilters,
                selected: _severity,
                onSelected: (value) {
                  setState(() {
                    _severity = value;
                    _loadTickets();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<SupportTicket>>(
                future: _ticketsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _EmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Não consegui carregar',
                      message: '${snapshot.error}',
                      action: 'Tentar novamente',
                      onTap: _refresh,
                    );
                  }

                  final tickets = snapshot.data ?? const <SupportTicket>[];

                  if (tickets.isEmpty) {
                    return _EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'Nada por aqui',
                      message:
                          'Quando alguém enviar feedback, ele aparece nesta central.',
                      action: 'Atualizar',
                      onTap: _refresh,
                    );
                  }

                  return RefreshIndicator(
                    color: Colors.blueAccent,
                    backgroundColor: const Color(0xFF16161E),
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemBuilder: (context, index) {
                        final ticket = tickets[index];
                        return _TicketCard(
                          ticket: ticket,
                          onTap: () => _showTicketDetails(ticket),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemCount: tickets.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'resolved' => const Color(0xFF22C55E),
      'closed' => Colors.grey,
      _ => Colors.blueAccent,
    };
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'resolved' => 'resolvido',
      'closed' => 'fechado',
      _ => 'aberto',
    };
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Não informado';
    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = ticket.message.length > 110
        ? '${ticket.message.substring(0, 110)}...'
        : ticket.message;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(
                  label: ticket.typeLabel,
                  color: ticket.severity == 'critical'
                      ? Colors.redAccent
                      : Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                _Pill(
                  label: ticket.statusLabel,
                  color: _SupportCenterScreenState._statusColor(ticket.status),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              preview,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.userName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _SupportCenterScreenState._formatDate(ticket.createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<_StatusFilter> filters;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final filter = filters[index];
        final isSelected = filter.value == selected;

        return ChoiceChip(
          selected: isSelected,
          label: Text(filter.label),
          selectedColor: Colors.blueAccent,
          backgroundColor: const Color(0xFF16161E),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontWeight: FontWeight.w800,
          ),
          side: BorderSide(
            color: isSelected
                ? Colors.blueAccent
                : Colors.white.withValues(alpha: 0.08),
          ),
          onSelected: (_) => onSelected(filter.value),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemCount: filters.length,
    );
  }
}

class _SupportMessageTimeline extends StatelessWidget {
  const _SupportMessageTimeline({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.forum_rounded, color: Colors.blueAccent, size: 19),
              SizedBox(width: 8),
              Text(
                'Conversa',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ticket.messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TimelineMessage(message: message),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMessage extends StatelessWidget {
  const _TimelineMessage({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final sender = message.isAdmin ? 'Suporte' : 'Usuário';
    final color = message.isAdmin ? Colors.blueAccent : Colors.white70;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sender,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message.message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 72),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(action),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilter {
  const _StatusFilter({required this.value, required this.label});

  final String value;
  final String label;
}
