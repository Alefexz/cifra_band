import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cifra_band/core/services/rehearsal_preparation.dart';
import 'package:cifra_band/core/services/rehearsal_service.dart';

class RehearsalPanel extends StatefulWidget {
  const RehearsalPanel({
    super.key,
    required this.scheduleId,
    required this.songs,
    required this.assignments,
    required this.openSong,
  });
  final String scheduleId;
  final List<Map<String, dynamic>> songs;
  final List<dynamic> assignments;
  final ValueChanged<Map<String, dynamic>> openSong;

  @override
  State<RehearsalPanel> createState() => _RehearsalPanelState();
}

class _RehearsalPanelState extends State<RehearsalPanel> {
  late Stream<Map<String, RehearsalPreparation>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = RehearsalService.watchTeam(widget.scheduleId);
  }

  @override
  void didUpdateWidget(covariant RehearsalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleId != widget.scheduleId) {
      _stream = RehearsalService.watchTeam(widget.scheduleId);
    }
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<Map<String, RehearsalPreparation>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar o ensaio.'),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _stream = RehearsalService.watchTeam(widget.scheduleId);
                    }),
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
          return RehearsalBoard(
            songs: widget.songs,
            members: RehearsalMember.fromAssignments(widget.assignments),
            statuses: snapshot.data!,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
            openSong: widget.openSong,
            edit: (song, current) => showPreparationEditor(
              context,
              song: song,
              current: current,
              save: (stage, note) => RehearsalService.savePreparation(
                scheduleId: widget.scheduleId,
                song: song,
                stage: stage,
                note: note,
              ),
            ),
          );
        },
      );
}

class RehearsalBoard extends StatelessWidget {
  const RehearsalBoard({
    super.key,
    required this.songs,
    required this.members,
    required this.statuses,
    required this.currentUid,
    required this.openSong,
    required this.edit,
  });
  final List<Map<String, dynamic>> songs;
  final List<RehearsalMember> members;
  final Map<String, RehearsalPreparation> statuses;
  final String currentUid;
  final ValueChanged<Map<String, dynamic>> openSong;
  final void Function(Map<String, dynamic>, RehearsalPreparation) edit;

  static Color stageColor(PreparationStage stage) => switch (stage) {
    PreparationStage.ready => Colors.greenAccent,
    PreparationStage.needsHelp => Colors.orangeAccent,
    PreparationStage.needsReview => Colors.amber,
    PreparationStage.studying => Colors.lightBlueAccent,
    PreparationStage.pending => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma música aprovada para este ensaio.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: songs.length,
      separatorBuilder: (_, _) => const Divider(height: 32),
      itemBuilder: (context, index) {
        final song = songs[index];
        final title = song['title']?.toString() ?? 'Música';
        final artist = song['artist']?.toString() ?? '';
        final key = RehearsalService.songKey(title, artist);
        final own =
            statuses['${currentUid}_$key'] ?? const RehearsalPreparation();
        final ready = members
            .where(
              (member) =>
                  statuses['${member.uid}_$key']?.forSong(song) ==
                  PreparationStage.ready,
            )
            .length;
        final tone = song['originalKey'] ?? song['key'] ?? 'Não informado';
        final instruction = song['rehearsalNotes']?.toString().trim() ?? '';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('$artist · Tom: $tone'),
              trailing: IconButton(
                tooltip: 'Abrir cifra',
                icon: const Icon(Icons.library_music_outlined),
                onPressed: () => openSong(song),
              ),
            ),
            if (instruction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(instruction),
              ),
            Text(
              members.isEmpty
                  ? 'Equipe ainda não definida'
                  : '$ready de ${members.length} integrantes preparados',
              style: TextStyle(
                color: ready == members.length && members.isNotEmpty
                    ? Colors.greenAccent
                    : Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: members.isEmpty ? 0 : ready / members.length,
              color: Colors.greenAccent,
              backgroundColor: Colors.white12,
            ),
            for (final member in members) ...[
              const SizedBox(height: 12),
              _MemberPreparation(
                member: member,
                preparation:
                    statuses['${member.uid}_$key'] ??
                    const RehearsalPreparation(),
                song: song,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: currentUid.isEmpty ? null : () => edit(song, own),
              icon: const Icon(Icons.edit_note),
              label: Text(
                'Minha preparação: ${own.forSong(song).label}',
                textAlign: TextAlign.center,
              ),
            ),
            if (own.note.isNotEmpty &&
                !members.any((member) => member.uid == currentUid))
              Text(own.note),
          ],
        );
      },
    );
  }
}

class _MemberPreparation extends StatelessWidget {
  const _MemberPreparation({
    required this.member,
    required this.preparation,
    required this.song,
  });
  final RehearsalMember member;
  final RehearsalPreparation preparation;
  final Map<String, dynamic> song;
  @override
  Widget build(BuildContext context) {
    final stage = preparation.forSong(song);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${member.name} · ${member.roles.join(', ')}'),
        Text(
          stage.label,
          style: TextStyle(color: RehearsalBoard.stageColor(stage)),
        ),
        if (preparation.note.isNotEmpty)
          Text(preparation.note, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

Future<void> showPreparationEditor(
  BuildContext context, {
  required Map<String, dynamic> song,
  required RehearsalPreparation current,
  required Future<void> Function(PreparationStage?, String) save,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PreparationEditor(song: song, current: current, save: save),
);

class _PreparationEditor extends StatefulWidget {
  const _PreparationEditor({
    required this.song,
    required this.current,
    required this.save,
  });
  final Map<String, dynamic> song;
  final RehearsalPreparation current;
  final Future<void> Function(PreparationStage?, String) save;
  @override
  State<_PreparationEditor> createState() => _PreparationEditorState();
}

class _PreparationEditorState extends State<_PreparationEditor> {
  late final TextEditingController _note = TextEditingController(
    text: widget.current.note,
  );
  PreparationStage? _changed;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_note.text.trim().length > 1500) {
      setState(() => _error = 'A observação deve ter até 1500 caracteres.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_changed, _note.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Não foi possível salvar. Verifique sua conexão e reabra o ensaio se o repertório mudou.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final effective = _changed ?? widget.current.forSong(widget.song);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.song['title']?.toString() ?? 'Preparação'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (effective == PreparationStage.needsReview)
                  const Text(
                    'Arranjo alterado ou preparação antiga sem confirmação de versão.',
                  ),
                DropdownButtonFormField<PreparationStage>(
                  initialValue: effective == PreparationStage.needsReview
                      ? null
                      : effective,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Preparação'),
                  items: [
                    for (final stage in PreparationStage.values)
                      if (stage != PreparationStage.needsReview)
                        DropdownMenuItem(
                          value: stage,
                          child: Text(stage.label),
                        ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _changed = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  enabled: !_saving,
                  maxLength: 1500,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Observação para a equipe',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando...' : 'Salvar'),
          ),
        ],
      ),
    );
  }
}
