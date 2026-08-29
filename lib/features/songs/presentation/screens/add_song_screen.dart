// lib/features/songs/presentation/screens/add_song_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:cifra_band/core/services/api_notification.dart';
import '../../../songs/domain/entities/song_entity.dart';
import '../../../songs/presentation/providers/song_providers.dart';

class AddSongScreen extends ConsumerStatefulWidget {
  final String setlistId;
  const AddSongScreen({super.key, required this.setlistId});

  @override
  ConsumerState<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends ConsumerState<AddSongScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadingTrack;
  List<dynamic> _songs = [];
  SongEntity? _songReady;

  String _selectedKey = 'C';
  String _selectedCapo = '0';

  final List<String> _musicalKeys = [
    'C',
    'C#',
    'Db',
    'D',
    'D#',
    'Eb',
    'E',
    'F',
    'F#',
    'Gb',
    'G',
    'G#',
    'Ab',
    'A',
    'A#',
    'Bb',
    'B',
  ];
  final List<String> _capoOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  Future<void> _performSearch(String query) async {
    final search = query.trim();
    if (search.isEmpty) {
      if (!mounted) return;
      setState(() {
        _songs = [];
        _isLoading = false;
        _songReady = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _songReady = null;
    });
    try {
      final url = Uri.https('itunes.apple.com', '/search', {
        'term': search,
        'entity': 'song',
        'limit': '15',
        'country': 'br',
        'media': 'music',
      });
      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200)
        throw Exception('Apple Search retornou ${response.statusCode}.');

      final dynamic decoded = json.decode(response.body);
      final dynamic results = decoded['results'];

      if (!mounted) return;
      setState(() => _songs = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _songs = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao pesquisar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
    setState(() {});
  }

  Future<void> _onSongSelected(String track, String artist) async {
    if (_loadingTrack != null) return;
    if (!mounted) return;
    setState(() => _loadingTrack = track);

    try {
      final uri = Uri.https('cifraband-api.onrender.com', '/searchSong', {
        'artist': artist.trim(),
        'track': track.trim(),
      });
      final repository = ref.read(songRepositoryProvider);
      final SongEntity songEntity = await repository.extractSongFromUrl(
        uri.toString(),
      );

      if (!mounted) return;
      setState(() {
        _songReady = songEntity;
        _loadingTrack = null;

        if (_musicalKeys.contains(songEntity.originalKey)) {
          _selectedKey = songEntity.originalKey;
        } else {
          _selectedKey = 'C';
        }

        if (songEntity.capo != null && _capoOptions.contains(songEntity.capo)) {
          _selectedCapo = songEntity.capo!;
        } else {
          _selectedCapo = '0';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTrack = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao buscar cifra:\n$e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _addToSetlistOrSchedule() async {
    final song = _songReady;
    if (song == null) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Usuário não logado');

      final scheduleDoc = await FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.setlistId)
          .get();

      if (scheduleDoc.exists) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? 'Membro';

        // ⚠️ AQUI ESTÁ A CORREÇÃO: AGORA ELE SALVA A CIFRA (CONTENT) JUNTO COM OS VOTOS
        final songMap = {
          'title': song.title,
          'artist': song.artist,
          'key': _selectedKey,
          'capo': _selectedCapo,
          'originalKey': song.originalKey,
          'shapeKey': song.shapeKey,
          'content': song.content, // A CIFRA SALVA AQUI!
          'url': song.url,
          'suggestedBy': userName,
          'upvotes': [currentUser.uid],
          'downvotes': [],
        };

        await FirebaseFirestore.instance
            .collection('schedules')
            .doc(widget.setlistId)
            .update({
              'suggested_songs': FieldValue.arrayUnion([songMap]),
            });

        final scheduleData = scheduleDoc.data();
        final teamAssignments = List<dynamic>.from(
          scheduleData?['team_assignments'] ?? [],
        );
        final teamUids = teamAssignments
            .map(
              (assignment) =>
                  assignment is Map<String, dynamic> ? assignment['uid'] : null,
            )
            .whereType<String>()
            .toSet()
            .toList();

        await ApiNotification.notificarMusicaNova(
          teamUids,
          song.title,
          userName,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Música sugerida para o culto com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        final songDocRef = await FirebaseFirestore.instance
            .collection('songs')
            .add({
              'title': song.title,
              'artist': song.artist,
              'key': _selectedKey,
              'originalKey': song.originalKey,
              'shapeKey': song.shapeKey,
              'capo': _selectedCapo,
              'content': song.content,
              'url': song.url,
              'created_by': currentUser.uid,
              'created_at': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('setlists')
            .doc(widget.setlistId)
            .update({
              'songIds': FieldValue.arrayUnion([songDocRef.id]),
            });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Música adicionada à setlist com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar música:\n$e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _songReady != null
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => _songReady = null),
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
        title: Text(
          _songReady != null ? 'Revisar Cifra' : 'Buscar Música',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: _songReady != null ? _buildCifraView() : _buildSearchLayout(),
    );
  }

  Widget _buildSearchLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar(),
        const SizedBox(height: 20),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : _songs.isEmpty
              ? _buildEmptyState()
              : _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Buscar artista ou música...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Colors.blueAccent,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      setState(() {
                        _songs = [];
                        _isLoading = false;
                        _songReady = null;
                      });
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF1A1A24),
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A24),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.graphic_eq_rounded,
                size: 48,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pronto para tocar?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesquise uma música para baixar a cifra\ne sugerir para o repertório.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final topResult = _songs.first;
    final otherSongs = _songs.length > 1 ? _songs.sublist(1) : <dynamic>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUGESTÃO PRINCIPAL',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildTopResultCard(topResult),
          if (otherSongs.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'OUTROS RESULTADOS',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            ...otherSongs.map((song) => _buildSongCard(song)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopResultCard(dynamic song) {
    final imageUrl =
        (song['artworkUrl100'] as String?)?.replaceAll(
          '100x100bb',
          '300x300bb',
        ) ??
        '';
    final trackName = song['trackName'] ?? 'Desconhecido';
    final artistName = song['artistName'] ?? 'Desconhecido';
    final isLoadingThis = _loadingTrack == trackName;

    return GestureDetector(
      onTap: isLoadingThis
          ? null
          : () => _onSongSelected(trackName.toString(), artistName.toString()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A24), Color(0xFF121218)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 88,
                      height: 88,
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackName.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        artistName.toString(),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoadingThis
                    ? null
                    : () => _onSongSelected(
                        trackName.toString(),
                        artistName.toString(),
                      ),
                icon: isLoadingThis
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.blueAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  isLoadingThis ? 'Buscando cifra...' : 'Revisar Cifra',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.15),
                  foregroundColor: Colors.blueAccent,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard(dynamic song) {
    final imageUrl = song['artworkUrl100'] ?? '';
    final trackName = song['trackName'] ?? 'Desconhecido';
    final artistName = song['artistName'] ?? 'Desconhecido';
    final isLoadingThis = _loadingTrack == trackName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            imageUrl.toString(),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 48,
              height: 48,
              color: Colors.grey.shade800,
              child: const Icon(
                Icons.music_note,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          trackName.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          artistName.toString(),
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            shape: BoxShape.circle,
          ),
          child: isLoadingThis
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.blueAccent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _onSongSelected(
                    trackName.toString(),
                    artistName.toString(),
                  ),
                ),
        ),
        onTap: isLoadingThis
            ? null
            : () =>
                  _onSongSelected(trackName.toString(), artistName.toString()),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1A24),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.blueAccent,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCifraView() {
    final song = _songReady!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${song.title} - ${song.artist}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Qual o Tom?',
                  value: _selectedKey,
                  items: _musicalKeys,
                  onChanged: (val) => setState(() => _selectedKey = val!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdown(
                  label: 'Qual a Casa do Capo?',
                  value: _selectedCapo,
                  items: _capoOptions,
                  onChanged: (val) => setState(() => _selectedCapo = val!),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  song.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _addToSetlistOrSchedule,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _isSaving ? 'Salvando...' : 'Confirmar e Sugerir',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
