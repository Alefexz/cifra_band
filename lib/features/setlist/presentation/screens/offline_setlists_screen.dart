import 'package:cifra_band/core/services/offline_setlist_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OfflineSetlistsScreen extends StatefulWidget {
  const OfflineSetlistsScreen({super.key});

  @override
  State<OfflineSetlistsScreen> createState() => _OfflineSetlistsScreenState();
}

class _OfflineSetlistsScreenState extends State<OfflineSetlistsScreen> {
  late Future<List<OfflineSetlistSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = OfflineSetlistService.listSummaries();
  }

  void _reload() {
    setState(() => _future = OfflineSetlistService.listSummaries());
  }

  Future<void> _openSetlist(OfflineSetlistSummary summary) async {
    final setlist = await OfflineSetlistService.loadCultSetlist(
      summary.scheduleId,
    );
    if (!mounted) return;

    if (setlist == null || setlist.songs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir esta setlist offline.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    context.push(
      '/cult-setlist',
      extra: {'title': setlist.title, 'songs': setlist.songs},
    );
  }

  Future<void> _deleteSetlist(OfflineSetlistSummary summary) async {
    await OfflineSetlistService.deleteCultSetlist(summary.scheduleId);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Setlist offline removida.'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D12),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Setlists Offline',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<OfflineSetlistSummary>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          final summaries = snapshot.data ?? [];
          if (summaries.isEmpty) {
            return _EmptyOfflineSetlists();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            itemCount: summaries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return _OfflineSetlistTile(
                summary: summary,
                onTap: () => _openSetlist(summary),
                onDelete: () => _deleteSetlist(summary),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyOfflineSetlists extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_done_rounded,
            color: Colors.grey.shade800,
            size: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma setlist baixada.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Abra uma escala e baixe o repertório aprovado\npara tocar mesmo sem internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _OfflineSetlistTile extends StatelessWidget {
  final OfflineSetlistSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _OfflineSetlistTile({
    required this.summary,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.offline_pin_rounded, color: Colors.green),
        ),
        title: Text(
          summary.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${summary.songCount} músicas • salvo ${_formatDate(summary.savedAt)}',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month às $hour:$minute';
  }
}
