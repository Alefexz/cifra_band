// lib/features/setlist/presentation/screens/favorite_songs_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../songs/data/models/song_model.dart'; 

class FavoriteSongsScreen extends StatefulWidget {
  const FavoriteSongsScreen({super.key});

  @override
  State<FavoriteSongsScreen> createState() => _FavoriteSongsScreenState();
}

class _FavoriteSongsScreenState extends State<FavoriteSongsScreen> {
  List<SongModel> _favoriteSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteList = prefs.getStringList('favorite_songs') ?? [];

    final List<SongModel> loadedSongs = [];
    for (String songJson in favoriteList) {
      try {
        final Map<String, dynamic> data = json.decode(songJson);
        loadedSongs.add(SongModel(
          id: data['id'] ?? '',
          title: data['title'] ?? 'Sem título',
          artist: data['artist'] ?? 'Artista desconhecido',
          originalKey: data['originalKey'] ?? '',
          content: data['content'] ?? '',
          capo: data['capo'],
          shapeKey: data['shapeKey'],
          url: data['url'] ?? '',
        ));
      } catch (e) {
        debugPrint('Erro ao decodificar cifra favorita: $e');
      }
    }

    setState(() {
      _favoriteSongs = loadedSongs;
      _isLoading = false;
    });
  }

  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteList = prefs.getStringList('favorite_songs') ?? [];

    favoriteList.removeWhere((songJson) {
      final decoded = json.decode(songJson);
      return decoded['id'] == id;
    });

    await prefs.setStringList('favorite_songs', favoriteList);
    _loadFavorites(); // Recarrega a lista
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cifra removida dos favoritos.'), backgroundColor: Colors.grey),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Cifras Favoritas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : _favoriteSongs.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.heart_broken_rounded, color: Colors.grey.shade800, size: 80),
          const SizedBox(height: 16),
          const Text('Nenhuma cifra salva offline.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'As cifras que você favoritar no Modo Palco\naparecerão aqui para tocar sem internet.', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.grey.shade500)
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: _favoriteSongs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final song = _favoriteSongs[index];
        return Container(
          decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
            ),
            title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('${song.artist} • Tom: ${song.originalKey}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
              onPressed: () => _removeFavorite(song.id),
            ),
            onTap: () {
              // Ao voltar da cifra, recarrega a lista caso o usuário tenha desmarcado o coração lá dentro
              context.push('/cifra', extra: song).then((_) {
                _loadFavorites();
              });
            },
          ),
        );
      },
    );
  }
}