import 'package:cifra_band/core/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.initialType,
    this.initialScreen,
    this.initialMessage,
  });

  final String? initialType;
  final String? initialScreen;
  final String? initialMessage;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _messageController = TextEditingController();
  String _selectedType = 'bug';
  String _selectedScreen = 'Cifra';
  bool _isSending = false;

  static const _types = [
    _FeedbackOption(
      value: 'bug',
      label: 'Bug',
      icon: Icons.bug_report_rounded,
      severity: 'high',
    ),
    _FeedbackOption(
      value: 'wrong_chord',
      label: 'Cifra errada',
      icon: Icons.music_off_rounded,
      severity: 'critical',
    ),
    _FeedbackOption(
      value: 'notification',
      label: 'Notificação',
      icon: Icons.notifications_off_rounded,
      severity: 'high',
    ),
    _FeedbackOption(
      value: 'update',
      label: 'Atualização',
      icon: Icons.system_update_alt_rounded,
      severity: 'high',
    ),
    _FeedbackOption(
      value: 'question',
      label: 'Dúvida',
      icon: Icons.help_rounded,
      severity: 'medium',
    ),
    _FeedbackOption(
      value: 'suggestion',
      label: 'Sugestão',
      icon: Icons.lightbulb_rounded,
      severity: 'low',
    ),
  ];

  static const _screens = [
    'Cifra',
    'Busca',
    'Escalas',
    'Setlists',
    'Perfil',
    'Notificações',
    'Atualização',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    final type = widget.initialType;
    final screen = widget.initialScreen;
    if (type != null && _types.any((item) => item.value == type)) {
      _selectedType = type;
    }
    if (screen != null && _screens.contains(screen)) {
      _selectedScreen = screen;
    }
    _messageController.text = widget.initialMessage ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final option = _types.firstWhere((item) => item.value == _selectedType);
    setState(() => _isSending = true);

    try {
      final ticketId = await FeedbackService.submitFeedback(
        type: option.value,
        severity: option.severity,
        message: _messageController.text,
        screen: _selectedScreen,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback enviado. Código: ${ticketId.substring(0, 6)}',
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não consegui enviar agora: $error'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _messageController.text.trim().length >= 8 && !_isSending;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Enviar feedback',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _messageController,
          builder: (context, _) {
            final activeCanSend =
                _messageController.text.trim().length >= 8 && !_isSending;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                const Text(
                  'O que aconteceu?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Conte o problema ou ideia. O app envia junto a versão, build e modelo do aparelho.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _types.map((option) {
                    final selected = option.value == _selectedType;
                    return _FeedbackChip(
                      option: option,
                      selected: selected,
                      onTap: () => setState(() => _selectedType = option.value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Tela',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedScreen,
                      dropdownColor: const Color(0xFF16161E),
                      iconEnabledColor: Colors.white70,
                      isExpanded: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      items: _screens
                          .map(
                            (screen) => DropdownMenuItem(
                              value: screen,
                              child: Text(screen),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedScreen = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _messageController,
                  minLines: 7,
                  maxLines: 10,
                  maxLength: 1200,
                  style: const TextStyle(color: Colors.white, height: 1.35),
                  cursorColor: Colors.blueAccent,
                  decoration: InputDecoration(
                    hintText:
                        'Ex: pesquisei Galileu, abri a cifra e o acorde apareceu fora da linha...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: const Color(0xFF16161E),
                    counterStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: activeCanSend ? _sendFeedback : null,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSending ? 'Enviando...' : 'Enviar feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    disabledBackgroundColor: const Color(0xFF252532),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (!canSend) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Escreva pelo menos 8 caracteres para enviar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _FeedbackOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.blueAccent : const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.blueAccent
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackOption {
  const _FeedbackOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.severity,
  });

  final String value;
  final String label;
  final IconData icon;
  final String severity;
}
