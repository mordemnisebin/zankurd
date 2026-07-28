import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  const AppColors._();

  static const focus = AppTheme.primaryGradientStart;

  static Color disabledSurface(BuildContext context) =>
      AppTheme.isLight(context)
      ? const Color(0xFFEDE9E3)
      : const Color(0xFF282A36);

  /// İkon zemin tonu (menü/istatistik ikon karoları). Light'ta hafif pastel
  /// kalır; dark'ta alfa yükselir ki koyu zeminde ikon kaybolmasın — ama
  /// hiçbir zaman açık temadan taşan düz pastel ("yapışkan not") kullanılmaz.
  static Color iconTileBg(BuildContext context, Color color) =>
      color.withValues(alpha: AppTheme.isLight(context) ? 0.14 : 0.24);

  /// Aksan metin rengini yüzeye göre uyarlar. Dark temada koyu aksanlar
  /// (ör. brandDeep, deniz mavisi) yüzeyde boğulduğu için aydınlatılır;
  /// light temada renk olduğu gibi döner.
  static Color toneOnSurface(BuildContext context, Color color) {
    if (AppTheme.isLight(context)) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness >= 0.55) return color;
    return hsl.withLightness((hsl.lightness + 0.22).clamp(0.0, 0.72)).toColor();
  }

  /// [toneOnSurface]'in ters yönü: açık temada, açık aksanların (altın,
  /// sarı, açık yeşil) açık yüzey üzerinde metin olarak kullanılması
  /// okunmuyor — ör. turnuva "Bot turnuva" çipi altın metin + altın@0.2
  /// zemin ile ~2:1 kalıyordu (2026-07-22 UX denetimi).
  ///
  /// Aksanın kimliğini (ton/doygunluk) korur, yalnız açıklığını metin
  /// olarak okunabilecek düzeye çeker. Koyu temada [toneOnSurface]'e devreder.
  static Color readableAccent(BuildContext context, Color color) {
    if (!AppTheme.isLight(context)) return toneOnSurface(context, color);
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness <= 0.45) return color;
    // 0.30: beyaz yüzeyde altın için ölçülen kontrast 4.5:1'i geçen ilk
    // değer (0.34 → 4.34:1, AA altında kalıyordu).
    return hsl.withLightness(0.30).toColor();
  }

  /// Düz renkli (dolu) zeminin üstünde okunan metin rengi.
  ///
  /// Dolu düğmelerde yazı rengi sabit beyaz yazılıyordu. Beyaz, koyu
  /// aksanlarda doğru; açık aksanlarda değil: öğrenme ekranındaki "Flaş
  /// kart" düğmesi altın zeminde 2.30:1, "Dersler" orta yeşilde 3.96:1
  /// ölçüldü (2026-07-27). Etiket, düğmenin üstünde eriyip gidiyordu.
  ///
  /// Karar zemine bağlıdır, düğmeye değil: hangi uç (koyu metin ya da
  /// beyaz) zeminden daha uzaksa o seçilir. Çarkın rakamları zaten bu
  /// mantıkla çiziliyordu; burada da aynısı yapılır.
  static Color onSolid(Color background) {
    const ink = Color(0xFF1A1D1B);
    return _contrast(Colors.white, background) >= _contrast(ink, background)
        ? Colors.white
        : ink;
  }

  /// Kendi %14'lük tonu üzerine yazılan aksan metnin okunur hâli
  /// (tonal düğmeler: "Odaya çağır", ödül çipleri).
  ///
  /// [readableAccent] düz yüzeye göre ayarlanmıştır. Tonal düğmede zemin
  /// aksanın kendi tonudur: koyu temada yüzey açılır, açık temada beyaz
  /// koyulaşır — her iki yönde de metinle zemin birbirine yaklaşır.
  /// Ölçüm (2026-07-27): arkadaş kartındaki "Odaya çağır" koyu temada
  /// 2.49:1, marka turuncusu açık temada 3.77:1. Düğmeler etkin oldukları
  /// hâlde kapalı görünüyordu.
  ///
  /// Renk kimliği (ton ve doygunluk) korunur; yalnız açıklık, AA eşiği
  /// geçilene dek adım adım zeminden uzaklaştırılır. Sabit bir sayı yerine
  /// arama kullanılır ki yeni bir aksan eklendiğinde de doğru kalsın.
  /// [tintAlpha], zeminin aksandan aldığı payı söyler. Varsayılan %14 tipik
  /// rozet/karo tonudur; kendisi de tonlu bir kartın üstünde duran çipler
  /// için daha yüksek verilir — yoksa hesap, gerçekte olduğundan koyu bir
  /// zemin varsayar ve metni gereğinden açık bırakır.
  static Color onAccentTint(
    BuildContext context,
    Color accent, {
    double tintAlpha = 0.14,
  }) {
    final surface = AppTheme.isLight(context)
        ? AppTheme.lightSurface
        : AppTheme.surface;
    final background = Color.alphaBlend(
      accent.withValues(alpha: tintAlpha),
      surface,
    );
    final darken = background.computeLuminance() > 0.4;
    var hsl = HSLColor.fromColor(readableAccent(context, accent));
    for (var i = 0; i < 24; i++) {
      final candidate = hsl.toColor();
      if (_contrast(candidate, background) >= 4.5) return candidate;
      final next = hsl.lightness + (darken ? -0.03 : 0.03);
      if (next < 0 || next > 1) return candidate;
      hsl = hsl.withLightness(next);
    }
    return hsl.toColor();
  }

  static double _contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final hi = l1 > l2 ? l1 : l2;
    final lo = l1 > l2 ? l2 : l1;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Renk tonuyla boyanmış kart üzerinde ikincil metin rengi.
  ///
  /// [AppTheme.textSubColor] ve [AppTheme.textMutedColor] düz yüzeye göre
  /// seçilmiştir. Turnuva kartı gibi yüzeyin üstüne altın tonu seren
  /// kartlarda gerçek zemin belirgin biçimde açılır ve o iki ton eşiğin
  /// altına düşer: koyu temada turnuva ipucu satırı ölçümde 3.38:1
  /// çıkıyordu (2026-07-27). Kusur sessizdi — renkler temadan geliyordu,
  /// yalnız zemin başka bir zemindi.
  ///
  /// Her iki tema da aynı kusuru taşıyordu: açık temada ikincil satır 3.23:1
  /// ölçülüyordu. Tonlar bir basamak yukarı çekilir — hiyerarşi korunur
  /// (birincil/ikincil ayrımı sürer), yalnız ikisi de tonlu zeminde okunur.
  /// `tinted_surface_contrast_test` bunları harmanlanmış gerçek kart
  /// rengine karşı ölçer.
  static Color onTintedSurface(BuildContext context, {bool secondary = false}) {
    if (AppTheme.isLight(context)) {
      return secondary ? AppTheme.lightTextSub : AppTheme.lightTextPrimary;
    }
    return secondary ? const Color(0xFFC9D0D6) : AppTheme.textPrimary;
  }

  /// Marka turuncusu gibi orta tonlu gradyanların üzerinde beyaz metnin AA
  /// eşiğini geçmesi için gereken koyu perde. Beyaz, turuncu üzerinde tek
  /// başına yalnız ~2.2:1 verir; bu perde ile 4.5:1 üstüne çıkar.
  /// (2026-07-22 UX denetimi — contrast_policy_test bu değeri doğrular.)
  static Color heroScrim([double opacity = 0.34]) =>
      Colors.black.withValues(alpha: opacity);
}

