// lib/features/setlist/data/repositories/setlist_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/setlist_entity.dart';
import '../../domain/repositories/setlist_repository.dart';
import '../models/setlist_model.dart';

class SetlistRepositoryImpl implements SetlistRepository {
  final FirebaseFirestore _firestore;

  SetlistRepositoryImpl(this._firestore);

  @override
  Future<void> createSetlist(SetlistEntity setlist) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('Você precisa estar logado para criar setlists.');

    final model = SetlistModel(
      id: setlist.id,
      title: setlist.title,
      ownerId: currentUser.uid,
      sharedWith: setlist.sharedWith,
      songIds: setlist.songIds,
      updatedAt: setlist.updatedAt,
    );

    await _firestore.collection('setlists').doc(model.id).set(model.toMap());
  }

  @override
  Future<List<SetlistEntity>> getSetlistsByUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return []; 

    // ⚠️ MÁGICA: Busca as que sou dono OU as que meu UID está na lista de compartilhados!
    final snapshot = await _firestore
        .collection('setlists')
        .where(
          Filter.or(
            Filter('ownerId', isEqualTo: currentUser.uid),
            Filter('sharedWith', arrayContains: currentUser.uid),
          )
        )
        .get();

    return snapshot.docs
        .map((doc) => SetlistModel.fromMap(doc.data(), doc.id))
        .toList();
  }
}