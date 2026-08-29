// lib/features/setlist/data/models/setlist_model.dart

import '../../domain/entities/setlist_entity.dart';

class SetlistModel extends SetlistEntity {
  SetlistModel({
    required super.id,
    required super.title,
    required super.ownerId,
    required super.sharedWith,
    required super.songIds,
    required super.updatedAt,
  });

  // Transforma o JSON do Firebase no nosso Objeto Flutter
  factory SetlistModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SetlistModel(
      id: documentId,
      title: map['title'] ?? '',
      ownerId: map['ownerId'] ?? '',
      sharedWith: List<String>.from(map['sharedWith'] ?? []),
      songIds: List<String>.from(map['songIds'] ?? []),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt']) 
          : DateTime.now(),
    );
  }

  // Transforma o nosso Objeto Flutter em JSON para enviar pro Firebase
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'ownerId': ownerId,
      'sharedWith': sharedWith,
      'songIds': songIds,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }
}