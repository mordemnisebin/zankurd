import 'package:flutter/material.dart';

import '../config/category_visibility.dart';
import '../config/category_visuals.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/kilim_reveal.dart';
import '../widgets/language_toggle.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/styled_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _controller = PageController();
  int _page = 0;
  bool _ageConfirmed = false;
  // "Başla"ya kutu işaretsizken basılınca eskiden bir SnackBar çıkıyordu:
  // ne yapılacağını söylemiyordu VE ekranın altındaki "Başla" düğmesini
  // örtüyordu (2026-09-27 canlı gezinti). Artık kutunun yanında satır içi
  // gösterilir; yalnız bir başarısız denemeden sonra görünür, kutu
  // işaretlenince hemen kaybolur.
  bool _showAgeGateHint = false;
  late final AnimationController _brandController;
  late final Animation<double> _brandScale;
  late final Animation<double> _brandOpacity;

  @override
  void initState() {
    super.initState();
    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _brandScale = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeOutBack,
    );
    _brandOpacity = CurvedAnimation(
      parent: _brandController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _completeIfAgeOk() {
    if (!_ageConfirmed) {
      setState(() => _showAgeGateHint = true);
      return;
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (ReducedMotionProvider.isReducedIn(context)) {
      _brandController.value = 1;
    }
    final pages = _pages(context);
    final last = _page == pages.length - 1;
    final isDark = !AppTheme.isLight(context);

    final glowColor1 = isDark
        ? AppTheme.gold.withValues(alpha: 0.08)
        : AppTheme.gold.withValues(alpha: 0.05);
    final glowColor2 = isDark
        ? AppTheme.secondaryAccent.withValues(alpha: 0.12)
        : AppTheme.borderOf(context).withValues(alpha: 0.06);

    return Scaffold(
      body: Container(
        key: const ValueKey('onboarding-surface'),
        decoration: BoxDecoration(color: AppTheme.bgOf(context)),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor1, glowColor1.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -140,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor2, glowColor2.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final textScale = MediaQuery.textScalerOf(context).scale(1);
                  final accessibilityText = textScale >= 2.0;
                  final compact =
                      constraints.maxHeight < 560 || accessibilityText;
                  final wide = constraints.maxWidth >= 720;
                  final wideCompact = compact && wide;
                  final horizontalPadding = wide
                      ? AppSpacing.xl
                      : AppSpacing.page;
                  final verticalPadding = compact
                      ? AppSpacing.xxs
                      : AppSpacing.xs;
                  // Kısa ekranda (< 560px) küçük başlık, orta (< 720px) ve
                  // geniş ekranda tam başlık alanı. Bu değerler her yükseklik
                  // bandına göre dengelendi; token sistemi piksel değerini
                  // sabitleyerek gelecekte tek noktada güncellenebilir kılar.
                  const double kHeaderCompact = 90.0; // < 560px: mini logo
                  const double kHeaderMedium = 140.0; // 560–719px: normal
                  const double kHeaderFull = 180.0; // ≥ 720px: geniş
                  final headerHeight = accessibilityText
                      ? 112.0
                      : (compact
                            ? kHeaderCompact
                            : (constraints.maxHeight < 720
                                  ? kHeaderMedium
                                  : kHeaderFull));
                  final buttonMaxWidth = wide ? 520.0 : double.infinity;
                  final skipButton = TextButton(
                    onPressed: () => _completeIfAgeOk(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textMutedColor(context),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: Text(
                      context.t(K.skip),
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMutedColor(context),
                      ),
                    ),
                  );

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      // CTA'ya sabit bottom-safe mesafe (SafeArea içinde).
                      16,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          key: const ValueKey('onboarding-header'),
                          height: headerHeight,
                          child: accessibilityText
                              ? Column(
                                  children: [
                                    Row(
                                      key: const ValueKey(
                                        'onboarding-accessibility-top-controls',
                                      ),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const LanguageToggle(
                                          kuKey: ValueKey(
                                            'onboarding-language-ku',
                                          ),
                                          trKey: ValueKey(
                                            'onboarding-language-tr',
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.topRight,
                                            child: skipButton,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Center(
                                        key: const ValueKey(
                                          'onboarding-accessibility-brand',
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          // 2026-09-27: 1. sayfada logo,
                                          // 2.'de düz "ZanKurd" yazısı vardı —
                                          // aynı sabit yükseklikli kutuda çok
                                          // daha küçük içerik durunca üstte
                                          // büyük boşluk kalıyor ve başlık
                                          // sayfa geçişinde zıplıyormuş gibi
                                          // görünüyordu (canlı gezinti). Logo
                                          // artık her sayfada aynı; kontrolör
                                          // 900ms'de bir kez koşar, geç
                                          // sayfalarda zaten bitmiş (deger 1)
                                          // durur, yeniden animasyon oynamaz.
                                          child: _AnimatedBrandLockup(
                                            scale: _brandScale,
                                            opacity: _brandOpacity,
                                            logoWidth: 44,
                                            showTagline: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  children: [
                                    Align(
                                      alignment: wideCompact
                                          ? Alignment.centerLeft
                                          : Alignment.topCenter,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: compact ? 0 : 8,
                                          left: wideCompact ? 4 : 0,
                                        ),
                                        // Kısa pencerelerde sabit başlık kutusunu
                                        // taşırmasın diye gerekirse küçülür.
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          // 2026-09-27: 1. sayfada beyaz logo
                                          // kartı, 2.'de düz "ZanKurd" yazısı
                                          // vardı. Sabit yükseklikli başlık
                                          // kutusunda çok daha küçük içerik
                                          // durunca üstte büyük boşluk kalıyor
                                          // ve başlık sayfa geçişinde
                                          // zıplıyormuş gibi görünüyordu
                                          // (canlı gezinti). Logo kartı artık
                                          // her sayfada aynı; giriş animasyonu
                                          // yalnız bir kez (900ms) koşar,
                                          // sonraki sayfalarda zaten bitmiş
                                          // durumda (deger 1) görünür.
                                          child: _AnimatedBrandLockup(
                                            scale: _brandScale,
                                            opacity: _brandOpacity,
                                            logoWidth: compact ? 48 : 96,
                                            showTagline: !wideCompact,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Dil seçimi ilk ekranda görünür olmalı:
                                    // uygulama doğrudan Kurmancî açılıyor ve
                                    // Türkçe okuyan kullanıcı, tanıtımı hiç
                                    // anlamadan geçmek zorunda kalıyordu; TR
                                    // seçeneği ancak giriş ekranında beliriyordu
                                    // (2026-07-25 canlı denetimi).
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: compact ? 0 : 2,
                                        ),
                                        child: const LanguageToggle(
                                          kuKey: ValueKey(
                                            'onboarding-language-ku',
                                          ),
                                          trKey: ValueKey(
                                            'onboarding-language-tr',
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: compact ? 0 : 2,
                                        ),
                                        child: skipButton,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: pages.length,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                            itemBuilder: (context, index) => _OnboardingPage(
                              data: pages[index],
                              compact: compact,
                              wideCompact: wideCompact,
                              textRoom:
                                  accessibilityText ||
                                  (!compact && constraints.maxHeight < 700),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.xs : AppSpacing.xs,
                        ),
                        if (pages.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < pages.length; i++)
                                AnimatedContainer(
                                  key: ValueKey('onboarding-page-indicator-$i'),
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeInOut,
                                  width: i == _page ? 28 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: i == _page
                                        ? AppTheme.identityHeaderGradient
                                        : null,
                                    color: i == _page
                                        ? null
                                        : AppTheme.borderColor(
                                            context,
                                          ).withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: i == _page
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.culturalBrandBg
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        SizedBox(height: compact ? 8 : 10),
                        Container(
                          // Başarısız bir "Başla" denemesinden sonra kutu
                          // satırı hata renginde kenarlıkla vurgulanır; aynı
                          // anda hemen altında ne yapılacağını söyleyen metin
                          // durur (bkz. [K.ageGateHint]).
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: _showAgeGateHint
                                ? Border.all(color: AppTheme.wrong, width: 1.4)
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              key: const ValueKey('onboarding-age-gate'),
                              value: _ageConfirmed,
                              onChanged: (value) => setState(() {
                                _ageConfirmed = value ?? false;
                                if (_ageConfirmed) _showAgeGateHint = false;
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                context.t(K.ageGateLabel),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_showAgeGateHint) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: Text(
                              context.t(K.ageGateHint),
                              key: const ValueKey('onboarding-age-gate-hint'),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.readableAccent(
                                  context,
                                  AppTheme.wrong,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 8 : 10),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: GeometricGradientButton(
                              onPressed: last
                                  ? _completeIfAgeOk
                                  : () {
                                      _controller.nextPage(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOutCubic,
                                      );
                                    },
                              icon: last ? AppIcons.check : AppIcons.arrowRight,
                              label: last
                                  ? context.t(K.start)
                                  : context.t(K.next),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_OnboardingData> _pages(BuildContext context) {
    final categoryCount = visibleCategories(
      CategoryVisuals.colorDefinedCategories,
    ).length;
    return [
      _OnboardingData(
        icon: AppIcons.graduationCap,
        // 2026-07-24: hero bloğu da CTA da turuncuydu — ekranda iki eşit
        // güçte turuncu kütle vardı ve göz nereye basacağını şaşırıyordu.
        // Hero kimlik rengine (Kesk) alındı; turuncu yalnız butonda kalır.
        color: AppTheme.culturalBrandBg,
        title: context.t(K.onbLearnTitle),
        body: context.t(K.onbLearnBody),
        bullets: [
          // Sayı sabit yazılıydı ve Sînema kategorisi eklenince yanlışa
          // düştü (2026-07-25). Görünür kategori listesinden türetilir;
          // yeni kategori eklendiğinde metin kendiliğinden doğru kalır.
          context.t(K.onbCategoriesBullet, {'count': '$categoryCount'}),
          context.t(K.onbDailyBullet),
        ],
      ),
      // İlk kez gelen kullanıcı yalnız öğrenme yüzeyini görüyordu; Yarış,
      // oda, kupa ve ödül döngüsü ancak uygulamaya girdikten sonra ortaya
      // çıkıyordu. Metinler zaten sözlükte vardı fakat turdan kopuktu.
      // İkinci kısa sayfa, yeni jargon eklemeden ürünün diğer yarısını
      // gösterir; görsel kimliği rekabet yüzeyinin madder tonuyla ayrışır.
      _OnboardingData(
        icon: AppIcons.bolt,
        color: const Color(0xFF9D203A),
        title: context.t(K.onbCompeteTitle),
        body: context.t(K.onbCompeteBody),
        bullets: [context.t(K.onbDuelBullet), context.t(K.onbRewardBullet)],
      ),
    ];
  }
}

class _AnimatedBrandLockup extends StatelessWidget {
  const _AnimatedBrandLockup({
    required this.scale,
    required this.opacity,
    this.logoWidth = 132,
    this.showTagline = true,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final double logoWidth;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: ScaleTransition(
        scale: scale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(width: logoWidth, onCard: true),
            if (showTagline) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.t(K.onbTagline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.bullets = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final List<String> bullets;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.compact,
    required this.wideCompact,
    required this.textRoom,
  });

  final _OnboardingData data;
  final bool compact;
  final bool wideCompact;

  /// Dekoratif hero panelinin küçülüp yerini metne bırakması gereken ekran
  /// sınıfı: ya sistem metin ölçeği çok büyük ya da ekran kısa. Bkz.
  /// [_OnboardingPage.build] içindeki 2026-09-25 notu.
  final bool textRoom;

  @override
  Widget build(BuildContext context) {
    final heroIconSize = compact ? 72.0 : 100.0;
    final heroGlyphSize = compact ? 36.0 : 52.0;
    final titleSize = compact ? 22.0 : 26.0;
    final bodySize = compact ? 13.0 : 15.0;

    // 2026-09-25 iPhone SE denetimi. İki ayrı kısa ekran yolu vardı ve
    // ikisinde de madde listesi metin bandının altında kesiliyordu:
    //
    // 1) Sistem metin ölçeği XXXL (ölçek 2.0). Simülatörün erişilebilirlik
    //    ayarı açıkken `compact` zaten true oluyor, ama 13pt gövde metni
    //    ikiye katlanınca içerik banda sığmıyor; ilk karede yarım madde
    //    ve sayfa noktalarının arkasına gizlenen ikinci madde görünüyor.
    // 2) Varsayılan metin ölçeğinde iPhone SE (667pt). `compact` eşiği
    //    (560) tutmuyor, tam boy başlık + büyük hero kullanılıyor ve
    //    dekoratif panel metinden ~20pt çalıyor.
    //
    // İkisinde de aynı çözüm: dekoratif hero yerini metne verir. Hero yalnız
    // görsel kimliktir; başlık, gövde ve maddeler içeriktir. 700pt üstünde
    // veya metin ölçeği normalde hiçbir şey değişmez.
    final heroFlex = textRoom ? 26 : (compact ? 36 : 38);
    final textFlex = textRoom ? 74 : (compact ? 64 : 62);

    return Column(
      children: [
        Expanded(
          // Görsel kimlik güçlü kalsın; metin ve madde listesi ilk bakışta
          // daha fazla alan bulsun. (Hero yüksekliği bilinçli olarak
          // sınırlıdır — bkz. onboarding_hierarchy_test.)
          flex: heroFlex,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              key: const ValueKey('onboarding-hero-panel'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                // Design 2: onboarding sayfaları ayrı ürünler gibi renk
                // değiştirmez. Hero yüzeyi her adımda Forest kimliğidir;
                // sayfanın kendi rengi yalnız ikon ve küçük işaretlerde
                // kalır.
                gradient: AppTheme.identityHeaderGradient,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Stack(
                children: [
                  // Kart dokusu: kilim baklavası.
                  //
                  // Önce aynı ikon kartın iki köşesinde soluk olarak
                  // tekrarlanıyordu — ortadaki büyük ikonla birlikte tek
                  // kartta aynı glif üç kez görünüyordu ve iki slayt
                  // birbirinden yalnız renkle ayrılıyordu (2026-07-25
                  // görsel denetimi). Doku, uygulamanın başka yerlerinde de
                  // kullanılan marka motifidir; slaytlara tekrar hissi
                  // vermeden derinlik katar.
                  const Positioned.fill(
                    child: KilimReveal(child: SizedBox.expand()),
                  ),
                  Center(
                    child: _OnboardingIcon(
                      data: data,
                      size: heroIconSize,
                      iconSize: heroGlyphSize,
                    ),
                  ),
                  // 2026-09-10 görsel denetimi: hero düz renk + jenerik
                  // ikondu ve ana sayfadaki Zana ile bağ kurmuyordu.
                  // Maskot kartın köşesinde karşılar; sonuç ekranındaki
                  // "köşede Zana" diliyle aynıdır.
                  Positioned(
                    right: compact ? 10 : 18,
                    bottom: compact ? 8 : 14,
                    child: IgnorePointer(
                      child: RojMascot(
                        size: compact ? 52 : 68,
                        mood: RojMood.happy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Expanded(
          flex: textFlex,
          // Metin bloğu kendi bandının tepesine yapışıyordu: madde
          // listesinden sonra sayfa noktalarına kadar ~350 pt boş kalıyor,
          // uygulamayı ilk açan kişi yarım yüklenmiş bir ekran görüyordu.
          // Kısa içerik artık bandın ortasında durur; uzun içerikte
          // (büyük yazı, uzun çeviri) kaydırma davranışı korunur.
          // Hero'nun payı değişmedi — yüksekliği `onboarding_hierarchy_test`
          // tarafından bilerek sınırlanmıştır (2026-07-27).
          //
          // 2026-09-25 iPhone SE denetimi: buradaki `mainAxisSize: min`
          // kaldırılınca `Column` kendisine gelen sık yükseklik
          // kısıtını (`ConstrainedBox` minHeight = bant yüksekliği) tam
          // boy kabul ediyor, çocukları o yükseklik içine sıkıştırıyor ve
          // taşan içerik `center` hizasıyla YUKARI itiliyordu. Flutter
          // negatif taşmayı kaydırmadığı için 1. madde sayfa noktalarının
          // altında kalıyor, 2. madde hiç görünmüyor ve kullanıcı kaydırmayı
          // denese bile eksik metin geri gelmiyordu. `min` ile Column
          // içeriğe göre küçülür: kısa metin ortalanır, taşan metin
          // aşağıdan kayar. `auth_onboarding_test` bunu SE + %200 yazıda
          // sözleşme olarak kilitler.
          child: LayoutBuilder(
            builder: (context, textBandConstraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: textBandConstraints.maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 22,
                          margin: const EdgeInsets.only(right: AppSpacing.sm),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                data.color,
                                data.color.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            data.title,
                            style: AppTypography.heading1.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontSize: titleSize,
                              letterSpacing: -0.5,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? AppSpacing.xs : AppSpacing.xs),
                    Text(
                      data.body,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontSize: bodySize,
                        height: 1.5,
                      ),
                    ),
                    if (data.bullets.isNotEmpty) ...[
                      SizedBox(
                        height: compact ? AppSpacing.cardGap : AppSpacing.md,
                      ),
                      for (final bullet in data.bullets) ...[
                        _BulletRow(text: bullet, color: data.color),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Onboarding sayfasındaki madde satırı.
class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingIcon extends StatelessWidget {
  const _OnboardingIcon({
    required this.data,
    required this.size,
    required this.iconSize,
  });

  final _OnboardingData data;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Beyaz plaka + marka renkli glif: stock-icon hissini azaltır,
        // renkli panel zemininde net ayrışır. Çevresindeki ince altın
        // halka premium vurgudur (2026-09-10).
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.65),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(data.icon, color: data.color, size: iconSize),
      ),
    );
  }
}
