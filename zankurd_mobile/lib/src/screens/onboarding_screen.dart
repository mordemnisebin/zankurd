import 'package:flutter/material.dart';

import '../config/category_visibility.dart';
import '../config/category_visuals.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/kilim_reveal.dart';
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

  @override
  Widget build(BuildContext context) {
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
                  final compact = constraints.maxHeight < 560;
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
                  final headerHeight = compact
                      ? kHeaderCompact
                      : (constraints.maxHeight < 720
                            ? kHeaderMedium
                            : kHeaderFull);
                  final buttonMaxWidth = wide ? 520.0 : double.infinity;

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
                          height: headerHeight,
                          child: Stack(
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
                                    // Dev beyaz logo kartı yalnız 1. slaytta;
                                    // diğer slaytlarda küçük wordmark yeterli.
                                    child: _page == 0
                                        ? _AnimatedBrandLockup(
                                            scale: _brandScale,
                                            opacity: _brandOpacity,
                                            logoWidth: compact ? 48 : 96,
                                            showTagline: !wideCompact,
                                          )
                                        : Text(
                                            'ZanKurd',
                                            style: AppTypography.heading2
                                                .copyWith(
                                                  color:
                                                      AppTheme.textPrimaryColor(
                                                        context,
                                                      ),
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.3,
                                                ),
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
                                  child: const _OnboardingLanguageToggle(),
                                ),
                              ),
                              Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: compact ? 0 : 2,
                                  ),
                                  child: TextButton(
                                    onPressed: widget.onComplete,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.textMutedColor(
                                        context,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      context.t(K.skip),
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textMutedColor(context),
                                      ),
                                    ),
                                  ),
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
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeInOut,
                                  width: i == _page ? 28 : 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xxs,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: i == _page
                                        ? AppTheme.accentGradient
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
                                              color: AppTheme
                                                  .primaryGradientStart
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
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: GeometricGradientButton(
                              onPressed: last
                                  ? widget.onComplete
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
                                  // "Piştre" Kurmancî'de "sonra / daha
                                  // sonra" demek; ileri götüren düğmede
                                  // yanlış, üstelik sağ üstteki "Derbas
                                  // bike" (atla) ile anlamca çakışıyordu
                                  // (2026-07-25 canlı denetimi).
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
    ];
  }
}

/// Tanıtım turunun KU/TR seçici hapı. Giriş ekranındaki denetimle aynı
/// davranışı taşır; kullanıcı dili daha ilk ekranda değiştirebilir.
class _OnboardingLanguageToggle extends StatelessWidget {
  const _OnboardingLanguageToggle();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.t(K.changeLanguage),
      excludeSemantics: true,
      child: Tooltip(
        message: context.t(K.language),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: const ValueKey('onboarding-language-toggle'),
            onTap: context.langProvider.toggle,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceHiColor(context),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Text(
                context.t(K.languageCode),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimaryColor(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
  });

  final _OnboardingData data;
  final bool compact;
  final bool wideCompact;

  @override
  Widget build(BuildContext context) {
    final heroIconSize = compact ? 72.0 : 100.0;
    final heroGlyphSize = compact ? 36.0 : 52.0;
    final titleSize = compact ? 22.0 : 26.0;
    final bodySize = compact ? 13.0 : 15.0;

    return Column(
      children: [
        Expanded(
          // Görsel kimlik güçlü kalsın; metin ve madde listesi ilk bakışta
          // daha fazla alan bulsun. (Hero yüksekliği bilinçli olarak
          // sınırlıdır — bkz. onboarding_hierarchy_test.)
          flex: compact ? 36 : 38,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              key: const ValueKey('onboarding-hero-panel'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    data.color,
                    Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.16),
                      data.color,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
                boxShadow: AppTheme.elevatedShadow(data.color),
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
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Expanded(
          flex: compact ? 64 : 62,
          // Metin bloğu kendi bandının tepesine yapışıyordu: madde
          // listesinden sonra sayfa noktalarına kadar ~350 pt boş kalıyor,
          // uygulamayı ilk açan kişi yarım yüklenmiş bir ekran görüyordu.
          // Kısa içerik artık bandın ortasında durur; uzun içerikte
          // (büyük yazı, uzun çeviri) kaydırma davranışı korunur.
          // Hero'nun payı değişmedi — yüksekliği `onboarding_hierarchy_test`
          // tarafından bilerek sınırlanmıştır (2026-07-27).
          child: LayoutBuilder(
            builder: (context, textBandConstraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: textBandConstraints.maxHeight,
                ),
                child: Column(
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
        // renkli panel zemininde net ayrışır.
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
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
