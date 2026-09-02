import 'package:cifra_band/core/services/official_library_service.dart';
import 'package:cifra_band/features/songs/data/models/song_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class OfficialSongEditorScreen extends StatefulWidget {
  const OfficialSongEditorScreen({super.key, this.initialSong});

  final Object? initialSong;

  @override
  State<OfficialSongEditorScreen> createState() =>
      _OfficialSongEditorScreenState();
}

class _OfficialSongEditorScreenState extends State<OfficialSongEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late final TextEditingController _key;
  late final TextEditingController _shapeKey;
  late final TextEditingController _capo;
  late final TextEditingController _bpm;
  late final TextEditingController _reference;
  late final TextEditingController _notes;
  late final TextEditingController _content;

  String? _existingId;
  bool _saving = false;
  OfficialSongValidation? _validation;

  @override
  void initState() {
    super.initState();
    final seed = widget.initialSong;
    OfficialSong? official;
    SongModel? model;
    if (seed is OfficialSong) official = seed;
    if (seed is SongModel) model = seed;

    _existingId = official?.id;
    _title = TextEditingController(text: official?.title ?? model?.title ?? '');
    _artist = TextEditingController(
      text: official?.artist ?? model?.artist ?? '',
    );
    _key = TextEditingController(
      text: official?.originalKey ?? model?.originalKey ?? 'C',
    );
    _shapeKey = TextEditingController(
      text: official?.shapeKey ?? model?.shapeKey ?? '',
    );
    _capo = TextEditingController(text: official?.capo ?? model?.capo ?? '');
    _bpm = TextEditingController(text: official?.bpm ?? model?.bpm ?? '');
    _reference = TextEditingController(
      text: official?.referenceUrl ?? model?.referenceUrl ?? '',
    );
    _notes = TextEditingController(
      text: official?.rehearsalNotes ?? model?.rehearsalNotes ?? '',
    );
    _content = TextEditingController(
      text: official?.content ?? model?.content ?? '',
    );
    _validate();
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _key.dispose();
    _shapeKey.dispose();
    _capo.dispose();
    _bpm.dispose();
    _reference.dispose();
    _notes.dispose();
    _content.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _validation = OfficialLibraryService.validateContent(_content.text);
    });
  }

  Future<void> _detectFromPaste() async {
    var raw = _content.text;
    if (raw.trim().isEmpty) {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      raw = clipboard?.text ?? '';
    }
    if (raw.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cole uma cifra primeiro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final draft = OfficialLibraryService.parseImportedText(raw);
    setState(() {
      if (_title.text.trim().isEmpty || _title.text == 'Nova cifra') {
        _title.text = draft.title;
      }
      if (_artist.text.trim().isEmpty ||
          _artist.text == 'Artista nao informado') {
        _artist.text = draft.artist;
      }
      _key.text = draft.originalKey;
      _content.text = draft.content;
      _validation = OfficialLibraryService.validateContent(_content.text);
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty ||
        _artist.text.trim().isEmpty ||
        _content.text.trim().length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe titulo, artista e uma cifra valida.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await OfficialLibraryService.saveOfficialSong(
        title: _title.text,
        artist: _artist.text,
        originalKey: _key.text,
        shapeKey: _shapeKey.text,
        capo: _capo.text,
        bpm: _bpm.text,
        referenceUrl: _reference.text,
        rehearsalNotes: _notes.text,
        content: _content.text,
        existingId: _existingId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cifra oficial salva para a igreja.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao consegui salvar: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
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
        title: Text(
          _existingId == null ? 'Nova cifra oficial' : 'Editar cifra oficial',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: _field(_title, 'Titulo')),
              const SizedBox(width: 10),
              SizedBox(width: 92, child: _field(_key, 'Tom')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_artist, 'Artista'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _field(_shapeKey, 'Forma/capo ex: Am')),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: _field(_capo, 'Capo')),
              const SizedBox(width: 10),
              SizedBox(width: 90, child: _field(_bpm, 'BPM')),
            ],
          ),
          const SizedBox(height: 12),
          _field(_reference, 'Link YouTube/Spotify/referencia'),
          const SizedBox(height: 12),
          _field(_notes, 'Observacoes para ensaio', maxLines: 3),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _detectFromPaste,
                  icon: const Icon(Icons.content_paste_search_rounded),
                  label: const Text('Detectar cifra colada'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: BorderSide(
                      color: Colors.blueAccent.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _validate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: BorderSide(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 14,
                  ),
                ),
                child: const Text('Validar'),
              ),
            ],
          ),
          if (validation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: validation.isValid
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: validation.isValid
                      ? Colors.green.withValues(alpha: 0.35)
                      : Colors.orange.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                validation.isValid
                    ? '${validation.chordCount} acordes reconhecidos. Pronta para salvar.'
                    : 'Revise a cifra: ${validation.chordCount} acordes encontrados${validation.unknownTokens.isEmpty ? '' : ' / duvidosos: ${validation.unknownTokens.join(', ')}'}.',
                style: TextStyle(
                  color: validation.isValid
                      ? Colors.greenAccent
                      : Colors.orange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _content,
            onChanged: (_) => _validate(),
            minLines: 18,
            maxLines: 28,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              height: 1.35,
            ),
            cursorColor: Colors.blueAccent,
            decoration: _inputDecoration(
              'Cole ou escreva a cifra aqui',
              hint:
                  'Ex:\nTom: Am\n\n[Intro] C  Am  F7M\n\nC\nDeixou Sua gloria...',
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      cursorColor: Colors.blueAccent,
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey.shade500),
      hintStyle: TextStyle(color: Colors.grey.shade700),
      filled: true,
      fillColor: const Color(0xFF16161E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
    );
  }
}
