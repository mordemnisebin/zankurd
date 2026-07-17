import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const focus = AppTheme.primaryGradientStart;

  static Color disabledSurface(BuildContext context) =>
      AppTheme.isLight(context)
      ? const Color(0xFFEDE9E3)
      : const Color(0xFF282A36);
}

class AppTypography {
  const AppTypography._();

  static const TextStyle display = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 32,
    height: 1.15,
    letterSpacing: -0.8,
  );

  static const TextStyle heading1 = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.45,
  );

  // Slightly bigger for readability (14 → 15)
  static const TextStyle bodyMedium = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12.5,
    height: 1.35,
    letterSpacing: 0.2,
  );

  static const categoryTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontSize: 20,
    height: 1.05,
    letterSpacing: 0,
    shadows: [
      Shadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 2)),
    ],
  );

  static const categoryMeta = TextStyle(
    color: Colors.white,
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  // Quiz-specific text styles
  static const TextStyle quizQuestion = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 18,
    height: 1.5,
  );

  static const TextStyle quizAnswer = TextStyle(
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.4,
  );
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double page = 20;
  static const double section = 28;
  static const double cardGap = 14;
  static const double gridGap = 16;

  // Quiz-specific spacing
  static const double quizQuestionGap = 20;
  static const double quizOptionGap = 12;
  static const double quizSectionGap = 32;
}

class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 99;

  // Slightly rounder (16 → 14)
  static const double card = 14;
}

class AppGradients {
  const AppGradients._();

  static const accentVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppTheme.accent, AppTheme.primaryGradientEnd],
  );

  static LinearGradient categoryImageOverlay(LinearGradient base) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0, 0.42, 1],
      colors: [
        Colors.black.withValues(alpha: 0.06),
        base.colors.first.withValues(alpha: 0.18),
        base.colors.last.withValues(alpha: 0.86),
      ],
    );
  }

  static LinearGradient categoryFallback(LinearGradient base) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base.colors.first, base.colors.last],
    );
  }
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> panel(BuildContext context) =>
      AppTheme.softShadow(context);

  static List<BoxShadow> categoryCard(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.20),
        offset: const Offset(0, 8),
        blurRadius: 18,
        spreadRadius: -8,
      ),
    ];
  }

  static List<BoxShadow> button(Color color, {required bool pressed}) {
    if (pressed) return const [];
    return [BoxShadow(color: color, offset: const Offset(0, 4), blurRadius: 0)];
  }

  static List<BoxShadow> focusRing(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.14),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ];
  }
}

class AppTheme {
  // ============ Design Tokens ============
  // Single source of truth: AppSpacing / AppRadius (no 18 vs 20 drift).
  /// Standard card corner radius used across all cards.
  static const double cardRadius = AppRadius.card;

  /// Standard small card corner radius for inner elements.
  static const double cardRadiusSmall = AppRadius.sm;

  /// Vertical gap between sections (e.g., section header → content).
  static const double sectionGap = AppSpacing.section;

  /// Vertical gap between cards within the same section.
  static const double cardGap = AppSpacing.cardGap;

  /// Standard horizontal page padding.
  static const double pagePadding = AppSpacing.page;

