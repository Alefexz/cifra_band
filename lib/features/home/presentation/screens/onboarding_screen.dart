// lib/features/home/presentation/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthStep { login, register, setupProfile }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Controladores
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Estados
  AuthStep _currentStep = AuthStep.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // Lista de instrumentos para o Onboarding
  final List<String> _availableInstruments = [
    'Voz',
    'Violão',
    'Guitarra',
    'Teclado',
    'Baixo',
    'Bateria',
    'Percussão',
    'Saxofone',
    'Outro',
  ];
  final List<String> _selectedInstruments = [];

  // ==========================================
  // ETAPA 1: LOGIN OU CADASTRO NO GOOGLE
  // ==========================================
  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Preencha e-mail e senha.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_currentStep == AuthStep.login) {
        // TENTA LOGAR
        final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Verifica se o usuário já preencheu o perfil no Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .get();
        if (doc.exists && doc.data() != null && doc.data()!['name'] != null) {
          if (mounted) context.go('/home'); // Já tem perfil, vai pra Home
        } else {
          // Se não tem nome no banco, obriga a preencher o perfil
          setState(() => _currentStep = AuthStep.setupProfile);
        }
      } else if (_currentStep == AuthStep.register) {
        // TENTA CRIAR CONTA
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Conta criada com sucesso! Pula para a etapa de escolher nome e instrumento
        setState(() => _currentStep = AuthStep.setupProfile);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Erro na autenticação.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'E-mail ou senha incorretos.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'Este e-mail já está em uso.';
      } else if (e.code == 'weak-password') {
        msg = 'A senha deve ter pelo menos 6 caracteres.';
      }
      _showError(msg);
    } catch (e) {
      _showError('Erro inesperado: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ETAPA 2: SALVAR PERFIL NO FIRESTORE
  // ==========================================
  Future<void> _submitProfile() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Como devemos te chamar?');
      return;
    }
    if (_selectedInstruments.isEmpty) {
      _showError('Selecione pelo menos um instrumento/função.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Salva os dados oficiais do músico no Banco de Dados
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'email': user.email,
        'roles': _selectedInstruments,
        'church_id': null, // Entra sem ministério por padrão
        'is_admin': false,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge evita apagar dados caso já exista

      if (mounted) context.go('/home'); // Vai pro aplicativo!
    } catch (e) {
      _showError('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Digite seu e-mail no campo acima para recuperar a senha.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail de recuperação enviado!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Erro ao enviar e-mail de recuperação.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            physics: const BouncingScrollPhysics(),
            child: _currentStep == AuthStep.setupProfile
                ? _buildProfileSetupView()
                : _buildAuthView(),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // VIEW: TELA DE LOGIN / CADASTRO (ETAPA 1)
  // ==========================================
  Widget _buildAuthView() {
    final isLogin = _currentStep == AuthStep.login;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.music_note_rounded,
          size: 80,
          color: Colors.blueAccent,
        ),
        const SizedBox(height: 24),
        const Text(
          'Cifra Band',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin ? 'Bem-vindo de volta!' : 'Crie sua conta para começar',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
        ),
        const SizedBox(height: 40),

        _buildTextField(
          controller: _emailController,
          hint: 'E-mail',
          icon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          hint: 'Senha',
          icon: Icons.lock_rounded,
          isPassword: true,
          obscure: _obscurePassword,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        if (isLogin)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _resetPassword,
              child: const Text(
                'Esqueci minha senha',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          )
        else
          const SizedBox(height: 24),

        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: _isLoading ? null : _submitAuth,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isLogin ? 'Entrar' : 'Continuar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLogin ? "Ainda não tem conta?" : "Já possui conta?",
              style: TextStyle(color: Colors.grey.shade500),
            ),
            TextButton(
              onPressed: () => setState(() {
                _currentStep = isLogin ? AuthStep.register : AuthStep.login;
                _errorMessage = null;
              }),
              child: Text(
                isLogin ? 'Cadastre-se' : 'Faça Login',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // VIEW: TELA DE NOME E INSTRUMENTOS (ETAPA 2)
  // ==========================================
  Widget _buildProfileSetupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Falta pouco!',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete seu perfil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          'Como devemos te chamar?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nameController,
          hint: 'Seu Nome (Ex: Álefe)',
          icon: Icons.person_rounded,
        ),

        const SizedBox(height: 32),

        const Text(
          'Selecione seus instrumentos:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Você pode escolher mais de um.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _availableInstruments.map((instrument) {
            final isSelected = _selectedInstruments.contains(instrument);
            return FilterChip(
              label: Text(instrument),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade400,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedInstruments.add(instrument);
                  } else {
                    _selectedInstruments.remove(instrument);
                  }
                });
              },
              backgroundColor: const Color(0xFF16161E),
              selectedColor: Colors.blueAccent.withOpacity(0.4),
              checkmarkColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? Colors.blueAccent
                      : Colors.white.withOpacity(0.05),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 48),

        ElevatedButton(
          onPressed: _isLoading ? null : _submitProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Entrar no App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  // ==========================================
  // COMPONENTES AUXILIARES
  // ==========================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscure : false,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.grey,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF16161E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
