import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/home_providers.dart';

class RehearsalCenterScreen extends ConsumerStatefulWidget {
  const RehearsalCenterScreen({super.key});
  @override
  ConsumerState<RehearsalCenterScreen> createState() =>
      _RehearsalCenterScreenState();
}

class _RehearsalCenterScreenState extends ConsumerState<RehearsalCenterScreen> {
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  bool _past = false;
  int _limit = 30;
  String? _church;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;

  void _load(String church) {
    _church = church;
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('schedules')
        .where('church_id', isEqualTo: church);
    query = _past
        ? query.where('date', isLessThan: Timestamp.fromDate(_today))
        : query.where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(_today),
          );
    _stream = query
        .orderBy('date', descending: _past)
        .limit(_limit)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Central de ensaios')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(userProfileProvider),
            child: const Text('Recarregar perfil'),
          ),
        ),
        data: (data) {
          final church = data?['church_id']?.toString() ?? '';
          if (church.isEmpty) {
            return const Center(
              child: Text('Você ainda não participa de um ministério.'),
            );
          }
          if (_church != church) {
            _limit = 30;
            _load(church);
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Próximos')),
                    ButtonSegment(value: true, label: Text('Anteriores')),
                  ],
                  selected: {_past},
                  onSelectionChanged: (value) => setState(() {
                    _past = value.single;
                    _limit = 30;
                    _load(church);
                  }),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  key: ValueKey('$church/$_past'),
                  stream: _stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Não foi possível carregar os ensaios.'),
                            TextButton.icon(
                              onPressed: () => setState(() => _load(church)),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          _past
                              ? 'Nenhum culto anterior.'
                              : 'Nenhum culto programado.',
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: docs.length + (docs.length == _limit ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index == docs.length) {
                          return TextButton(
                            onPressed: () => setState(() {
                              _limit += 30;
                              _load(church);
                            }),
                            child: const Text('Carregar mais'),
                          );
                        }
                        final event = docs[index].data();
                        final rawDate = event['date'];
                        final date = rawDate is Timestamp
                            ? rawDate.toDate()
                            : null;
                        final songs = (event['approved_songs'] as List?) ?? [];
                        final dateLabel = date == null
                            ? 'Data não informada'
                            : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                        return ListTile(
                          leading: const Icon(
                            Icons.queue_music,
                            color: Colors.greenAccent,
                          ),
                          title: Text(event['title']?.toString() ?? 'Culto'),
                          subtitle: Text(
                            '$dateLabel · ${songs.length} músicas aprovadas',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/event',
                            extra: {
                              'scheduleId': docs[index].id,
                              'isAdmin': data?['is_admin'] == true,
                              'initialTab': 2,
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
