import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. Fica de olho em quem está logado no Firebase Auth
final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// 2. Escuta o SEU perfil no Firestore em TEMPO REAL
final userProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

// 3. Escuta os dados da IGREJA que você faz parte
final ministryProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, churchId) {
  return FirebaseFirestore.instance
      .collection('ministries')
      .doc(churchId)
      .snapshots()
      .map((snapshot) => snapshot.data());
});

// 4. A NOVA MÁGICA: Escuta a próxima escala (Culto) da Igreja
final nextScheduleProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, churchId) {
  return FirebaseFirestore.instance
      .collection('schedules')
      .where('church_id', isEqualTo: churchId)
      // REMOVI O orderBy('date') para o Firebase não exigir o índice manual!
      // Como estamos limitando a 1 e as escalas são criadas em ordem, vai funcionar bem.
      .limit(1) 
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty ? snapshot.docs.first.data() : null);
});