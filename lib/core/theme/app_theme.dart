// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de Cores (Inspirado no Dark Mode Premium)
  static const Color backgroundDark = Color(0xFF121212); // Preto profundo (Spotify)
  static const Color surfaceDark = Color(0xFF1E1E1E); // Cartões e menus
  static const Color primaryAccent = Color(0xFF00FF7F); // Verde Neon/Moderno para os Acordes e botões ativos
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAAAAAA);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        surface: surfaceDark,
        background: backgroundDark,
      ),
      
      // Tipografia (Fonte Inter é moderna, limpa e legível - similar a da Apple)
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textSecondary),
      ),

      // Estilo global do AppBar (Menu superior transparente)
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}