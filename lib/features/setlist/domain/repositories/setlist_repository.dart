// lib/features/setlist/domain/repositories/setlist_repository.dart

import '../entities/setlist_entity.dart';

/// O nosso "Cardápio". 
/// Define QUAIS ações podemos fazer com as setlists, mas não COMO são feitas.
abstract class SetlistRepository {
  Future<void> createSetlist(SetlistEntity setlist);
  Future<List<SetlistEntity>> getSetlistsByUser(String userId);
}