  /// Standard card shadow for normal cards.
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = _isDark(context);
    final shadowColor = isDark
        ? const Color(0xFF0C0E14)
        : const Color(0xFFE8E4DF);
    return [
      BoxShadow(
        color: shadowColor.withValues(alpha: isDark ? 0.24 : 0.12),
        offset: const Offset(0, 8),
        blurRadius: 18,
        spreadRadius: -8,
      ),
    ];
  }

  /// Elevated shadow for hero/primary cards.
  static List<BoxShadow> elevatedShadow(Color tint) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.18),
        offset: const Offset(0, 8),
        blurRadius: 18,
        spreadRadius: -8,
      ),
    ];
  }

  /// Standard card decoration helper.
  static BoxDecoration cardDecoration(
    BuildContext context, {
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

  static BoxDecoration categoryCardDecoration(Color tint) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.22),
        width: 1.2,
      ),
      boxShadow: AppShadows.categoryCard(tint),
    );
  }

  // ============ Pirs-Inspired Modern Academic Palette (2026-07-16) ============
  // Deep Indigo + Warm Gold kimliği; Kürt kültürel mirası Pirs temasından
  // esinlenir. RojMascot (Zana) ışın motifinde taşınır.
  // Bkz. docs/superpowers/specs/2026-07-16-pirs-theme-redesign.md

  // Onaylı mockup sistemi (2026-07-17): Kürdistan yeşili ana aksan,
  // kâğıt-altın ikincil, koyu-sıcak zemin. Bkz.
  // docs/superpowers/specs/2026-07-17-onayli-mockup-hizalama-plan.md
  static const brandOrange = Color(0xFF3DA968); // Kürdistan yeşili — ana aksan
  static const brandOrangeWarm = Color(0xFF2F7D4F); // Koyu yeşil (gradyan ucu)
  static const playGreen = Color(0xFF3DA968); // Öğrenme kimliği (yeşil)
  static const playPink = Color(0xFFC9503C); // Nar kırmızısı — 1v1/rekabet (mockup paleti)
  static const playCyan = Color(0xFF2E9E93); // Teal — oda/mod kartları (mockup paleti)
  static const playPurple = Color(
    0xFF6B3A7A,
  ); // Erik moru — mockup kategori paleti tonu

  // ============ Dark Mode Palette (Pirs — koyu ikincil tema) ============
  // Legacy token names retained for existing screen consumers.
  static const primaryGradientStart = brandOrange;
  static const primaryGradientEnd = brandOrangeWarm;

  // Secondary accent — Pirinç Altını
  static const secondaryAccent = Color(0xFFE7B53C);

  // Reward color — ONLY for coin / reward / streak / mastery badge indicators.
  // Intentionally kept stable: reward/coin meaning preserved across palette changes.
  static const gold = Color(0xFFE7B53C);

  // Info/tip highlight — rare use (e.g. joker hint). Do not use for general accent.
  static const cyan = playCyan;

  // Dark backgrounds — koyu-sıcak yeşilimsi mürekkep (mockup sistemi)
  static const bg = Color(0xFF0B0F0D);
  static const bgDeep = Color(0xFF07100C);
  static const surface = Color(0xFF16211B);
  static const surfaceHi = Color(0xFF1E2C24);
  static const darkBg = Color(0xFF0B0F0D);

  // Dark mode text
  static const textPrimary = Color(0xFFF4F1E9);
  static const textSub = Color(0xFF93A29A);
  // WCAG AA: koyu zeminde (bg) 4.5:1 kontrastı geçecek kadar açık tutulur.
  static const textMuted = Color(0xFF7E8C84);

  // Borders
  static const border = Color(0xFF26332B);

  // Status colors
  // correct/wrong/gold — quiz feedback semantics independent of color system.
  static const accent = primaryGradientStart; // Deep Indigo
  static const violet = secondaryAccent; // Warm Gold
  // Correct answer color — ONLY for correct answer feedback.
  static const correct = Color(0xFF3DA968); // Kürdistan yeşili — mockup
  // Wrong answer color — ONLY for wrong answer feedback.
  static const wrong = Color(0xFFE5533D); // Nar kırmızısı — mockup

  // ============ Light Mode Palette (default theme) ============
  static const lightBg = Color(0xFFFBF9F6); // Warm off-white
  static const lightBgDeep = Color(0xFFF0EBE6); // Warm off-white deeper
  static const lightSurface = Color(0xFFFFFFFF); // Pure white
  static const lightSurfaceHi = Color(0xFFF7F4F0); // Surface highlight
  static const lightBorder = Color(0xFFE8E4DF);
  static const lightTextPrimary = Color(0xFF1E1E24);
  static const lightTextSub = Color(0xFF4A4655); // WCAG AA kontrast orani artirildi
  static const lightTextMuted = Color(0xFF6F6A7E); // WCAG AA kontrast orani artirildi

  // Compat aliases for screens not yet migrated
  static const page = bg;
  static const ink = textPrimary;
  static const muted = textMuted;
  static const green = correct;
  static const red = wrong;
  static const brown = gold;
  static const line = border;

  // ============ Gradient Constants ============
  // Primary accent gradient: Deep Indigo to Light Indigo
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

  // Home header gradient: Deep Green to Soft Green-Gold transition
  static const homeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B251C), Color(0xFF1A4E3B)],
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
    colors: [wrong, Color(0xFFB03D2E)],
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
  // Pirs-inspired vibrant palette:
  static const List<List<Color>> categoryGradients = [
    [Color(0xFFC67A5C), Color(0xFF9B4A2E)], // Ziman - Warm terracotta
    [Color(0xFF722F43), Color(0xFF4A1E2C)], // Çand - Rich burgundy
    [Color(0xFF2B4F7E), Color(0xFF1A3460)], // Dîrok - Deep blue
    [Color(0xFFD4A84B), Color(0xFFB8860B)], // Edebiyat - Amber/gold
    [Color(0xFF3D6B4F), Color(0xFF1E4D2E)], // Cografya - Forest green
    [Color(0xFFD4789E), Color(0xFFA84D6E)], // Muzîk - Rose pink
    [Color(0xFF6B3A7A), Color(0xFF452250)], // Siyaset - Plum purple
    [Color(0xFF2E7D7E), Color(0xFF1A5C5C)], // Paradigma - Teal
  ];

  static LinearGradient categoryGradient(int index) {
    final colors = categoryGradients[index % categoryGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  // Decorative gradients for QuickPlayGrid tiles.
  // Nar kırmızısı — mockup paleti (eski pembe-magenta bırakıldı).
  static const List<Color> duelGradient = [
    Color(0xFFE5533D),
    Color(0xFFB6402F),
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
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
        bodyMedium: TextStyle(color: textSub, height: 1.5),
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Rubik',
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: lightTextPrimary,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Rubik',
          fontWeight: FontWeight.w800,
          fontSize: 20,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: accent.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightTextPrimary,
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : lightTextMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : lightBorder,
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceHi,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextMuted),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w800,
          color: lightTextPrimary,
          letterSpacing: -0.3,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: -0.2,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          height: 1.3,
        ),
        bodyLarge: TextStyle(color: lightTextSub, height: 1.45),
        bodyMedium: TextStyle(color: lightTextSub, height: 1.5),
        bodySmall: TextStyle(color: lightTextMuted, height: 1.35),
        labelLarge: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightSurface,
        contentTextStyle: const TextStyle(color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============ Glassmorphism Helpers ============

  /// Creates a glassmorphism effect decoration.
  static BoxDecoration glassDecoration(
    BuildContext context, {
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

  /// Gradient for shimmer effect.
  static const shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x11FFFFFF), Color(0x33FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

  // ============ Additional Gradient Definitions ============

  /// Profile screen badge section background gradient.
  static const badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E5F47), Color(0xFF2C6B54)],
  );

  /// Streak indicator gradient.
  static const streakGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE76F51), Color(0xFFE9C46A)],
  );

  // ============ Premium Design Helpers ============

  /// Soft, diffuse shadow — for cards and panels.
  static List<BoxShadow> softShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Colored neon glow shadow — CTA buttons and featured elements.
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity),
        blurRadius: 20,
        offset: const Offset(0, 6),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: color.withValues(alpha: intensity * 0.4),
        blurRadius: 40,
        offset: const Offset(0, 12),
        spreadRadius: -4,
      ),
    ];
  }

  /// Gradient background circle icon container.
  static BoxDecoration iconCircle(
    List<Color> gradientColors, {
    double size = 44,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradientColors,
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: gradientColors.first.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Premium card decoration — gradient background + glow + border.
  static BoxDecoration premiumCard(
    BuildContext context, {
    LinearGradient? gradient,
    Color? glowColor,
    double radius = cardRadius,
  }) {
    return BoxDecoration(
      gradient: gradient,
      color: gradient == null ? surfaceColor(context) : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: _isDark(context)
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.8),
        width: 1.2,
      ),
      boxShadow: glowColor != null
          ? glowShadow(glowColor, intensity: 0.25)
          : softShadow(context),
    );
  }

  /// Section title accent — colored vertical bar on the left edge.
  static BoxDecoration sectionAccent(Color color) {
    return BoxDecoration(borderRadius: BorderRadius.circular(2), color: color);
  }

  /// Stat/metric card decoration (profile, result screens).
  static BoxDecoration statCard(BuildContext context, Color accentColor) {
    return BoxDecoration(
      color: surfaceColor(context),
      borderRadius: BorderRadius.circular(cardRadiusSmall),
      border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