class AppTypography {
  const AppTypography._();

  /// Uygulamanın yazı tipi ailesi.
  ///
  /// Widget'lar bunu temadan alır; `CustomPainter` içinde `TextPainter` ile
  /// çizilen metin **almaz** ve aile yazılmazsa sistem varsayılanına düşer.
  /// Tek bir ekranda iki ayrı yazı tipi görünmesin diye o çağrı yerleri
  /// buradan besleniyor (2026-07-26: çark rakamları ve haftalık grafik
  /// etiketleri böyleydi).
  static const fontFamily = 'Rubik';

  static const TextStyle display = TextStyle(
    fontWeight: FontWeight.w800,
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

  // Alt başlık — heading2 ile bodyLarge arasında organik geçiş.
  static const TextStyle subtitle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 17,
    height: 1.35,
    letterSpacing: -0.1,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontWeight: FontWeight.w500,
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
    fontSize: 12,
    height: 1.35,
    letterSpacing: 0.2,
  );

  static const categoryTitle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
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
  // Soru metni en belirgin metin olmalı — subtitle + bold
  static const TextStyle quizQuestion = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 18,
    height: 1.4,
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

  // Kucuk rozet/cip/etiket kosesi (onceki sabit borderRadius: 10 degeri).
  static const double badge = 10;
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

/// Kart öncelik/amaç tipi — visual weight ayrımı için kullanılır.
enum CardType {
  /// Ana CTA / soru kartı: gradient + glow + güçlü shadow.
  primary,

