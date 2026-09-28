import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sahne.dart';

class AppColors {
  const AppColors._();

  static const focus = AppTheme.primaryGradientStart;

  static Color disabledSurface(BuildContext context) =>
      AppTheme.isLight(context)
      ? const Color(0xFFEEF1F8)
      // Koyu ton `#282A36`ydı: maviye çalan bir gri, markanın orman
      // ailesinde yeri yok. Soru tahtasında pasif "Kontrol bike" yeşil
      // kartın üstünde mora kaçan bir leke gibi duruyordu (2026-09-27
      // simülatör turu). Aynı koyulukta, orman ailesinden doygunluğu
      // düşük bir gri; soluk metinle karşıtlık ~6.3.
      // Şahnê: pasif öğe Perde (s1) + üçüncül metin; opaklıkla değil.
      : SahneTokens.night.s1;

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
    const ink = Color(0xFF1B0C02);
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
    return secondary ? SahneTokens.night.tx2 : AppTheme.textPrimary;
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

  /// Metin ailesi (Onest). Başlık ailesi [SahneType.display].
  ///
  /// Widget'lar bunu temadan alır; `CustomPainter` içinde `TextPainter` ile
  /// çizilen metin **almaz** ve aile yazılmazsa sistem varsayılanına düşer.
  /// Tek bir ekranda iki ayrı yazı tipi görünmesin diye o çağrı yerleri
  /// buradan besleniyor (2026-07-26: çark rakamları ve haftalık grafik
  /// etiketleri böyleydi).
  static const fontFamily = SahneType.text;

  // 2026-09-29 Şahnê: eski yedi stil (32/24/18/17/16/15/12) beş boyutlu
  // ölçeğe eşlendi (64 · 28 · 22 · 16 · 14). Adlar, taşınmamış ekranlar da
  // aynı ölçeği alsın diye korunuyor.
  static const TextStyle display = SahneType.title;
  static const TextStyle heading1 = SahneType.title;
  static const TextStyle heading2 = SahneType.headline;
  static const TextStyle subtitle = SahneType.bodyStrong;
  static const TextStyle bodyLarge = SahneType.body;
  static const TextStyle bodyMedium = SahneType.body;
  static const TextStyle caption = SahneType.caption;

  /// Kategori adı: çizimin ALTINDA durur (Şahnê mücevher karo), çizimin
  /// üstüne yazılmaz; bu yüzden gölge yok.
  static const categoryTitle = TextStyle(
    color: Colors.white,
    fontFamily: SahneType.display,
    fontWeight: FontWeight.w800,
    fontSize: 16,
    height: 24 / 16,
  );

  static const categoryMeta = TextStyle(
    color: Colors.white,
    fontFamily: SahneType.text,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  /// Soru metni. Şahnê: 28'de 4 satırı aşan soru 22'ye iner; bu taban
  /// değer, uyarlama soru ekranında yapılır.
  static const TextStyle quizQuestion = SahneType.headline;

  static const TextStyle quizAnswer = SahneType.bodyStrong;
}

class AppSpacing {
  const AppSpacing._();

  // Şahnê: bütün aralıklar 4'ün katı (bkz. [SahneSpace]).
  static const double xxs = SahneSpace.x1;
  static const double xs = SahneSpace.x2;
  static const double sm = SahneSpace.x3;
  static const double md = SahneSpace.x4;
  static const double lg = SahneSpace.x6;
  static const double xl = SahneSpace.x8;
  static const double xxl = 48;

  static const double page = SahneSpace.page;
  static const double section = SahneSpace.sectionTop;
  static const double cardGap = SahneSpace.cardGap;
  static const double gridGap = SahneSpace.x4;

