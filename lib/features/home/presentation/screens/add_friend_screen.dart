// lib/features/home/presentation/screens/add_friend_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;
  String? _foundUserId;

  Future<void> _searchFriend() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um código válido de 6 caracteres.'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _foundUserId = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Busca no Firebase alguém com esse código
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum músico encontrado com esse código.'), backgroundColor: Colors.orange));
        setState(() => _isLoading = false);
        return;
      }

      final doc = snapshot.docs.first;
      
      // Bloqueia se a pessoa tentar adicionar ela mesma
      if (doc.id == currentUser.uid) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Este é o seu próprio código!'), backgroundColor: Colors.blueAccent));
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _foundUser = doc.data();
        _foundUserId = doc.id;
        _isLoading = false;
      });

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na busca: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _addFriend() async {
    if (_foundUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // ⚠️ MÁGICA: Adiciona o ID do amigo na SUA lista, e o SEU ID na lista do AMIGO (Amizade Mútua)
      final batch = FirebaseFirestore.instance.batch();
      
      final myRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final friendRef = FirebaseFirestore.instance.collection('users').doc(_foundUserId);

      batch.update(myRef, {'friends': FieldValue.arrayUnion([_foundUserId])});
      batch.update(friendRef, {'friends': FieldValue.arrayUnion([currentUser.uid])});

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Músico adicionado aos contatos! 🎉'), backgroundColor: Colors.green));
        context.pop(); // Volta pra tela anterior
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao adicionar: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Adicionar Músico', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tem o código de um amigo?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Digite a TAG de 6 dígitos para conectarem seus perfis e participarem dos mesmos ministérios.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 24),
            
            // Caixa de Pesquisa
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    decoration: InputDecoration(
                      hintText: 'EX: A7X9K2',
                      hintStyle: TextStyle(color: Colors.grey.shade700, letterSpacing: 0),
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFF1A1A24),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _isLoading ? null : _searchFriend,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.search_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),

            // Resultado da Busca
            if (_foundUser != null) ...[
              const Text('MÚSICO ENCONTRADO', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: const Color(0xFF16161E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      child: Text(_foundUser!['name']?[0]?.toUpperCase() ?? 'M', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ),
                    const SizedBox(height: 12),
                    Text(_foundUser!['name'] ?? 'Músico', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text((_foundUser!['roles'] as List<dynamic>?)?.join(', ') ?? 'Membro', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addFriend,
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Adicionar aos meus contatos', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}