  /// İçerik kartı: surface + border + orta shadow (glass/surface).
  secondary,

  /// Bilgi kartı: sadece border + minimal shadow (istatistik, yardımcı).
  info,

  /// Arkasını bulanıklaştıran glassmorphism (buzlu cam) görünümü.
  glass,
}

class AppTheme {
  // ============ Design Tokens ============
  // C-3: AppTheme.cardRadius, AppRadius.card (14) ile eşitlendi.
  // Önceki değer 16 idi ve tasarım sistemi bütünlüğünü bozuyordu.
  // AppRadius.card kullanan ekranlarla görsel tutarlılık sağlandı.
  static const double cardRadius = AppRadius.card;
  static const double cardRadiusSmall = 12;
  static const double sectionGap = AppSpacing.section;
  static const double cardGap = AppSpacing.cardGap;
  static const double pagePadding = AppSpacing.page;

  /// 2026-07-24: kartlar artık gölgeyle değil 1px kenarlıkla ayrılır.
  /// Üst üste binen gölge katmanları ekranı "kabartma" gösteriyor ve
  /// yüzeyler arasında sahte hiyerarşi yaratıyordu. Gölge yalnız gerçekten
  /// yüzen katmanlarda kalır (alt navigasyon, sabit CTA, sheet) — onlar
  /// [floatingShadow] kullanır.
  static List<BoxShadow> cardShadow(BuildContext context) => const [];

