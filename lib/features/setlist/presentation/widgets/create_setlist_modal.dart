// lib/features/setlist/presentation/widgets/create_setlist_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/setlist_entity.dart';
import '../controllers/setlist_controller.dart';

class CreateSetlistModal extends ConsumerStatefulWidget {
  const CreateSetlistModal({super.key});

  @override
  ConsumerState<CreateSetlistModal> createState() => _CreateSetlistModalState();
}

class _CreateSetlistModalState extends ConsumerState<CreateSetlistModal> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _salvarSetlist() {
    final title = _nameController.text.trim();
    if (title.isEmpty) return; // Não deixa salvar sem nome

    // Agora sim, criamos a Setlist com o nome que o usuário digitou!
    // Ela nasce vazia (sem músicas) para adicionarmos depois.
    final novaSetlist = SetlistEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      ownerId: '',
      sharedWith: [],
      songIds: [],
      updatedAt: DateTime.now(),
    );

    ref.read(setlistControllerProvider.notifier).addSetlist(novaSetlist);
    Navigator.of(context).pop(); // Fecha a aba do formulário
  }

  @override
  Widget build(BuildContext context) {
    // Pega a margem do teclado para a aba subir junto com ele
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ocupa só o espaço necessário
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nova Setlist',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ex: Culto de Domingo',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _salvarSetlist,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black, // Letra preta no botão verde neon
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Criar Repertório',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24), // Espaço extra para ficar bonito no final
        ],
      ),
    );
  }
}
