import 'package:flutter/material.dart';

class AppTheme {
  // Core palette
  static const bg = Color(0xFF1A1A2E);
  static const bgDeep = Color(0xFF16213E);
  static const surface = Color(0xFF1E2A45);
  static const surfaceHi = Color(0xFF243357);
  static const border = Color(0xFF2A3B5C);
  static const accent = Color(0xFFE94560);
  static const violet = Color(0xFF7C3AED);
  static const gold = Color(0xFFFFB800);
  static const correct = Color(0xFF00D68F);
  static const wrong = Color(0xFFFF3D71);
  static const textPrimary = Colors.white;
  static const textSub = Color(0xFFB0BCDB);
  static const textMuted = Color(0xFF6B7A9B);

  // Compat aliases for screens not yet migrated
  static const page = bg;
  static const ink = textPrimary;
  static const muted = textMuted;
  static const green = correct;
  static const red = accent;
  static const brown = gold;
  static const line = border;

  // Gradients
  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, bgDeep],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE94560), Color(0xFFBD1E3B)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB800), Color(0xFFE08C00)],
  );

  static const correctGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D68F), Color(0xFF009E6A)],
  );

  // Per-category gradients (index matches category list order)
  static const List<List<Color>> categoryGradients = [
    [Color(0xFF7C3AED), Color(0xFF5B21B6)], // Ziman - purple
    [Color(0xFFE94560), Color(0xFFF97316)], // Çand - coral-orange
    [Color(0xFF2563EB), Color(0xFF1D4ED8)], // Dîrok - blue
    [Color(0xFF10B981), Color(0xFF059669)], // Edebiyat - green
    [Color(0xFF06B6D4), Color(0xFF0891B2)], // Cografya - teal
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Muzîk - amber
  ];

  static LinearGradient categoryGradient(int index) {
    final colors = categoryGradients[index % categoryGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: Colors.white,
        secondary: violet,
        onSecondary: Colors.white,
        error: wrong,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : border,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHi,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w900,
          color: textPrimary,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: textPrimary),
        bodyMedium: TextStyle(color: textSub),
        bodySmall: TextStyle(color: textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHi,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
