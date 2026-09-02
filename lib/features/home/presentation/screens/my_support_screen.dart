import 'package:cifra_band/core/services/support_ticket_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MySupportScreen extends StatefulWidget {
  const MySupportScreen({super.key});

  @override
  State<MySupportScreen> createState() => _MySupportScreenState();
}

class _MySupportScreenState extends State<MySupportScreen> {
  late Future<MySupportTicketsResult> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = SupportTicketService.fetchMyTickets();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _openFeedback() async {
    await context.push('/feedback');
    if (mounted) setState(_load);
  }

  Future<void> _changeTicketStatus(SupportTicket ticket, String status) async {
    try {
      await SupportTicketService.updateMyTicketStatus(
        ticketId: ticket.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'open'
                ? 'Chamado reaberto para o suporte.'
                : 'Obrigado! Chamado marcado como resolvido.',
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(_load);
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
          'Meu Suporte',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<MySupportTicketsResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            }

            if (snapshot.hasError) {
              return _SupportEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Não consegui carregar',
                message: '${snapshot.error}',
                action: 'Tentar novamente',
                onTap: _refresh,
              );
            }

            final result =
                snapshot.data ??
                const MySupportTicketsResult(
                  tickets: <SupportTicket>[],
                  canCreateNew: true,
                );

            return RefreshIndicator(
              color: Colors.blueAccent,
              backgroundColor: const Color(0xFF16161E),
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    result.canCreateNew
                        ? 'Precisa de ajuda?'
                        : 'Aguardando resposta',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.canCreateNew
                        ? 'Envie um bug, dúvida, cifra errada ou sugestão.'
                        : 'Você já tem um feedback aberto. Assim que o suporte responder, você pode enviar outro.',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: result.canCreateNew ? _openFeedback : null,
                      icon: const Icon(Icons.add_comment_rounded),
                      label: const Text('Enviar novo feedback'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: const Color(0xFF252532),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'MEUS CHAMADOS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (result.tickets.isEmpty)
                    const _SupportEmptyCard()
                  else
                    ...result.tickets.map(
                      (ticket) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MyTicketCard(
                          ticket: ticket,
                          onResolve: () =>
                              _changeTicketStatus(ticket, 'resolved'),
                          onReopen: () => _changeTicketStatus(ticket, 'open'),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MyTicketCard extends StatelessWidget {
  const _MyTicketCard({
    required this.ticket,
    required this.onResolve,
    required this.onReopen,
  });

  final SupportTicket ticket;
  final VoidCallback onResolve;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (ticket.status) {
      'resolved' => const Color(0xFF22C55E),
      'closed' => Colors.grey,
      _ => Colors.blueAccent,
    };

    return Container(
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
              _Pill(label: ticket.typeLabel, color: Colors.blueAccent),
              const SizedBox(width: 8),
              _Pill(label: ticket.statusLabel, color: statusColor),
              const Spacer(),
              Text(
                _formatDate(ticket.createdAt),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ticket.message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _ConversationTimeline(ticket: ticket),
          if (ticket.canUserResolve || ticket.canUserReopen) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (ticket.canUserResolve)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Resolveu'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (ticket.canUserResolve && ticket.canUserReopen)
                  const SizedBox(width: 10),
                if (ticket.canUserReopen)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReopen,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Ainda preciso'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('dd/MM HH:mm').format(value.toLocal());
  }
}

class _ConversationTimeline extends StatelessWidget {
  const _ConversationTimeline({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final messages = ticket.messages;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ticket.hasAdminReply
            ? const Color(0xFF10233A)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ticket.hasAdminReply
                    ? Icons.mark_chat_read_rounded
                    : Icons.hourglass_top_rounded,
                color: ticket.hasAdminReply
                    ? Colors.blueAccent
                    : Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                ticket.hasAdminReply
                    ? 'Conversa do chamado'
                    : 'Ainda sem resposta',
                style: TextStyle(
                  color: ticket.hasAdminReply
                      ? Colors.white
                      : Colors.grey.shade400,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!ticket.hasAdminReply)
            Text(
              'O suporte vai responder por aqui.',
              style: TextStyle(color: Colors.grey.shade500, height: 1.35),
            )
          else
            ...messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MessageBubble(message: message),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final color = message.isAdmin ? Colors.blueAccent : Colors.white70;
    final label = message.isAdmin ? 'Suporte' : 'Você';

    return Column(
      crossAxisAlignment: message.isAdmin
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: message.isAdmin
                ? Colors.blueAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
        ),
      ],
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

class _SupportEmptyCard extends StatelessWidget {
  const _SupportEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        'Você ainda não enviou nenhum feedback.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade500, height: 1.35),
      ),
    );
  }
}

class _SupportEmptyState extends StatelessWidget {
  const _SupportEmptyState({
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