  // Quiz-specific spacing
  static const double quizQuestionGap = SahneSpace.x5;
  static const double quizOptionGap = SahneSpace.x3;
  static const double quizSectionGap = SahneSpace.x8;
}

/// Köşe değerleri. Şahnê'de köşe yuvarlak değil, kesiktir (45° pah); pah
/// boyları S 4 · M 8 · L 12 ([SahneShape]). `BorderRadius.circular` ile
/// kullanılan eski adlar aynı üç değere indirildi ki taşınmamış bir ekran
/// da ölçeğin dışına çıkmasın.
class AppRadius {
  const AppRadius._();

  static const double xs = SahneShape.sValue;
  static const double sm = SahneShape.mValue;
  static const double md = SahneShape.lValue;
  static const double lg = SahneShape.lValue;
  static const double xl = SahneShape.lValue;
  static const double pill = 99;

  static const double card = SahneShape.lValue;

  static const double badge = SahneShape.sValue;
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
  static const brand = Color(
    0xFFFF8A3D,
  ); // Agir — tek birincil eylem (Şahnê). Üstünde koyu metin.
  static const brandDeep = Color(0xFFE86F24); // Agir basılı / gradyan ucu.

  /// Gradyanın açık ucu — yalnız birincil CTA'da kullanılır.
  static const brandLite = Color(0xFFFF9A57); // Agir metin bağlantısı (gece).

  // Kesk — marka kimliği (başlık şeritleri, kimlik yüzeyleri).
  static const culturalBrandBg = Color(
    0xFF1A2352,
  ); // Sahne kartı üstü (gece kimliği; eski orman yeşili).

  // Yardımcı/kategori aksanları. Design 2 kategori renklerini korur fakat
  // doygun blok yerine işaret/rota vurgusu olarak kullanır.
  static const playGreen = Color(
    0xFF0E7453,
  ); // Zimrût dolgu tonu (beyaz metinle 5.77).
  static const playPink = Color(
    0xFFC4265A,
  ); // Palet dışıydı; Boyax tonuna indirildi.
  static const playCyan = Color(
    0xFF0E7453,
  ); // Palet dışıydı; Zimrût dolgusuna indirildi.
  static const playPurple = Color(
    0xFF29336F,
  ); // Palet dışıydı (profil moru); Ray tonuna indirildi.

  /// Yarışın rengi (Madder). Ana ekranın "Arkadaşınla yarış" kapısı ve
  /// eski düello satırı aynı tonu satır içi sabitle taşıyordu; tek ad
  /// altında toplandı. Turuncu CTA'dan (brand) bilerek ayrıdır: yarış kapısı
  /// bir yöndür, ekranın birincil eylemi değil.
  static const playRed = Color(0xFFC4265A); // Boyax — yarış (lal kök boyası).

  // ============ Dark Mode Palette — Forest ============
  static const primaryGradientStart = brand;
  static const primaryGradientEnd = brandDeep;

  // Zêr — yalnız ödül/ilerleme (XP, kredi, 1. sıra).
  static const secondaryAccent = Color(0xFFF5C24C); // Zêr — ödül ve ışık.
  static const gold = Color(0xFFF5C24C); // Zêr — ödül ve ışık.

  static const cyan = playCyan;

  static const bg = Color(0xFF0A0F2E); // Şev — gece zemini.
  static const bgDeep = Color(0xFF070B22); // Şev koyu.
  static const surface = Color(0xFF131A42); // Perde — gece yüzeyi.
  static const surfaceHi = Color(0xFF1C2455); // Kulis — yükseltilmiş yüzey.
  static const darkBg = bg;

  static const textPrimary = Color(0xFFF6F3EC); // Gece birincil metin.
  static const textSub = Color(0xFFBCC3E4); // Gece ikincil metin.
  static const textMuted = Color(0xFF959DC9); // Gece üçüncül metin (AA geçer).

  static const border = Color(
    0xFF2D3259,
  ); // Gece ayırıcı çizgi (tx2 %14 harmanı).

  static const accent = primaryGradientStart;
  static const violet = secondaryAccent;
  static const correct = Color(0xFF1DB482); // Rast/Zimrût işaret rengi.
  static const wrong = Color(
    0xFFFF7466,
  ); // Şaş — yanlış (kendi tonu, yarıştan ayrı).

