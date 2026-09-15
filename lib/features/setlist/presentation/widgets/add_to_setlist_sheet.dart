import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/personal_setlist_service.dart';
import '../../../songs/data/models/song_model.dart';

class AddToSetlistSheet extends StatefulWidget {
  const AddToSetlistSheet({super.key, required this.song});
  final SongModel song;
  @override
  State<AddToSetlistSheet> createState() => _AddToSetlistSheetState();
}

class _AddToSetlistSheetState extends State<AddToSetlistSheet> {
  late Future<QuerySnapshot<Map<String, dynamic>>> _lists;
  bool _saving = false;
  String? _error;
  final _name = TextEditingController();
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _lists = uid == null
        ? Future.error(
            StateError('Entre na sua conta para adicionar à setlist.'),
          )
        : FirebaseFirestore.instance
              .collection('setlists')
              .where(
                Filter.or(
                  Filter('ownerId', isEqualTo: uid),
                  Filter('sharedWith', arrayContains: uid),
                ),
              )
              .get()
              .timeout(const Duration(seconds: 20));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(String id) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final added = await PersonalSetlistService.addSong(id, widget.song);
      if (mounted) {
        Navigator.pop(
          context,
          added
              ? 'Cifra adicionada à setlist.'
              : 'Esta versão já está na setlist.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Não foi possível salvar. Verifique seu acesso e tente novamente.';
        });
      }
    }
  }

  Future<void> _create() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_saving || uid == null || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ref = FirebaseFirestore.instance.collection('setlists').doc();
      await ref.set({
        'title': _name.text.trim(),
        'ownerId': uid,
        'sharedWith': [],
        'songIds': [],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      if (!mounted) return;
      _saving = false;
      _name.clear();
      _reload();
      await _save(ref.id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível criar a setlist.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: math.min(
            MediaQuery.sizeOf(context).height * .55,
            math.max(
              0,
              MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom -
                  100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adicionar à setlist',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              if (_saving) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              Expanded(
                child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  future: _lists,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: _saving ? null : () => setState(_reload),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Recarregar setlists'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma setlist criada.'),
                      );
                    }
                    return ListView(
                      children: [
                        for (final doc in docs)
                          ListTile(
                            leading: const Icon(Icons.queue_music),
                            title: Text(
                              doc.data()['title']?.toString() ?? 'Setlist',
                            ),
                            trailing: const Icon(Icons.add),
                            enabled: !_saving,
                            onTap: () => _save(doc.id),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Nova setlist',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _create(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Criar setlist e adicionar',
                    onPressed: _saving ? null : _create,
                    icon: const Icon(Icons.playlist_add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
