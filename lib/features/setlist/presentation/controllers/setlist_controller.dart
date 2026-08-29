// lib/features/setlist/presentation/controllers/setlist_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/setlist_entity.dart';
import '../providers/setlist_providers.dart';

/// O Controller gerencia o ESTADO da tela (Loading, Erro ou Sucesso).
/// Usamos o AsyncNotifier, que é a ferramenta mais moderna do Riverpod.
class SetlistController extends AsyncNotifier<List<SetlistEntity>> {
  @override
  Future<List<SetlistEntity>> build() async {
    // Quando a tela carregar, ele busca as setlists automaticamente
    return _fetchSetlists();
  }

  Future<List<SetlistEntity>> _fetchSetlists() async {
    final repository = ref.read(setlistRepositoryProvider);

    return repository.getSetlistsByUser('');
  }

  // Função que a tela vai chamar quando o usuário clicar no botão "Nova Setlist"
  Future<void> addSetlist(SetlistEntity newSetlist) async {
    // 1. Coloca a tela em estado de Loading (girando a rodinha)
    state = const AsyncValue.loading();

    // 2. Tenta salvar no Firebase. O "guard" captura qualquer erro de internet automaticamente!
    state = await AsyncValue.guard(() async {
      final repository = ref.read(setlistRepositoryProvider);
      await repository.createSetlist(newSetlist);

      // 3. Busca a lista atualizada no banco
      return _fetchSetlists();
    });
  }
}

/// Provedor final que a nossa Tela vai escutar.
final setlistControllerProvider =
    AsyncNotifierProvider<SetlistController, List<SetlistEntity>>(() {
      return SetlistController();
    });
