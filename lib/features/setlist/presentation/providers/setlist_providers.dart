// lib/features/setlist/presentation/providers/setlist_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/setlist_repository_impl.dart';
import '../../domain/repositories/setlist_repository.dart';

/// 1. Provedor do Firebase Firestore (A conexão com o Google)
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// 2. Provedor do nosso Repositório (O Cozinheiro)
/// Note como ele usa a INTERFACE (SetlistRepository) mas retorna a IMPLEMENTAÇÃO.
/// A tela nunca saberá que o Firebase existe!
final setlistRepositoryProvider = Provider<SetlistRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return SetlistRepositoryImpl(firestore);
});