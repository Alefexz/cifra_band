// lib/features/setlist/domain/entities/setlist_entity.dart

class SetlistEntity {
  final String id;
  final String title;
  final String ownerId;
  final List<String> sharedWith; 
  final List<String> songIds; 
  final DateTime updatedAt;

  SetlistEntity({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.sharedWith,
    required this.songIds,
    required this.updatedAt,
  });
}