import 'package:flutter/material.dart';

class AppTheme {
  // ============ Design Tokens ============
  /// Standard card corner radius used across all cards.
  static const double cardRadius = 20;

  /// Standard small card corner radius for inner elements.
  static const double cardRadiusSmall = 12;

  /// Vertical gap between sections (e.g., section header → content).
  static const double sectionGap = 24;

  /// Vertical gap between cards within the same section.
  static const double cardGap = 12;

  /// Standard horizontal page padding.
  static const double pagePadding = 18;

  /// Standard card shadow for normal cards.
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  /// Elevated shadow for hero/primary cards.
  static List<BoxShadow> elevatedShadow(Color tint) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.35),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// Standard card decoration helper.
  static BoxDecoration cardDecoration(BuildContext context, {
    LinearGradient? gradient,
    Color? color,
    double radius = cardRadius,
  }) {
    return BoxDecoration(
      gradient: gradient,
      color: gradient == null ? (color ?? surfaceColor(context)) : null,
      borderRadius: BorderRadius.circular(radius),
      border: gradient == null
          ? Border.all(color: borderColor(context).withValues(alpha: 0.5))
          : null,
      boxShadow: cardShadow(context),
    );
  }

  // ============ Dark Mode Palette ============
  // Primary CTA / marka gradyanı — ana eylem butonları ve marka vurgusu.
  static const primaryGradientStart = Color(0xFFFF4B91); // Canlı neon pembe
  static const primaryGradientEnd = Color(0xFFFF7B54); // Canlı neon turuncu

  // İkincil aksan — ikincil vurgu / yardımcı renk.
  static const secondaryAccent = Color(0xFF6F61C0);

  // Ödül rengi — YALNIZCA coin / ödül / streak / ustalık rozeti göstergelerinde kullan.
  static const gold = Color(0xFFFFD23F); // Parlak neon altın sarısı

  // Bilgi/ipucu vurgusu — nadir kullan (ör. joker ipucu). Genel aksan için kullanma.
  static const cyan = Color(0xFF00F0FF); // Parlak neon mavi/turkuaz

  // Dark backgrounds (Derin Gece Mavisi / Kozmik Mor geçişleri)
  static const bg = Color(0xFF0F0C20); 
  static const bgDeep = Color(0xFF080711); 
  static const surface = Color(0xFF16132D); 
  static const surfaceHi = Color(0xFF221E42); 
  static const darkBg = Color(0xFF05040B); 

  // Dark mode text
  static const textPrimary = Color(0xFFF5F4FA); 
  static const textSub = Color(0xFFB8B5D0); 
  static const textMuted = Color(0xFF7F7A9C); 

  // Borders
  static const border = Color(0xFF2E2A52); 

  // Status colors
  // Primary neon pembe — ana aksan / vurgu rengi.
  static const accent = Color(0xFFFF4B91); // Neon Pembe
  // İkincil mor aksan — yardımcı vurgu rengi.
  static const violet = Color(0xFF8E8FFA); // Pastel Neon Mor
  // Doğru cevap rengi — YALNIZCA doğru cevap geri bildiriminde kullan.
  static const correct = Color(0xFF00E676); // Parlak Neon Yeşil
  // Yanlış cevap rengi — YALNIZCA yanlış cevap geri bildiriminde kullan.
  static const wrong = Color(0xFFFF1744); // Parlak Neon Kırmızı

  // ============ Light Mode Palette (Premium, TRT Tarzı Canlı/Parlak) ============
  // Yumuşak, modern ve göz yormayan, aynı zamanda renkleri patlatan arka planlar
  static const lightBg = Color(0xFFF3F2F9); // Yumuşak lavanta grisi
  static const lightBgDeep = Color(0xFFE5E3F1); 
  static const lightSurface = Color(0xFFFFFFFF); 
  static const lightSurfaceHi = Color(0xFFF7F6FB); 
  static const lightBorder = Color(0xFFDDD9EC); 
  static const lightTextPrimary = Color(0xFF140D33); 
  static const lightTextSub = Color(0xFF4A4468); 
  static const lightTextMuted = Color(0xFF8882A3); 

  // Compat aliases for screens not yet migrated
  static const page = bg;
  static const ink = textPrimary;
  static const muted = textMuted;
  static const green = correct;
  static const red = accent;
  static const brown = gold;
  static const line = border;

  // ============ Gradient Constants ============
  // Primary accent gradient: Coral to Orange
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  // Dark auth gradient
  static const darkAuthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, bgDeep],
  );

  // Home header gradient
  static const homeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F61C0), Color(0xFFFF4B91)],
  );

  // Legacy gradient aliases for backwards compatibility
  static const bgGradient = darkAuthGradient;

  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  static LinearGradient backgroundGradient(BuildContext context) {
    if (!isLight(context)) return bgGradient;
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightBg, lightBgDeep],
    );
  }

  static Color surfaceColor(BuildContext context) =>
      isLight(context) ? lightSurface : surface;

  static Color surfaceHiColor(BuildContext context) =>
      isLight(context) ? lightSurfaceHi : surfaceHi;

  static Color borderColor(BuildContext context) =>
      isLight(context) ? lightBorder : border;

  static Color textPrimaryColor(BuildContext context) =>
      isLight(context) ? lightTextPrimary : textPrimary;

  static Color textSubColor(BuildContext context) =>
      isLight(context) ? lightTextSub : textSub;

  static Color textMutedColor(BuildContext context) =>
      isLight(context) ? lightTextMuted : textMuted;

  // Legacy gradients for backwards compatibility
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFFFB300)],
  );

  static const correctGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [correct, Color(0xFF00C853)],
  );

  static const wrongGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [wrong, Color(0xFFD50000)],
  );

  static List<BoxShadow> shadow3D(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.6),
        offset: const Offset(0, 4),
        blurRadius: 0,
      ),
    ];
  }

  // Per-category gradients (index matches category list order)
  static const List<List<Color>> categoryGradients = [
    [Color(0xFF7C3AED), Color(0xFF5B21B6)], // Ziman - purple
    [Color(0xFFE94560), Color(0xFFF97316)], // Çand - coral-orange
    [Color(0xFF2563EB), Color(0xFF1D4ED8)], // Dîrok - blue
    [Color(0xFF10B981), Color(0xFF059669)], // Edebiyat - green
    [Color(0xFF06B6D4), Color(0xFF0891B2)], // Cografya - teal
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Muzîk - amber
    [Color(0xFFFF2E93), Color(0xFFFF8E53)], // Siyaset - hot pink to neon orange
    [Color(0xFF00F2FE), Color(0xFF4FACFE)], // Paradigma - bright cyan to neon blue
  ];

  static LinearGradient categoryGradient(int index) {
    final colors = categoryGradients[index % categoryGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  // Tek kullanımlık dekoratif gradyanlar (QuickPlayGrid tile'ları için).
  static const List<Color> duelGradient = [
    Color(0xFFFF416C),
    Color(0xFFFF4B2B),
  ];
  static const List<Color> tournamentGradient = [
    Color(0xFF00BFA5),
    Color(0xFF00897B),
  ];

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: Colors.white,
        secondary: violet,
        onSecondary: Colors.white,
        tertiary: cyan,
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
          fontFamily: 'Rubik',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? accent : textMuted,
          ),
        ),
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
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.3,
        ),
        bodyLarge: TextStyle(color: textSub, height: 1.45),
        bodyMedium: TextStyle(color: textSub, height: 1.4),
        bodySmall: TextStyle(color: textMuted, height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHi,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============ Context-Aware Helpers ============
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bgOf(BuildContext context) => _isDark(context) ? bg : lightBg;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? surface : lightSurface;

  static Color surfaceHiOf(BuildContext context) =>
      _isDark(context) ? surfaceHi : lightSurfaceHi;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? textPrimary : lightTextPrimary;

  static Color textSubOf(BuildContext context) =>
      _isDark(context) ? textSub : lightTextSub;

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? border : lightBorder;

  static ThemeData light() {
    final base = dark();
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: accent,
        onPrimary: Colors.white,
        secondary: violet,
        onSecondary: Colors.white,
        tertiary: cyan,
        error: wrong,
        onError: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: lightTextPrimary,
        titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
          color: lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: lightTextPrimary),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: lightSurface,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : lightTextMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: s.contains(WidgetState.selected) ? accent : lightTextMuted,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: lightSurfaceHi,
        hintStyle: const TextStyle(color: lightTextMuted),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: lightTextPrimary,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: lightTextPrimary,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: lightTextPrimary,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: lightTextSub),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: lightTextSub),
        bodySmall: base.textTheme.bodySmall?.copyWith(color: lightTextMuted),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: const Color(0xFFFFFFFF),
        contentTextStyle: const TextStyle(color: Color(0xFF172033)),
      ),
    );
  }

  // ============ Glassmorphism Helpers ============

  /// Glassmorphism efektli dekorasyon oluşturur.
  static BoxDecoration glassDecoration(BuildContext context, {
    double borderRadius = 16,
    double opacity = 0.12,
  }) {
    final isDark = _isDark(context);
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white.withValues(alpha: opacity + 0.4),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.6),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Shimmer efekti için gradient.
  static const shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FFFFFF),
      Color(0x11FFFFFF),
      Color(0x33FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ============ Ek Gradient Tanımları ============

  /// Profil ekranı rozet bölümü arka plan gradient'i.
  static const badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
  );

  /// Streak göstergesi gradient'i.
  static const streakGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFFFD700)],
  );
}

