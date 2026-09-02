import 'package:cifra_band/core/services/availability_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  bool _saving = false;

  Future<void> _addUnavailableDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
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

    if (picked == null) return;
    if (!mounted) return;

    var reasonText = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text(
          'Marcar indisponível',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          onChanged: (value) => reasonText = value,
          decoration: const InputDecoration(
            labelText: 'Motivo opcional',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonText),
            child: const Text(
              'Salvar',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );

    if (reason == null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('availability')
          .doc(AvailabilityService.dateId(picked))
          .set({
            'date': Timestamp.fromDate(
              DateTime(picked.year, picked.month, picked.day),
            ),
            'reason': reason.trim(),
            'created_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indisponibilidade salva.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar essa data.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteDate(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('availability')
        .doc(docId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final content = user == null
        ? const Center(
            child: Text(
              'Entre na sua conta para marcar datas.',
              style: TextStyle(color: Colors.white),
            ),
          )
        : _AvailabilityContent(
            userId: user.uid,
            saving: _saving,
            embedded: widget.embedded,
            onAddUnavailableDate: _addUnavailableDate,
            onDeleteDate: _deleteDate,
          );

    if (widget.embedded) {
      return ColoredBox(color: const Color(0xFF0D0D12), child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        title: const Text(
          'Minha Disponibilidade',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _addUnavailableDate,
        backgroundColor: Colors.blueAccent,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.event_busy_rounded, color: Colors.white),
        label: const Text(
          'Adicionar Data',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: content,
    );
  }
}

class _AvailabilityContent extends StatelessWidget {
  const _AvailabilityContent({
    required this.userId,
    required this.saving,
    required this.embedded,
    required this.onAddUnavailableDate,
    required this.onDeleteDate,
  });

  final String userId;
  final bool saving;
  final bool embedded;
  final VoidCallback onAddUnavailableDate;
  final ValueChanged<String> onDeleteDate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('availability')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        return ListView(
          padding: EdgeInsets.fromLTRB(20, embedded ? 18 : 20, 20, 96),
          physics: const BouncingScrollPhysics(),
          children: [
            if (embedded) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_busy_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Minha disponibilidade',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bloqueie datas em que você não pode tocar.',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: saving ? null : onAddUnavailableDate,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Data'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 72),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      color: Colors.grey.shade700,
                      size: 64,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Nenhuma data bloqueada',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quando você marcar uma data aqui, o líder não vai te escalar naquele culto.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final date = data['date'] is Timestamp
                    ? (data['date'] as Timestamp).toDate()
                    : DateTime.tryParse(doc.id);
                final formattedDate = date == null
                    ? doc.id
                    : _formatAvailabilityDate(date);
                final reason = data['reason']?.toString().trim() ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16161E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.event_busy_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (reason.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  reason,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDeleteDate(doc.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

String _formatAvailabilityDate(DateTime date) {
  const weekdays = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year} · ${weekdays[date.weekday - 1]}';
}
