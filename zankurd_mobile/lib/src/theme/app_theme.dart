import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Core colors
  static const bg = Color(0xFFF0F4F8);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0D1B2A);
  static const muted = Color(0xFF8899AA);
  static const line = Color(0xFFE2EAF0);

  // Brand
  static const primary = Color(0xFF1AA366);
  static const primaryDark = Color(0xFF0D7C4E);
  static const primaryLight = Color(0xFF22C87A);

  // Semantic
  static const success = Color(0xFF22C87A);
  static const error = Color(0xFFE74C3C);
  static const warning = Color(0xFFF59E0B);
  static const gold = Color(0xFFF4C430);

  // Backward-compat aliases
  static const green = primary;
  static const red = error;
  static const brown = Color(0xFF241C15);
  static const page = bg;

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7C4E), Color(0xFF1AA366), Color(0xFF22C87A)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2332), Color(0xFF243447)],
  );

  // Category gradients
  static const List<List<Color>> categoryGradients = [
    [Color(0xFF1AA366), Color(0xFF22C87A)],
    [Color(0xFF4059AD), Color(0xFF6B7FD4)],
    [Color(0xFFE74C3C), Color(0xFFFF6B6B)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    [Color(0xFF0891B2), Color(0xFF22D3EE)],
  ];

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: bg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 32),
        headlineLarge: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 28),
        headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 24),
        headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: ink, fontSize: 20),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: ink, fontSize: 18),
        titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink, fontSize: 16),
        bodyLarge: TextStyle(color: ink, fontSize: 16),
        bodyMedium: TextStyle(color: ink, fontSize: 14),
      ),
    );
  }

  // Shadow helpers
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get coloredShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.25),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
