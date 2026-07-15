import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const focus = AppTheme.primaryGradientStart;

  static Color disabledSurface(BuildContext context) =>
      AppTheme.isLight(context)
      ? const Color(0xFFE4E0D6)
      : const Color(0xFF284235);
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

  static const TextStyle bodyMedium = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1.35,
    letterSpacing: 0.2,
  );

  static const categoryTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontSize: 19,
    height: 1.05,
    letterSpacing: 0,
    shadows: [
      Shadow(color: Color(0x99000000), blurRadius: 10, offset: Offset(0, 2)),
    ],
  );

  static const categoryMeta = TextStyle(
    color: Colors.white,
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
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
}

class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 99;

  static const double card = 16;
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
        ? const Color(0xFF081912)
        : const Color(0xFFE5DFD3);
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

  // ============ Ronahî Arcade Palette (2026-07-15) ============
  // Google AI Studio referansının kompakt oyun hiyerarşisi; açık-varsayılan,
  // turuncu/indigo ZanKurd kimliğiyle yeniden yorumlanır.
  static const brandOrange = Color(0xFFE57832);
  static const brandOrangeWarm = Color(0xFFF09A52);
  static const playGreen = Color(0xFF4EA66A);
  static const playPink = Color(0xFFD94D72);
  static const playCyan = Color(0xFF2D8BD8);
  static const playPurple = Color(0xFF5147C7);

  // ============ Dark Mode Palette (Bubblegum Arcade — koyu ikincil tema) ============
  // Legacy token names retained for existing screen consumers.
  static const primaryGradientStart = brandOrange;
  static const primaryGradientEnd = brandOrangeWarm;

  // İkincil aksan — ikincil vurgu / yardımcı renk.
  static const secondaryAccent = playCyan;

  // Ödül rengi — YALNIZCA coin / ödül / streak / ustalık rozeti göstergelerinde kullan.
  // Bilinçli olarak sabit tutuldu: renk sistemi değişse de ödül/coin anlamı korunur.
  static const gold = Color(0xFFE9B949);

  // Bilgi/ipucu vurgusu — nadir kullan (ör. joker ipucu). Genel aksan için kullanma.
  static const cyan = playCyan;

  // Dark backgrounds (nötr lacivert tonlar)
  static const bg = Color(0xFF101217);
  static const bgDeep = Color(0xFF0B0D12);
  static const surface = Color(0xFF171C29);
  static const surfaceHi = Color(0xFF202739);
  static const darkBg = bg;

  // Dark mode text
  static const textPrimary = Color(0xFFF5F7FC);
  static const textSub = Color(0xFFC3CAD8);
  static const textMuted = Color(0xFF929CAF);

  // Borders
  static const border = Color(0xFF30394C);

  // Status colors
  // Doğru/yanlış renkleri correct/wrong; altın ödül gold — bu üçü sabit kalır
  // (quiz geri bildirim anlamı renk sisteminden bağımsız).
  static const accent = brandOrange;
  static const violet = playPurple;
  // Doğru cevap rengi — YALNIZCA doğru cevap geri bildiriminde kullan.
  static const correct = Color(0xFF2E7D32); // Dengeli Yeşil — değişmez
  // Yanlış cevap rengi — YALNIZCA yanlış cevap geri bildiriminde kullan.
  static const wrong = Color(0xFFC62828); // Dengeli Kırmızı — değişmez

  // ============ Light Mode Palette (varsayılan tema) ============
  static const lightBg = Color(0xFFF5F7FC);
  static const lightBgDeep = Color(0xFFEFF3FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHi = Color(0xFFEEF2FA);
  static const lightBorder = Color(0xFFDCE3EF);
  static const lightTextPrimary = Color(0xFF171B2E);
  static const lightTextSub = Color(0xFF566078);
  static const lightTextMuted = Color(0xFF7D879C);

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

  // Home header gradient: referanstaki sıcak üst şeridin ZanKurd yorumu.
  static const homeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC45A13), Color(0xFF5147C7)],
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
    [Color(0xFF1E5F47), Color(0xFF0F3A2B)], // Ziman - asil orman yeşili
    [Color(0xFFD65A31), Color(0xFF8B2600)], // Çand - terracotta / kil kırmızısı
    [Color(0xFF2B5C8F), Color(0xFF1A3B5C)], // Dîrok - asil kobalt mavisi
    [Color(0xFFE0A96D), Color(0xFF966C3B)], // Edebiyat - parşömen / sıcak bej
    [Color(0xFF4C7063), Color(0xFF2B443B)], // Cografya - adaçayı yeşili
    [Color(0xFFD4AF37), Color(0xFF8C6D1F)], // Muzîk - sıcak altın sarısı
    [
      Color(0xFFB83B5E),
      Color(0xFF6A2C38),
    ], // Siyaset - asil mürdüm / nar çiçeği
    [Color(0xFF3282B8), Color(0xFF0F4C81)], // Paradigma - derin klasik mavi
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
        onPrimary: lightTextPrimary,
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
          foregroundColor: lightTextPrimary,
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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: accent,
        onPrimary: lightTextPrimary,
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
          foregroundColor: lightTextPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
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
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
        bodyMedium: TextStyle(color: lightTextSub, height: 1.4),
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

  /// Glassmorphism efektli dekorasyon oluşturur.
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

  /// Shimmer efekti için gradient.
  static const shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x11FFFFFF), Color(0x33FFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

  // ============ Ek Gradient Tanımları ============

  /// Profil ekranı rozet bölümü arka plan gradient'i.
  static const badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E5F47), Color(0xFF2C6B54)],
  );

  /// Streak göstergesi gradient'i.
  static const streakGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE76F51), Color(0xFFE9C46A)],
  );

  // ============ Premium Design Helpers ============

  /// Yumuşak, dağınık gölge — kartlar ve paneller için.
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

  /// Renkli neon ışıltı gölgesi — CTA butonlar ve öne çıkan elemanlar.
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

  /// Gradient arka planlı yuvarlak ikon konteyneri.
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

  /// Premium kart dekorasyonu — gradient arka plan + glow + border.
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

  /// Bölüm başlık aksanı — sol kenardaki renkli dikey çizgi.
  static BoxDecoration sectionAccent(Color color) {
    return BoxDecoration(borderRadius: BorderRadius.circular(2), color: color);
  }

  /// Stat/metric kartı dekorasyonu (profil, sonuç ekranları).
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
