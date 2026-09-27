import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  const AppColors._();

  static const focus = AppTheme.primaryGradientStart;

  static Color disabledSurface(BuildContext context) =>
      AppTheme.isLight(context)
      ? const Color(0xFFEDE9E3)
      // Koyu ton `#282A36`ydı: maviye çalan bir gri, markanın orman
      // ailesinde yeri yok. Soru tahtasında pasif "Kontrol bike" yeşil
      // kartın üstünde mora kaçan bir leke gibi duruyordu (2026-09-27
      // simülatör turu). Aynı koyulukta, orman ailesinden doygunluğu
      // düşük bir gri; soluk metinle karşıtlık ~6.3.
      : const Color(0xFF25302A);

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
    fontWeight: FontWeight.w700,
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
    fontWeight: FontWeight.w600,
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

  /// İçerik kartı: surface + border + orta shadow.
  secondary,

  /// Bilgi kartı: sadece border + minimal shadow (istatistik, yardımcı).
  info,
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
  static const double panelRadius = AppRadius.card;

  /// İçerik kartlarını zeminden ayıran tek, düşük yoğunluklu yüzey gölgesi.
  /// Hiyerarşiyi bağırmadan verir; yüzen katmanlar için daha güçlü
  /// [floatingShadow] token'ı ayrı tutulur.
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = _isDark(context);
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.07),
        offset: const Offset(0, 3),
        blurRadius: 12,
        spreadRadius: -4,
      ),
    ];
  }

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

  // ============ ZanKurd Design 2.0 — Forest / Ember / Cream ============
  // Kaynak: docs/ZANKURD_DESIGN_2.md. Uygulamanın kimliği Forest, ana
  // eylemi Ember, ödül vurgusu Sun ve okuma yüzeyi Cream ailesinden gelir.
  //
  // Design 2 belgesindeki Ember 600 (#C9530A) beyaz metinle 4.44:1'de
  // kaldığı için CTA tokenı aynı renk ailesinde çok küçük koyulaştırılmıştır.
  // #C75209 beyazla 4.52:1 ölçülür ve normal metin için WCAG AA'yı geçer.
  static const brand = Color(0xFFC75209); // Accessible Ember 600 / Tîrêj
  static const brandDeep = Color(0xFFA03B0A);

  /// Gradyanın açık ucu — yalnız birincil CTA'da kullanılır.
  static const brandLite = Color(0xFFE06A16); // Ember 500

  // Kesk — marka kimliği (başlık şeritleri, kimlik yüzeyleri).
  static const culturalBrandBg = Color(0xFF20533A); // Forest 700

  // Yardımcı/kategori aksanları. Design 2 kategori renklerini korur fakat
  // doygun blok yerine işaret/rota vurgusu olarak kullanır.
  static const playGreen = Color(0xFF2F7450); // Forest 600
  static const playPink = Color(0xFFA85A7A);
  static const playCyan = Color(0xFF2F6F62);
  static const playPurple = Color(0xFF6B5AA6);

  /// Yarışın rengi (Madder). Ana ekranın "Arkadaşınla yarış" kapısı ve
  /// eski düello satırı aynı tonu satır içi sabitle taşıyordu; tek ad
  /// altında toplandı. Turuncu CTA'dan (brand) bilerek ayrıdır: yarış kapısı
  /// bir yöndür, ekranın birincil eylemi değil.
  static const playRed = Color(0xFFB31E3B);

  // ============ Dark Mode Palette — Forest ============
  static const primaryGradientStart = brand;
  static const primaryGradientEnd = brandDeep;

  // Zêr — yalnız ödül/ilerleme (XP, kredi, 1. sıra).
  static const secondaryAccent = Color(0xFFE9A91B); // Sun 500
  static const gold = Color(0xFFE9A91B); // Sun 500

  static const cyan = playCyan;

  static const bg = Color(0xFF0A1712); // Forest 950
  static const bgDeep = Color(0xFF06100C);
  static const surface = Color(0xFF10251C); // Forest 900
  static const surfaceHi = Color(0xFF17382A); // Forest 800
  static const darkBg = bg;

  static const textPrimary = Color(0xFFFBF7EE); // Cream 50
  static const textSub = Color(0xFFD5DDD6);
  static const textMuted = Color(0xFFA6B3AA);

  static const border = Color(0xFF20533A); // Forest 700

  static const accent = primaryGradientStart;
  static const violet = secondaryAccent;
  static const correct = Color(0xFF3DA968);
  static const wrong = Color(0xFFE5533D);

  /// Form doğrulama hatası metni.
  static const formErrorLight = Color(0xFFDC2626);
  static const formErrorDark = Color(0xFFF87171);

  // Onboarding 2. slayt: ödül/yarış teması için terracotta tonu.
  static const terracotta = Color(0xFFEA580C);

  /// Solo sonuç vitrininin kutlama gradyanı.
  static const celebrationInk = Color(0xFF0A1712);
  static const celebrationGreen = culturalBrandBg;

  // 1v1 sonuç ekranı — kazanma/kaybetme gradyanının koyu gölge renkleri.
  static const correctDeep = Color(0xFF064E3B); // Win gradient shadow
  static const wrongDeep = Color(0xFF7F1D1D); // Lose gradient shadow

  /// 1v1 sonuç başlığının AÇIK ucu — `correct`/`wrong`un okunur hâli.
  static const correctHeader = Color(0xFF20533A);
  static const wrongHeader = Color(0xFFDC2626);

  // ============ Light Mode Palette — Cream / Ink ============
  static const lightBg = Color(0xFFFBF7EE); // Cream 50
  static const lightBgDeep = Color(0xFFF4EBDD); // Cream 100
  static const lightSurface = Color(0xFFFFFDF8);
  static const lightSurfaceHi = Color(0xFFFBF7EE);
  static const lightBorder = Color(0xFFE7ECE6); // Mist
  static const lightTextPrimary = Color(0xFF171812); // Ink 950
  static const lightTextSub = Color(0xFF4D554E);
  static const lightTextMuted = Color(0xFF687169);

  static const pirsOrangeStart = culturalBrandBg;
  static const pirsOrangeEnd = culturalBrandBg;

  static const answerOptionBg = lightSurface;
  static const answerOptionBorder = lightBorder;

  // ============ Leaderboard Podium ============
  static const silver = Color(0xFF94A3B8);
  static const silverLight = Color(0xFF64748B);
  static const bronze = Color(0xFFD97706);
  static const bronzeLight = Color(0xFFB45309);

  // ============ Shimmer Skeleton ============
  static const shimmerBaseLight = Color(0xFFE7ECE6);
  static const shimmerBaseDark = surfaceHi;
  static const shimmerHighlightLight = lightBg;
  static const shimmerHighlightDark = culturalBrandBg;

  // ============ Status Indicators ============
  static const onlineGreen = playGreen;
  static const offlineGrey = Color(0xFF96A09A);

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

  static const identityHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [culturalBrandBg, playGreen],
  );

  /// Durum çubuğunun altına koyu bir başlık (orman şeridi, kategori görseli)
  /// giren ekranların durum çubuğu stili: açık saat ve pil ikonları.
  ///
  /// Uygulama kökü stili temadan seçer; açık temada ikonlar koyudur. Ad
  /// ekranının orman şeridi ve kategori ekranının görsel başlığı ise tam
  /// durum çubuğunun altına uzanır — koyu yeşil üstünde koyu saat ve pil
  /// okunmuyordu (2026-09-27 simülatör turu).
  static const overlayOnDarkHeader = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  );

  static const darkAuthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg, bgDeep],
  );

  // `homeHeaderGradient` burada duruyordu ve hiçbir yerde kullanılmıyordu.
  // 2026-08-01'de silindi: ana ekran başlık şeridi BİLEREK düz renktir ve
  // iki ayrı karar onu öyle tutuyor —
  //
  //   1. Gradyan "buraya bas" demektir, ekran başına bir tane; ana
  //      ekranınki "Başla" düğmesinin (kulturel_modern_home_test).
  //   2. Şeride süs koymak 2026-07-24'te denendi ve geri alındı: dekoratif
  //      daireler ve yıldız filigranı metnin kontrastını düşürüyordu.
  //
  // Kullanılmayan bir token, kararı bilmeyen herkesi onu kullanmaya davet
  // eder — 2026-07-31 denetimi de "ölü token" diye bildirdi, ardından
  // gradyan denendi ve test kırıldı. Token yoksa davet de yok.

  static const bgGradient = darkAuthGradient;

  static bool isLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light;
  }

  /// Yalnız gerçek birincil eylemler için tema uyumlu CTA rengi.
  static Color primaryCtaColor(BuildContext context) => brand;

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

  // Quiz şık kartlarının cevap durumları. Bu iki gradyanın ÜZERİNE beyaz metin
  // yazılır (`quiz_option_tile.dart`), dolayısıyla her iki durak da WCAG AA'yı
  // geçmek zorundadır.
  //
  // 2026-08-02: gradyanlar `correct`/`wrong` sabitlerinden başlıyordu ve
  // başlangıç duraklarında beyaz metin **2.97:1** (doğru) ve **3.73:1**
  // (yanlış) veriyordu — ikisi de 4.5:1 eşiğinin altında, biri 3:1'in bile
  // altında. Etiket 17px/w800; WCAG'ın kalın "büyük metin" eşiği 18.67px
  // olduğundan normal metin eşiği (4.5:1) geçerlidir. Kusur uygulamanın en
  // çok görüntülenen yüzeyindeydi ve hiçbir test onu ölçmüyordu.
  //
  // Duraklar aynı HSL tonunda (yeşil 144°, kırmızı 8°) koyulaştırıldı; marka
  // ailesi korunur, derinlik hissi korunur ve dört durak da AA'yı geçer.
  // Oranlar `contrast_policy_test.dart` ile sabitlenmiştir.
  //
  // `correct`/`wrong` sabitlerinin KENDİLERİ değiştirilmedi: onlar kenarlık,
  // ikon ve açık zemin üstü metin için kullanılıyor ve kendi testleri var.
  static const correctGradientStart = Color(0xFF308452); // beyazla 4.62:1
  static const correctGradientEnd = Color(0xFF266A42); // beyazla 6.52:1
  static const wrongGradientStart = Color(0xFFDB361D); // beyazla 4.61:1
  static const wrongGradientEnd = Color(0xFFB02C18); // beyazla 6.52:1

  static const correctGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [correctGradientStart, correctGradientEnd],
  );

  static const wrongGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [wrongGradientStart, wrongGradientEnd],
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
  /// Şık indeksi rengi — DÖRDÜ DE AYNI nötr tondur, bilerek.
  ///
  /// 2026-08-03'te bu liste kategori paletinden dört ayrı renge çevrildi
  /// (zümrüt/safir/madder/safran) ve `answer_option_color_semantics_test`
  /// haklı olarak kırdı. İki ayrı denetimin kaldırdığı şey geri gelmişti:
  /// quiz bağlamında yeşil "doğru", kırmızı "yanlış" demektir; oyuncu
  /// cevaplamadan ÖNCE A'yı yeşil, C'yi kırmızı görmek sahte ipucudur.
  /// Dört doygun ton ayrıca şıklar arasında bir fark olduğunu ima eder,
  /// oysa şık harfi yalnız bir etikettir.
  ///
  /// Rengîn kimliği şıklara renkten değil GEOMETRİDEN gelir: rozet artık
  /// elmas. Karakter kazanıldı, sahte ipucu kazanılmadı.
  ///
  /// Ton `#545C63` griden önce mürekkep ailesine, 2026-09-10'da sıcak
  /// antrasite çekildi — aynı nötr işlevi görür ama markanın
  /// krem/yeşil/turuncu ailesiyle akrabadır. Doygunluk 0.19 (< 0.35
  /// tavanı), hue ~46°: doğru (144°) ve yanlış (8°) hue'larından 30°'den
  /// fazla uzak — bekçisi `answer_option_color_semantics_test`.
  static const List<Color> answerOptionColors = [
    Color(0xFF413C2C),
    Color(0xFF413C2C),
    Color(0xFF413C2C),
    Color(0xFF413C2C),
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

  /// Dekoratif teal — CTA için KULLANILMAZ.
  ///
  /// Birincil eylemler yalnız [primaryCtaColor] / [brand] kullanır.
  /// Bu teal yalnız çark segmenti ve turnuva gradyanı gibi dekoratif
  /// yüzeyler içindir; yeni CTA butonu için referans alınmamalı.
  static const ctaTeal = Color(0xFF288077);
  static const ctaTealDeep = Color(0xFF1E6962);
  static const List<Color> ctaTealGradient = [ctaTeal, ctaTealDeep];
  static const List<Color> ctaBrandGradient = [brand, brandDeep];

  /// Diyalog. Uygulamadaki 11 diyalog şeklini tek tek veriyordu (altısı
  /// düz `16`, dördü `AppRadius.md`, biri `AppRadius.lg`), seri-dondurma
  /// diyaloğu ise hiç vermiyor ve Material varsayılanına — 28px, kenarlıksız
  /// — düşüyordu. Aynı uygulamada iki ayrı diyalog dili oluyordu
  /// (2026-07-31 denetimi). Karar artık temada tek yerde.
  static DialogThemeData _dialogTheme({
    required Color background,
    required Color title,
    required Color body,
    required Color border,
  }) {
    return DialogThemeData(
      backgroundColor: background,
      surfaceTintColor: background,
      titleTextStyle: TextStyle(
        color: title,
        fontFamily: AppTypography.fontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
      contentTextStyle: TextStyle(
        color: body,
        fontFamily: AppTypography.fontFamily,
        fontSize: 14,
        height: 1.45,
      ),
      // 2026-09-25: kenarlık ve yarıçap burada tek yerde tanımlanıyor.
      // Onlarca ekran `AlertDialog`'u `backgroundColor` + `shape` +
      // `BorderSide` üçlüsüyle elle kuruyordu; aynı sayılar farklı
      // yardımcılarla (`surfaceOf` / `surfaceColor`) yazıldığı için
      // ekranlar birbirinden ayrışıyordu. Kenarlık tema sayesinde korunuyor,
      // tekrar gereksiz.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: border),
      ),
    );
  }

  /// Kaydırıcı. `inactiveTrackColor` verilmediğinde M3 varsayılanı
  /// `surfaceContainerHighest`tir; şema eksikken bu `surface`e düşüyor ve
  /// pasif ray, üstünde durduğu kartla birebir aynı renk oluyordu —
  /// kullanıcı sesin ya da hızın nereye kadar gidebileceğini göremiyordu
  /// (Ayarlar → seslendirme, soru öner → zorluk; 2026-07-31 denetimi).
  ///
  /// Şema artık tam olsa da ray burada AÇIKÇA veriliyor: tek tek çağrı
  /// yerlerini yamamak yerine tek yerde karar veriliyor, sonradan
  /// eklenecek kaydırıcılar da aynı tuzağa düşmüyor.
  static SliderThemeData _sliderTheme({required Color track}) {
    return SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: track,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.12),
      trackHeight: 4,
    );
  }

  /// Bildirim saati seçici. Temasızken uygulamanın ortasında bir anda
  /// başka bir uygulamadan gelmiş gibi duruyordu: kadran diski zeminle
  /// aynı renk (görünmüyor), seçili kutu tam doygun marka turuncusu,
  /// alan kenarlığı ise metin rengi kadar sert.
  static TimePickerThemeData _timePickerTheme({
    required Color background,
    required Color dial,
    required Color idleField,
    required Color idleText,
    required Color selectedField,
    required Color selectedText,
    required Color outline,
  }) {
    return TimePickerThemeData(
      backgroundColor: background,
      dialBackgroundColor: dial,
      dialHandColor: accent,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? selectedField : idleField,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? selectedText : idleText,
      ),
      dayPeriodColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? selectedField
            : Colors.transparent,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? selectedText : idleText,
      ),
      dayPeriodBorderSide: BorderSide(color: outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }

  /// Bölünmüş düğme (Gözden Geçir → Liste / Flaşkart). Stilsizken seçili
  /// segmentin zemini `secondaryContainer`a, o da eksik şemada altına
  /// düşüyordu: beyaz metin altın zeminde 2,30:1 — AA eşiğinin yarısı.
  static SegmentedButtonThemeData _segmentedButtonTheme({
    required Color selectedBg,
    required Color selectedFg,
    required Color idleFg,
    required Color outline,
  }) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? selectedBg
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selectedFg : idleFg,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selectedFg : idleFg,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: outline)),
      ),
    );
  }

  /// Soru ekranının SAHNE teması — uygulama teması ne olursa olsun koyu.
  ///
  /// Uygulamanın geri kalanı bir belge gibi okunur ve kullanıcının açık/
  /// karanlık tercihine uyar. Soru ekranı ise bir belge değil, bir andır:
  /// süre işler, seri kırılır, rakip cevap verir. Sinema salonu gibi
  /// karartmak dikkati soruya toplar ve altın kilim ipliğini tek parlak
  /// öğe hâline getirir — açık krem zeminde altın kayboluyordu.
  ///
  /// Tek noktadan uygulanır: gövde `Theme` ile sarılınca `isLight` ve ona
  /// dayanan bütün renk yardımcıları (`surfaceColor`, `borderColor`,
  /// `QuizOptionTile` gradyanları) kendiliğinden koyu değerlere döner.
  /// Bileşen bileşen renk geçmek gerekmez; geçilseydi ilk eklenen yeni
  /// şık türü sessizce açık temada kalırdı.
  ///
  /// Her karede `dark()` çağırmak `ThemeData` kurulumunu tekrarlar; sabit
  /// olduğu için bir kez üretilir.
  static final ThemeData stage = dark();

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: darkBg,
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      // Klavye odağı görünürlüğü (WCAG 2.4.7): belirgin marka rengi vurgusu.
      focusColor: accent.withValues(alpha: 0.35),
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: Colors.white,
        secondary: playGreen,
        onSecondary: Colors.white,
        tertiary: gold,
        onTertiary: Color(0xFF171812),
        error: wrong,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
        // ── Aşağıdaki roller 2026-07-31'e kadar TANIMSIZDI ────────────
        //
        // Şema yalnız 10 rolle kuruluyordu; gerisi Flutter'ın getter
        // fallback'lerine düşüyordu (color_scheme.dart): surfaceContainer*
        // → surface, primaryContainer → primary, outline → onSurface.
        // Yani "container" tonları üstünde durdukları yüzeyle BİREBİR AYNI
        // renk oluyor, "outline" ise metin rengi kadar sert çıkıyordu.
        //
        // Üç görünür kusur bunun doğrudan sonucuydu: Ayarlar'daki
        // kaydırıcının pasif rayı kartla aynı renkti (nereye kadar
        // gittiği görünmüyordu), bildirim saati seçicisinin kadran diski
        // zeminde kayboluyordu, ve Gözden Geçir'deki SegmentedButton
        // seçili sekmesinde beyaz metin altın zeminde 2,30:1 kalıyordu.
        //
        // Container tonları aksanın yüzey üzerine %14 harmanıdır; "on"
        // karşılıkları rengin tonunu koruyup açıklığını AA (4,5:1)
        // eşiğini geçene dek zeminden uzaklaştırarak hesaplandı — aynı
        // yöntem `AppColors.onAccentTint` içinde çalışma zamanında da var.
        surfaceContainerLowest: bgDeep,
        surfaceContainerLow: bg,
        surfaceContainer: surface,
        surfaceContainerHigh: surfaceHi,
        surfaceContainerHighest: culturalBrandBg,
        onSurfaceVariant: textSub,
        outline: border,
        outlineVariant: surfaceHi,
        primaryContainer: Color(0xFF2B160C),
        onPrimaryContainer: brandLite,
        secondaryContainer: surfaceHi,
        onSecondaryContainer: Color(0xFFB9D7C5),
        tertiaryContainer: Color(0xFF332A13),
        onTertiaryContainer: gold,
        errorContainer: Color(0xFF2E1515),
        onErrorContainer: Color(0xFFF87171),
        surfaceTint: surface,
        inverseSurface: lightBg,
        onInverseSurface: surface,
        inversePrimary: brand,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontFamily: 'Rubik',
          fontWeight: FontWeight.w700,
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
          // Pasif hâl aynı turuncunun soluk alpha'sıydı: Kaydet koyu
          // panelde kayboluyordu (2026-09-03 simülatör). Opak karışım +
          // açık yazı okunur; «henüz değil» izlenimi kalır.
          disabledBackgroundColor: Color.alphaBlend(
            accent.withValues(alpha: 0.55),
            surfaceHi,
          ),
          disabledForegroundColor: const Color(0xFFFFF6ED),
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
      dialogTheme: _dialogTheme(
        background: surfaceHi,
        title: textPrimary,
        body: textSub,
        border: border,
      ),
      sliderTheme: _sliderTheme(track: border),
      timePickerTheme: _timePickerTheme(
        background: surface,
        dial: surfaceHi,
        idleField: surfaceHi,
        idleText: textPrimary,
        selectedField: const Color(0xFF302819),
        selectedText: const Color(0xFFED6911),
        outline: border,
      ),
      segmentedButtonTheme: _segmentedButtonTheme(
        selectedBg: accent,
        selectedFg: Colors.white,
        idleFg: textSub,
        outline: border,
      ),
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
          fontWeight: FontWeight.w700,
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

  static BoxDecoration identityHeaderDecoration(
    BuildContext context, {
    double radius = cardRadius,
  }) {
    // Sayfa kimliği artık ikinci bir hero değildir. Büyük marka gradyanı,
    // hemen altındaki asıl CTA/hero ile yarışıyor ve çok sayıda ekranda
    // "renkli panel + renkli panel" yığını oluşturuyordu. Kimlik yüzeyi
    // ortak, sakin bir kart geometrisi taşır; ekrana özgü renk yalnız
    // ScreenIdentityHeader içindeki küçük amblemde yaşar.
    return BoxDecoration(
      color: surfaceColor(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor(context).withValues(alpha: 0.72)),
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Rubik',
      scaffoldBackgroundColor: lightBg,
      cardTheme: const CardThemeData(
        color: lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
      ),
      // Klavye odağı görünürlüğü (WCAG 2.4.7): belirgin marka rengi vurgusu.
      focusColor: accent.withValues(alpha: 0.30),
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: accent,
        onPrimary: Colors.white,
        secondary: playGreen,
        onSecondary: Colors.white,
        tertiary: gold,
        onTertiary: lightTextPrimary,
        error: wrong,
        onError: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        // Karanlık temadaki ile aynı gerekçe — bkz. `dark()`.
        surfaceContainerLowest: lightSurface,
        surfaceContainerLow: lightSurfaceHi,
        surfaceContainer: lightBgDeep,
        surfaceContainerHigh: Color(0xFFEEE5D8),
        surfaceContainerHighest: lightBorder,
        onSurfaceVariant: lightTextSub,
        outline: lightBorder,
        outlineVariant: lightBgDeep,
        primaryContainer: Color(0xFFF5DDCB),
        onPrimaryContainer: brandDeep,
        secondaryContainer: Color(0xFFDCE8E0),
        onSecondaryContainer: culturalBrandBg,
        tertiaryContainer: Color(0xFFF8E8B8),
        onTertiaryContainer: Color(0xFF6B4B00),
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFFB91C1C), // 4,61:1
        surfaceTint: lightSurface,
        inverseSurface: bg,
        onInverseSurface: textPrimary,
        inversePrimary: brandLite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: lightTextPrimary,
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontFamily: 'Rubik',
          fontWeight: FontWeight.w700,
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
          disabledBackgroundColor: Color.alphaBlend(
            accent.withValues(alpha: 0.28),
            lightSurfaceHi,
          ),
          disabledForegroundColor: const Color(0xFF4A2508),
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
      dialogTheme: _dialogTheme(
        background: lightSurface,
        title: lightTextPrimary,
        body: lightTextSub,
        border: lightBorder,
      ),
      sliderTheme: _sliderTheme(track: const Color(0xFFE9E4DA)),
      timePickerTheme: _timePickerTheme(
        background: lightSurface,
        dial: lightBgDeep,
        idleField: lightSurfaceHi,
        idleText: lightTextPrimary,
        selectedField: const Color(0xFFF6E7DD),
        selectedText: const Color(0xFFAA4B0C),
        outline: lightBorder,
      ),
      segmentedButtonTheme: _segmentedButtonTheme(
        selectedBg: accent,
        selectedFg: Colors.white,
        idleFg: lightTextSub,
        outline: lightBorder,
      ),
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
