import 'package:flutter/material.dart';

class AppTheme {
  static const page = Color(0xFFFBF8F2);
  static const ink = Color(0xFF1D2522);
  static const muted = Color(0xFF6F7773);
  static const green = Color(0xFF177A56);
  static const red = Color(0xFFD44942);
  static const brown = Color(0xFF241C15);
  static const line = Color(0xFFE4DDD2);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        brightness: Brightness.light,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleLarge: TextStyle(fontWeight: FontWeight.w900, color: ink),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
        bodyMedium: TextStyle(color: ink),
      ),
    );
  }
}