  /// Form doğrulama hatası metni.
  static const formErrorLight = Color(0xFFB42318); // Gündüz hata metni.
  static const formErrorDark = Color(0xFFFF7466); // Gece hata metni.

  // Onboarding 2. slayt: ödül/yarış teması için terracotta tonu.
  static const terracotta = Color(0xFFC4265A); // Tanıtım yarış slaytı: Boyax.

  /// Solo sonuç vitrininin kutlama gradyanı.
  static const celebrationInk = Color(0xFF0A0F2E); // Kutlama zemini: Şev.
  static const celebrationGreen = culturalBrandBg;

  // 1v1 sonuç ekranı — kazanma/kaybetme gradyanının koyu gölge renkleri.
  static const correctDeep = Color(0xFF0B4637); // Kazanma gölgesi: Zimrût tonu.
  static const wrongDeep = Color(0xFF45160F); // Kaybetme gölgesi: Şaş tonu.

  /// 1v1 sonuç başlığının AÇIK ucu — `correct`/`wrong`un okunur hâli.
  static const correctHeader = Color(
    0xFF0E7453,
  ); // Kazanma başlığı: Rast dolgusu.
  static const wrongHeader = Color(
    0xFF6B1F1A,
  ); // Kaybetme başlığı: Şaş dolgusu.

  // ============ Light Mode Palette — Cream / Ink ============
  static const lightBg = Color(
    0xFFE9EDF6,
  ); // Gündüz zemini (soğuk; krem değil).
  static const lightBgDeep = Color(0xFFDDE3F0); // Gündüz zemin koyu.
  static const lightSurface = Color(0xFFFFFFFF); // Gündüz yüzeyi.
  static const lightSurfaceHi = Color(0xFFEEF1F8); // Gündüz yükseltilmiş yüzey.
  static const lightBorder = Color(0xFFD3D9E8); // Gündüz kenar.
  static const lightTextPrimary = Color(0xFF0E1433); // Gündüz birincil metin.
  static const lightTextSub = Color(0xFF454E79); // Gündüz ikincil metin.
  static const lightTextMuted = Color(
    0xFF566090,
  ); // Gündüz üçüncül metin (AA geçer).

  static const pirsOrangeStart = culturalBrandBg;
  static const pirsOrangeEnd = culturalBrandBg;

  static const answerOptionBg = lightSurface;
  static const answerOptionBorder = lightBorder;

  // ============ Leaderboard Podium ============
  static const silver = Color(0xFFC9D0EA); // Madalya: gümüş.
  static const silverLight = Color(0xFF5D6694); // Gümüş (gündüz metni).
  static const bronze = Color(0xFFD9925F); // Madalya: bronz.
  static const bronzeLight = Color(0xFF9A5A2A); // Bronz (gündüz metni).

  // ============ Shimmer Skeleton ============
  static const shimmerBaseLight = Color(0xFFDDE3F0); // İskelet yükleyici.
  static const shimmerBaseDark = surfaceHi;
  static const shimmerHighlightLight = lightBg;
  static const shimmerHighlightDark = culturalBrandBg;

