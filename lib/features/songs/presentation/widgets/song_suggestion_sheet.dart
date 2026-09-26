import 'package:flutter/material.dart';

class SongSuggestionSheet extends StatefulWidget {
  const SongSuggestionSheet({
    super.key,
    required this.save,
    this.title = '',
    this.artist = '',
  });
  final Future<void> Function(Map<String, String>) save;
  final String title;
  final String artist;
  @override
  State<SongSuggestionSheet> createState() => _SongSuggestionSheetState();
}

class _SongSuggestionSheetState extends State<SongSuggestionSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title);
  late final _artist = TextEditingController(text: widget.artist);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save({
        'title': _title.text.trim(),
        'artist': _artist.text.trim(),
        'kind': 'listening',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível enviar. Seus dados foram mantidos; tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sugerir louvor',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Nome do louvor'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
              ),
              TextFormField(
                controller: _artist,
                enabled: !_saving,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Artista ou ministério',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o artista.' : null,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_saving ? 'Enviando...' : 'Enviar sugestão'),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        if (_form.currentState!.validate()) {
                          Navigator.pop(context, {
                            'title': _title.text.trim(),
                            'artist': _artist.text.trim(),
                          });
                        }
                      },
                icon: const Icon(Icons.library_music_outlined),
                label: const Text('Buscar cifra antes de sugerir'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
