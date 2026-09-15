import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cifra_band/features/home/presentation/providers/home_providers.dart';
import '../../domain/entities/setlist_entity.dart';
import '../providers/setlist_providers.dart';

class SetlistController extends StreamNotifier<List<SetlistEntity>> {
  @override
  Stream<List<SetlistEntity>> build() {
    final user = ref.watch(authUserProvider).value;
    if (user == null) return Stream.value([]);
    // Riverpod cancels the old subscription when the authenticated user changes.
    return ref.watch(setlistRepositoryProvider).watchSetlistsByUser(user.uid);
  }

  Future<void> addSetlist(SetlistEntity newSetlist) async {
    await ref.read(setlistRepositoryProvider).createSetlist(newSetlist);
  }
}

final setlistControllerProvider =
    StreamNotifierProvider<SetlistController, List<SetlistEntity>>(
      SetlistController.new,
    );
