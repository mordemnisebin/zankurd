import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/styled_button.dart';

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
                  final headerHeight = compact
                      ? 90.0
                      : (constraints.maxHeight < 720 ? 140.0 : 180.0);
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
                                      context.s('Derbas bike', 'Atla'),
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
                                            color: AppTheme.primaryGradientStart
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
                              icon: last
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              label: last
                                  ? context.s('Dest pê bike', 'Başla')
                                  : context.s('Piştre', 'Sonraki'),
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
    final ku = context.isKu;
    return [
      _OnboardingData(
        icon: Icons.school_rounded,
        color: AppTheme.brandGreen,
        title: context.s('Hîn bibe', 'Öğren'),
        body: context.s(
          'Kurmancî peyv, çand û zanînê bi pirsên kurt fêr bibe.',
          'Kurmancî kelimeleri, kültürü ve bilgiyi kısa sorularla öğren.',
        ),
        bullets: [
          ku
              ? '8 kategorî — Ziman, Dîrok, Çand û zêdetir'
              : '8 kategori — Dil, Tarih, Kültür ve daha fazlası',
          ku
              ? 'Her roj pirsên nû û balkêş'
              : 'Her gün yeni ve ilgi çekici sorular',
          ku ? 'Bi kurtî û bi bandor fêr bibe' : 'Kısa ve etkili öğrenme',
        ],
      ),
      _OnboardingData(
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFFB86A3E), // terracotta — palet tonu
        title: context.s('Pêşbirkê bike', 'Yarış'),
        body: context.s(
          'Bi hevalan an botan re pêşbirkê bike û pûanên xwe zêde bike.',
          'Arkadaşlarınla veya botlarla yarış, puanını yükselt.',
        ),
        bullets: [
          ku
              ? 'Şerê 1vs1 — rasterast bi hevalên xwe re'
              : '1vs1 düello — arkadaşlarınla doğrudan',
          ku
              ? 'Pêşbirka Rojê — 10 pirs, xelata rojê'
              : 'Günün Yarışması — 10 soru, günlük ödül',
          ku ? 'Turnuva — ji bo kûpayê pêşbikeve' : 'Turnuva — kupa için yarış',
        ],
      ),
      // 3. slayt: günlük ödüller + "Neden ZanKurd?" değer önerisi birleşti
      // (4 slayt → 3 slayt; daha kısa ilk izlenim).
      _OnboardingData(
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.gold,
        title: context.s('Çima ZanKurd?', 'Neden ZanKurd?'),
        body: context.s(
          'Kurmancî çand û zimanê bi pêşbirkê fêr bibe; her roj vegere, xelat bistîne.',
          'Kurmancî kültürünü yarışarak öğren; her gün dön, ödül kazan.',
        ),
        bullets: [
          ku
              ? 'Çerxa Rojê — 100 coinê belaş'
              : 'Günlük Çark — 100 ücretsiz coin',
          ku
              ? 'Zincîra xwe biparêze û bonus bistîne'
              : 'Seriyi koru, bonus kazan',
          ku
              ? 'Jokerên stratejîk: 50/50, Demjimêr zêde'
              : 'Stratejik jokerler: 50/50, Süre uzat',
          ku
              ? 'Turnuvayên rojane — bibe şampiyon'
              : 'Günlük turnuvalar — şampiyon ol',
        ],
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
                context.s('Hîn bibe, pêş bike', 'Öğren, yarış, ilerle'),
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
          // daha fazla alan bulsun.
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
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: KilimPatternPainter(
                          drawPattern: true,
                          color: Colors.white,
                          opacity: 0.05,
                        ),
                      ),
                    ),
                  ),
                  // Ölü dikey alanı dolduran, içerikle ilişkili arka plan
                  // ikonları (dekoratif; erişilebilirlik dışı).
                  Positioned(
                    top: 18,
                    left: 22,
                    child: Icon(
                      data.icon,
                      size: 34,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 24,
                    child: Icon(
                      data.icon,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
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
          child: SingleChildScrollView(
            child: Column(
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