  // ============ Status Indicators ============
  static const onlineGreen = playGreen;
  static const offlineGrey = Color(0xFF959DC9); // Çevrimdışı: üçüncül metin.

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
    colors: [gold, Color(0xFFE0A82E)],
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
  static const correctGradientStart = Color(
    0xFF0E7453,
  ); // Rast dolgusu; beyazla 5.77:1.
  static const correctGradientEnd = Color(0xFF0B6146); // Rast dolgusu koyu ucu.
  static const wrongGradientStart = Color(
    0xFF6B1F1A,
  ); // Şaş dolgusu; beyazla ~11:1.
  static const wrongGradientEnd = Color(0xFF5A1813); // Şaş dolgusu koyu ucu.

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
  ///
  /// 2026-09-29 Şahnê: harf karosu Ray (s3) tonudur — sahne her zaman
  /// gece olduğu için gece değeri. Ton ~231°: doğru (Rast, ~160°) ve yanlış
  /// (Şaş, ~5°) tonlarından uzak; dördü yine aynı.
  static const List<Color> answerOptionColors = [
    Color(0xFF29336F),
    Color(0xFF29336F),
    Color(0xFF29336F),
    Color(0xFF29336F),
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
  // Şahnê: düello = yarış sahnesi degradesi; turnuva = gece sahnesi.
  static const List<Color> duelGradient = [
    SahneStageColors.race1,
    SahneStageColors.race2,
  ];
  static const List<Color> tournamentGradient = [
    SahneStageColors.top,
    SahneStageColors.bottom,
  ];

  /// Dekoratif teal — CTA için KULLANILMAZ.
  ///
  /// Birincil eylemler yalnız [primaryCtaColor] / [brand] kullanır.
  /// Bu teal yalnız çark segmenti ve turnuva gradyanı gibi dekoratif
  /// yüzeyler içindir; yeni CTA butonu için referans alınmamalı.
  static const ctaTeal = Color(0xFF1C2455); // Dekoratif teal kalktı; Kulis.
  static const ctaTealDeep = Color(0xFF131A42); // Dekoratif teal kalktı; Perde.
  static const List<Color> ctaTealGradient = [ctaTeal, ctaTealDeep];
  static const List<Color> ctaBrandGradient = [brand, brandDeep];

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

  static ThemeData dark() => _build(SahneTokens.night, Brightness.dark);

  /// İki tema da aynı yapıcıdan, yalnız belirteçleri farklı kurulur.
  ///
  /// 2026-09-29 Şahnê: `dark()` ve `light()` 250'şer satırlık iki ayrı
  /// kopyaydı ve zamanla ayrışmıştı (ör. başlık kalınlığı birinde 700,
  /// ötekinde 800). Tek yapıcı bu ayrışmayı imkânsız kılar.
  static ThemeData _build(SahneTokens t, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const buttonSize = Size(64, 52);
    final textTheme = TextTheme(
      displayLarge: SahneType.screen.copyWith(color: t.tx),
      displayMedium: SahneType.title.copyWith(color: t.tx),
      displaySmall: SahneType.title.copyWith(color: t.tx),
      headlineLarge: SahneType.title.copyWith(color: t.tx),
      headlineMedium: SahneType.title.copyWith(color: t.tx),
      headlineSmall: SahneType.headline.copyWith(color: t.tx),
      titleLarge: SahneType.headline.copyWith(color: t.tx),
      titleMedium: SahneType.bodyStrong.copyWith(color: t.tx),
      titleSmall: SahneType.bodyStrong.copyWith(color: t.tx),
      bodyLarge: SahneType.body.copyWith(color: t.tx2),
      bodyMedium: SahneType.body.copyWith(color: t.tx2),
      bodySmall: SahneType.caption.copyWith(color: t.tx3),
      labelLarge: SahneType.button.copyWith(color: t.tx),
      labelMedium: SahneType.caption.copyWith(color: t.tx2),
      labelSmall: SahneType.caption.copyWith(color: t.tx3),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: SahneType.text,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      extensions: [t],
      textTheme: textTheme,
      iconTheme: IconThemeData(color: t.tx, size: 24),
      // Klavye odağı görünürlüğü (WCAG 2.4.7).
      focusColor: t.tx.withValues(alpha: 0.24),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: t.s1,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.act,
        onPrimary: t.onAct,
        secondary: t.learnBar,
        onSecondary: Colors.white,
        tertiary: t.gold,
        onTertiary: const Color(0xFF1B0C02),
        error: t.errTx,
        onError: isDark ? const Color(0xFF2A0806) : Colors.white,
        surface: t.s1,
        onSurface: t.tx,
        // Container tonları eksik kalırsa Flutter onları `surface`e düşürür
        // (2026-07-31 denetimi); hepsi açıkça verilir.
        surfaceContainerLowest: t.bg,
        surfaceContainerLow: t.bg,
        surfaceContainer: t.s1,
        surfaceContainerHigh: t.s2,
        surfaceContainerHighest: t.s3,
        onSurfaceVariant: t.tx2,
        outline: t.s3,
        outlineVariant: t.s2,
        primaryContainer: t.s2,
        onPrimaryContainer: t.actTx,
        secondaryContainer: t.learnTint,
        onSecondaryContainer: t.learnTx,
        tertiaryContainer: t.goldTint,
        onTertiaryContainer: t.goldTx,
        errorContainer: t.errTint,
        onErrorContainer: t.errTx,
        // Yükseklik tonlaması yüzeyi renklendirmez: tint = yüzeyin kendisi.
        surfaceTint: t.s1,
        inverseSurface: isDark ? SahneTokens.day.s1 : SahneTokens.night.s1,
        onInverseSurface: isDark ? SahneTokens.day.tx : SahneTokens.night.tx,
        inversePrimary: t.act,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: t.tx,
        centerTitle: false,
        titleTextStyle: SahneType.headline.copyWith(color: t.tx),
        iconTheme: IconThemeData(color: t.tx),
        // AppBar kendi `systemOverlayStyle`ını kökteki AnnotatedRegion'ın
        // üstüne yazar; saydam zeminden türetilen varsayılan yanlış
        // parlaklığı seçiyordu (2026-07-25). Temayla birlikte sabitlenir.
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.dark,
                statusBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarBrightness: Brightness.light,
                statusBarIconBrightness: Brightness.dark,
              ),
      ),
      // Alt gezinme: seçili sekme her yerde TEK görünümdedir (Ray plaketi +
      // birincil metin). Maketin ilk hâlinde her sekme kendi rol rengini
      // alıyordu; dört ayrı seçili görünüm karşılaştırmada kusur sayıldı.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.nav,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.s3,
        indicatorShape: SahneShape.m,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? t.tx : t.tx3,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => SahneType.caption.copyWith(
            color: s.contains(WidgetState.selected) ? t.tx : t.tx3,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      // Birincil düğme: Agir dolgu, koyu metin, 52 boy, M pah. Ekranda tek.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.act,
          foregroundColor: t.onAct,
          // Pasif: opaklık değil Perde + üçüncül metin (saveLayer açmaz).
          disabledBackgroundColor: t.s1,
          disabledForegroundColor: t.tx3,
          minimumSize: buttonSize,
          textStyle: SahneType.button,
          shape: SahneShape.m,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      // İkincil düğme: Kulis tonu, kenarsız.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: t.s2,
          foregroundColor: t.tx,
          disabledBackgroundColor: t.s1,
          disabledForegroundColor: t.tx3,
          side: BorderSide(color: t.edge),
          minimumSize: buttonSize,
          textStyle: SahneType.button,
          shape: SahneShape.m,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.s2,
          foregroundColor: t.tx,
          elevation: 0,
          minimumSize: buttonSize,
          textStyle: SahneType.button,
          shape: SahneShape.m,
        ),
      ),
      // Metin düğmesi: Agir metni, 44 dokunma alanı.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.actTx,
          minimumSize: const Size(44, 44),
          textStyle: SahneType.button,
          shape: SahneShape.m,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.tx,
          minimumSize: const Size(44, 44),
          shape: SahneShape.m,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.s2,
        selectedColor: t.s3,
        disabledColor: t.s1,
        labelStyle: SahneType.caption.copyWith(color: t.tx),
        secondaryLabelStyle: SahneType.caption.copyWith(color: t.tx),
        side: BorderSide(color: t.edge),
        shape: SahneShape.m,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      // Anahtar: açıkken Zimrût (öğrenme ayarları çoğunlukta); Agir değil,
      // çünkü Agir yalnız birincil eylemin dolgusudur.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : t.tx3,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.learnBar : t.s3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? t.learnBar
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: t.tx3, width: SahneRing.r2),
        shape: SahneShape.s,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.learnBar : t.tx3,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.learnBar,
        linearTrackColor: t.s3,
        circularTrackColor: t.s3,
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: t.s1,
        surfaceTintColor: t.s1,
        titleTextStyle: SahneType.headline.copyWith(color: t.tx),
        contentTextStyle: SahneType.body.copyWith(color: t.tx2),
        // 2026-09-25: kenar ve şekil tek yerde; Şahnê'de L pah.
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.s1,
        surfaceTintColor: t.s1,
        modalBackgroundColor: t.s1,
        shape: const BeveledRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SahneShape.lValue),
          ),
        ),
        dragHandleColor: t.s3,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.s2,
        surfaceTintColor: t.s2,
        textStyle: SahneType.body.copyWith(color: t.tx),
        shape: SahneShape.m,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(color: t.s3, shape: SahneShape.s),
        textStyle: SahneType.caption.copyWith(color: t.tx),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.tx2,
        textColor: t.tx,
        titleTextStyle: SahneType.bodyStrong.copyWith(color: t.tx),
        subtitleTextStyle: SahneType.caption.copyWith(color: t.tx2),
        minVerticalPadding: 8,
      ),
      // Kaydırıcı: pasif ray kartla aynı renkte olmasın (2026-07-31).
      sliderTheme: SliderThemeData(
        activeTrackColor: t.learnBar,
        inactiveTrackColor: t.s3,
        thumbColor: t.learnBar,
        overlayColor: t.learnBar.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.s1,
        dialBackgroundColor: t.s2,
        dialHandColor: t.learnBar,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.s3 : t.s2,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.tx : t.tx2,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.s3 : Colors.transparent,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.tx : t.tx2,
        ),
        dayPeriodBorderSide: BorderSide(color: t.s3),
        shape: SahneShape.l,
      ),
      // Bölünmüş düğme: seçili segment Ray + birincil metin.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.s3 : t.s1,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.tx : t.tx2,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.tx : t.tx2,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: t.s3)),
          shape: const WidgetStatePropertyAll(SahneShape.m),
          textStyle: const WidgetStatePropertyAll(SahneType.caption),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.tx,
        unselectedLabelColor: t.tx3,
        labelStyle: SahneType.bodyStrong,
        unselectedLabelStyle: SahneType.body,
        indicatorColor: t.learnBar,
        dividerColor: t.line,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.s2,
        hintStyle: SahneType.body.copyWith(color: t.tx3),
        labelStyle: SahneType.body.copyWith(color: t.tx2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          borderSide: BorderSide(color: t.edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          borderSide: BorderSide(color: t.edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          borderSide: BorderSide(color: t.tx, width: SahneRing.r2),
        ),
        // Doğrulama hatası krem/koyu yüzeyde okunmuyordu (2026-07-25).
        errorStyle: SahneType.caption.copyWith(
          color: t.errTx,
          fontWeight: FontWeight.w600,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          borderSide: BorderSide(color: t.errTx, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SahneShape.mValue),
          borderSide: BorderSide(color: t.errTx, width: SahneRing.r2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? t.s3 : SahneTokens.night.s1,
        contentTextStyle: SahneType.body.copyWith(
          color: isDark ? t.tx : SahneTokens.night.tx,
        ),
        actionTextColor: SahneTokens.night.actTx,
        shape: SahneShape.m,
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

  static ThemeData light() => _build(SahneTokens.day, Brightness.light);

  /// Gradient for shimmer effect.
  // Removed static const shimmerGradient – replaced by shimmerGradient(context, animValue) method below.

  // ============ Additional Gradient Definitions ============

  /// Profile screen badge section background gradient.
  static const badgeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SahneStageColors.top, SahneStageColors.bottom],
  );

  /// Streak indicator gradient.
  static const streakGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5C24C), Color(0xFFE0A82E)],
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