  /// Gerçekten yüzen katmanlar için tek gölge token'ı.
  static List<BoxShadow> floatingShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.10),
        offset: const Offset(0, 6),
        blurRadius: 20,
        spreadRadius: -6,
      ),
    ];
  }

  static List<BoxShadow> elevatedShadow(Color tint) {
    return [
      BoxShadow(
        color: tint.withValues(alpha: 0.12),
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -4,
      ),
    ];
  }

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
      border: gradient == null ? Border.all(color: borderColor(context)) : null,
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

  // ============ Zanîn paleti (2026-07-24 tasarım yenilemesi) ============
  // İlke: zemin sakin, kimlik yeşil (Kesk), eylem turuncu (Tîrêj), ödül altın
  // (Zêr). Aksan rolü 3'e indirildi; kategori tonları `category_visuals.dart`
  // içinde yaşar ve yalnız ikon karosu + ince şeritte görünür.
  //
  // Tîrêj — tek eylem rengi. Eski #F5931E beyaz metinle 2.2:1 veriyordu ve
  // her CTA'ya karartma perdesi (heroScrim) gerektiriyordu; bu ton beyazla
  // AA eşiğini kendi başına geçer.
  static const brand = Color(0xFFC2560E); // Primary CTA/Accent (Tîrêj)
  static const brandDeep = Color(0xFFA0450A);

  /// Gradyanın açık ucu — yalnız birincil CTA'da kullanılır.
  static const brandLite = Color(0xFFE2711D);

  // Kesk — marka kimliği (başlık şeritleri, kimlik yüzeyleri).
  static const culturalBrandBg = Color(0xFF14513A); // Deep Green

  // Aşağıdaki dört ton geriye dönük ad uyumu için duruyor; artık "oyun modu
  // rengi" değil, nötrleştirilmiş yardımcı aksanlardır.
  // Dolu düğme zemini olarak kullanıldığında beyaz etiket yalnız 3.96:1
  // veriyordu; koyu metin de 4.29'da kalıyordu, yani hiçbir yazı rengi
  // eşiği geçmiyordu — sorun rengin kendisiydi (2026-07-27). Açıklık
  // 0.40'tan 0.36'ya çekildi: aynı yeşil, beyazla 4.72:1.
  static const playGreen = Color(0xFF398156);
  static const playPink = Color(0xFFA85A7A); // Muted elegant rose
  static const playCyan = Color(0xFF2F6F62); // Muted elegant teal
  static const playPurple = Color(0xFF6B5AA6); // Muted elegant purple

  // ============ Dark Mode Palette ============
  static const primaryGradientStart = brand;
  static const primaryGradientEnd = brandDeep;

  // Zêr — yalnız ödül/ilerleme (XP, kredi, 1. sıra). Eski #E7B53C açık
  // yüzeyde metin olarak okunmuyordu; bu ton her iki temada da çalışır.
  static const secondaryAccent = Color(0xFFD9A227);
  static const gold = Color(0xFFD9A227);

  static const cyan = playCyan;

  static const bg = Color(0xFF0E1512);
  static const bgDeep = Color(0xFF0A0F0C);
  // Kartlar zeminden 1px kenarlıkla ayrılır; yüzey zeminden yalnız bir tık
  // açık olsun ki gece kullanımında ekran parlamasın (2026-07-24).
  static const surface = Color(0xFF18211B);
  static const surfaceHi = Color(0xFF212C24);
  static const darkBg = bg;

  static const textPrimary = Color(0xFFF6F3EC);
  static const textSub = Color(0xFFA8B0B8);
  static const textMuted = Color(0xFF8F98A0);

  static const border = Color(0xFF2A362E);

  static const accent = primaryGradientStart;
  static const violet = secondaryAccent;
  static const correct = Color(0xFF3DA968);
  static const wrong = Color(0xFFE5533D);

  /// Form doğrulama hatası metni. Material varsayılanı açık temada
  /// krem zemin üzerinde ~1.8:1 kontrastla okunmuyordu; bu iki ton
  /// WCAG AA'yı her iki temada da geçer.
  static const formErrorLight = Color(0xFFB3261E);
  static const formErrorDark = Color(0xFFFF8A75);

  // Onboarding 2. slayt: ödül/yarış teması için terracotta tonu.
  static const terracotta = Color(0xFFB86A3E);

  // 1v1 sonuç ekranı — kazanma/kaybetme gradyanının koyu gölge renkleri.
  // `correct`/`wrong`'un karanlık tonu; hardcoded Color literal yerine
  // anlamlı token olarak tanımlandı (quiz_result_screen M-11).
  static const correctDeep = Color(0xFF1B5E20); // Win gradient shadow
  static const wrongDeep = Color(0xFF7F1D1D); // Lose gradient shadow

  // ============ Light Mode Palette (Variant C) ============
  static const lightBg = Color(0xFFF7F4EE);
  static const lightBgDeep = Color(0xFFEFEBE3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHi = Color(0xFFFBF8F3);
  static const lightBorder = Color(0xFFE7E0D4);
  static const lightTextPrimary = Color(0xFF1B201D); // Mürekkep
  static const lightTextSub = Color(0xFF5C635E);
  // Açık temada sönük metin rengi. Eski #7C837D sayfa zemininde 3.54:1,
  // beyaz kartta 3.89:1 veriyordu — ikisi de AA eşiği olan 4.5'in altında
  // (2026-07-27). Uygulamanın bütün ikincil etiketleri bu rengi kullanıyor:
  // ipuçları, alt başlıklar, form yardım metinleri, hatta karşılama
  // ekranındaki "Atla" düğmesi. Yani tek bir sabit, ekranların yarısında
  // aynı kusuru taşıyordu ve tek tek bakıldığında "tasarım tercihi" gibi
  // görünüyordu.
  //
  // Bir tık koyulaştırıldı: sayfa zemininde 4.70:1, beyaz kartta 5.16:1.
  // `lightTextSub` (#5C635E) hâlâ belirgin biçimde koyu, yani sönük/ikincil
  // ayrımı korunuyor. Koyu temanın karşılığı (#8F98A0) zaten 5.6-6.3
  // veriyordu; orada bir şey değişmedi.
  static const lightTextMuted = Color(0xFF686F69);

  static const pirsOrangeStart = culturalBrandBg; // Cultural Deep Green
  static const pirsOrangeEnd = culturalBrandBg;

  static const answerOptionBg = Color(0xFFF8F9FA);
  static const answerOptionBorder = Color(0xFFE2E2E8);

  // ============ Leaderboard Podium ============
  static const silver = Color(0xFF9AA6B4);
  static const silverLight = Color(0xFF5B6B7C);
  static const bronze = Color(0xFFB66A3A);
  static const bronzeLight = Color(0xFF8A4E24);

  // ============ Shimmer Skeleton ============
  // 2026-07-24 canlı denetim: iskelet (shimmer) tonları eski indigo/pembe
  // paletten kalmıştı — sıcak kâğıt zemin üzerinde lavanta mor bloklar
  // beliriyordu ve uygulama yüklenirken başka bir uygulama gibi görünüyordu.
  static const shimmerBaseLight = Color(0xFFEDE7DC);
  static const shimmerBaseDark = Color(0xFF1E2822);
  static const shimmerHighlightLight = Color(0xFFF7F3EC);
  static const shimmerHighlightDark = Color(0xFF283429);

  // ============ Status Indicators ============
  static const onlineGreen = Color(0xFF4CAF50);
  static const offlineGrey = Color(0xFF9E9E9E);

  // Compat aliases for screens not yet migrated
  static const page = bg;
  static const ink = textPrimary;
  static const muted = textMuted;
  static const green = correct;
  static const red = wrong;
  static const brown = gold;
  static const line = border;

  // ============ Gradient Constants ============
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryGradientStart, primaryGradientEnd],
  );

  static const darkAuthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, bgDeep],
  );

  static const homeHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF173C2D), Color(0xFF1E4A38), Color(0xFF245440)],
  );

  static const bgGradient = darkAuthGradient;

  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  /// Yalnız gerçek birincil eylemler için tema uyumlu CTA rengi.
  static Color primaryCtaColor(BuildContext context) =>
      isLight(context) ? const Color(0xFFD4650A) : brand;

  // Private helpers for theme checks
  static bool _isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static LinearGradient backgroundGradient(BuildContext context) {
    if (!isLight(context)) return bgGradient;
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightBg, lightBgDeep],
    );
  }

  static LinearGradient shimmerGradient(
    BuildContext context,
    double animValue,
  ) {
    final isLight = _isLight(context);
    final baseColor = isLight ? shimmerBaseLight : shimmerBaseDark;
    final shimmerColor = isLight ? shimmerHighlightLight : shimmerHighlightDark;
    return LinearGradient(
      begin: Alignment(-1.0 + animValue, -0.5),
      end: Alignment(1.0 + animValue, 0.5),
      colors: [baseColor, shimmerColor, baseColor],
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

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFC7A22A)], // Softer gold gradient
  );

  static const correctGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [correct, Color(0xFF2D8250)],
  );

  static const wrongGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [wrong, Color(0xFFC53F2B)],
  );

  static List<BoxShadow> shadow3D(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.3),
        offset: const Offset(0, 4),
        blurRadius: 0,
      ),
    ];
  }

  // ============ Card Type System ============
  static BoxDecoration cardDecorationByType(
    BuildContext context, {
    CardType type = CardType.secondary,
    LinearGradient? gradient,
    double radius = cardRadius,
  }) {
    final isDark = _isDark(context);
    switch (type) {
      case CardType.primary:
        final colors = gradient?.colors ?? [brand, brandDeep];
        final grad =
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            );
        return BoxDecoration(
          gradient: grad,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: brand.withValues(alpha: isDark ? 0.2 : 0.1),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        );
      case CardType.secondary:
        return BoxDecoration(
          color: surfaceColor(context),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor(context), width: 1.0),
          boxShadow: cardShadow(context),
        );
      case CardType.info:
        return BoxDecoration(
          color: surfaceColor(context),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor(context).withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  (isDark ? const Color(0xFF000000) : const Color(0xFF000000))
                      .withValues(alpha: isDark ? 0.1 : 0.02),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        );
      case CardType.glass:
        return glassDecoration(context, borderRadius: radius);
    }
  }

  // Muted, elegant gradients replacing the neon ones
  static const List<List<Color>> categoryGradients = [
    [Color(0xFFD47C3B), Color(0xFFC0672A)], // Muted Orange
    [Color(0xFFB54C6F), Color(0xFF9E3C5B)], // Muted Rose
    [Color(0xFF3B6FB8), Color(0xFF2E5A9D)], // Muted Blue
    [Color(0xFFC4A020), Color(0xFFA88818)], // Sari-Altin
    [Color(0xFF2B8A50), Color(0xFF227542)], // Muted Green
    [Color(0xFF8B3A5A), Color(0xFF742E4A)], // Bordo
    [Color(0xFF7048B8), Color(0xFF5D3A9E)], // Doygun Mor
    [Color(0xFF1E8A7A), Color(0xFF177064)], // Acik Turkuaz
  ];

  /// A/B/C/D şık harflerinin kimlik renkleri.
  ///
  /// Kırmızı ve yeşil bilerek dışarıda: quiz bağlamında bu iki renk
  /// "yanlış" ve "doğru" demektir. Cevaplamadan önce A'yı kırmızı, C'yi
  /// yeşil göstermek kullanıcıya sahte bir ipucu veriyordu (2026-07-22
  /// canlı UX denetimi). Geri bildirim renkleri (correct/wrong) yalnız
  /// cevap verildikten sonra kullanılır.
  /// Şık harflerinin (A/B/C/D) rozet rengi.
  ///
  /// 2026-07-24 canlı denetim: dört şık dört ayrı doygun renk taşıyordu
  /// (mavi/mor/camgöbeği/kehribar). Renk burada hiçbir anlam taşımıyor —
  /// oyuncu "mavi şık" ile "mor şık" arasında bir fark sanıyordu. Tonlar
  /// tek bir nötr aileye indirildi; renk yalnız doğru/yanlış anında konuşur.
  /// Şık rozetlerinin tonu (A/B/C/D) — dördü de aynı nötr.
  ///
  /// 2026-07-27'de bunlara marka renkleri verilmişti: ekran daha canlı
  /// görünüyordu ama `answer_option_color_semantics_test` haklı olarak
  /// kırdı. Karar iki ayrı canlı denetimde verilmiş: renkli şık harfleri
  /// oyuncuya şıklar arasında bir *fark* olduğunu ima ediyor, üstelik
  /// yeşil/kırmızıya yaklaşan tonlar cevaptan önce sahte "doğru/yanlış"
  /// ipucu veriyor. Şık harfi yalnız bir etikettir; renk yalnız cevaptan
  /// sonra konuşur.
  ///
  /// Bu ekranı canlandırmanın yolu şıkları boyamak değil — kart tonu,
  /// kategori kimliği ve eylem düğmesi üzerinden gidilir.
  static const List<Color> answerOptionColors = [
    Color(0xFF545C63),
    Color(0xFF545C63),
    Color(0xFF545C63),
    Color(0xFF545C63),
  ];

  static LinearGradient categoryGradient(int index) {
    final colors = categoryGradients[index % categoryGradients.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  // Decorative gradients for QuickPlayGrid tiles (Muted tones)
  static const List<Color> duelGradient = [
    Color(0xFFB54C6F), // Muted rose
    Color(0xFF9E3C5B),
  ];
  static const List<Color> tournamentGradient = [
    Color(0xFF288077), // Muted teal
    Color(0xFF1E6962),
  ];

  static const ctaTeal = Color(0xFF288077);
  static const ctaTealDeep = Color(0xFF1E6962);
  static const List<Color> ctaTealGradient = [ctaTeal, ctaTealDeep];
  static const List<Color> ctaBrandGradient = [brand, brandDeep];

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: darkBg,
      // Klavye odağı görünürlüğü (WCAG 2.4.7): belirgin marka rengi vurgusu.
      focusColor: accent.withValues(alpha: 0.35),
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
        // AppBar, kendi `systemOverlayStyle`ını uygulama kökündeki
        // AnnotatedRegion'ın üzerine yazar. Belirtilmezse Material bunu
        // AppBar zemininden türetir; zemin saydam olduğu için yanlış
        // parlaklık seçilip saat/pil okunmaz hale geliyordu (2026-07-25
        // canlı denetimi). Değer temayla birlikte açıkça sabitlenir.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
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
          // Pasif hâl Material'ın gri levhasına düşüyordu: ekranın en
          // büyük öğesi (kaydet, sonraki, satın al) ölü bir gri blok
          // oluyor ve arayüz bozuk görünüyordu. Marka renginin soluk tonu
          // "henüz değil" der, "bozuk" demez (2026-07-27).
          disabledBackgroundColor: accent.withValues(alpha: 0.12),
          disabledForegroundColor: accent.withValues(alpha: 0.55),
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
        // Doğrulama hatası varsayılan Material stiliyle çiziliyordu ve
        // krem/koyu yüzeyler üzerinde neredeyse okunmuyordu (2026-07-25
        // canlı denetimi). Renk ve kalınlık açıkça sabitlenir.
        errorStyle: const TextStyle(
          color: formErrorDark,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          height: 1.3,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: formErrorDark, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: formErrorDark, width: 2),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
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
      // Klavye odağı görünürlüğü (WCAG 2.4.7): belirgin marka rengi vurgusu.
      focusColor: accent.withValues(alpha: 0.30),
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
        // Bkz. koyu temadaki aynı alan: saydam AppBar zemininden türetilen
        // varsayılan, açık temada beyaz ikon seçip krem zeminde saati
        // görünmez kılıyordu.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
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
          // Pasif hâl Material'ın gri levhasına düşüyordu: ekranın en
          // büyük öğesi (kaydet, sonraki, satın al) ölü bir gri blok
          // oluyor ve arayüz bozuk görünüyordu. Marka renginin soluk tonu
          // "henüz değil" der, "bozuk" demez (2026-07-27).
          disabledBackgroundColor: accent.withValues(alpha: 0.12),
          disabledForegroundColor: accent.withValues(alpha: 0.55),
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
        errorStyle: const TextStyle(
          color: formErrorLight,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          height: 1.3,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: formErrorLight, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: formErrorLight, width: 2),
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
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
  // Removed static const shimmerGradient – replaced by shimmerGradient(context, animValue) method below.

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

  /// Renkli vurgu gölgesi. 2026-07-24: "neon glow" iki katmandan tek, yumuşak
  /// katmana indirildi ve şiddeti yarıya çekildi — parlayan kenarlar ekranı
  /// oyuncak gibi gösteriyor ve altındaki kartın kenarlığını yutuyordu.
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity * 0.5),
        blurRadius: 18,
        offset: const Offset(0, 6),
        spreadRadius: -6,
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

  /// Home teaser kartları için daha rafine, hafif tonda yüzey.
  static BoxDecoration teaserCardDecoration(
    BuildContext context, {
    required Color accent,
    double radius = 16,
  }) {
    final isDark = _isDark(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surfaceColor(context),
          isDark
              ? accent.withValues(alpha: 0.08)
              : accent.withValues(alpha: 0.045),
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? accent.withValues(alpha: 0.28)
            : accent.withValues(alpha: 0.18),
      ),
      boxShadow: cardShadow(context),
    );
  }

  /// Section title accent — colored vertical bar on the left edge.
  static BoxDecoration sectionAccent(Color color) {
    return BoxDecoration(borderRadius: BorderRadius.circular(2), color: color);
  }

  /// Stat/metric card decoration (profile, result screens).
  static BoxDecoration statCard(BuildContext context, Color accentColor) {
    final isDark = _isDark(context);
    // Dark temada kenarlık ve gölge güçlendirilir; aksi halde kart sınırı
    // koyu zeminde silik kalıyordu (istatistik kart kontrast sorunu).
    return BoxDecoration(
      color: surfaceColor(context),
      borderRadius: BorderRadius.circular(cardRadiusSmall),
      border: Border.all(
        color: accentColor.withValues(alpha: isDark ? 0.38 : 0.2),
        width: isDark ? 1.1 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: isDark ? 0.14 : 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
