import 'package:flutter/material.dart';

import '../config/category_visibility.dart';
import '../config/category_visuals.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/language_toggle.dart';
import '../widgets/sahne/sahne.dart';
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
    final t = SahneTokens.of(context);
    final reduce = sahneMotionReduced(context);
    final pages = _pages(context);
    final last = _page == pages.length - 1;

    // 2026-09-29 Şahnê: marka anı. Düz zemin (yumuşak ışık halkaları
    // kalktı); üstte logo işareti plakası, her slayt bir sahne kartı
    // (öğren = Zimrût, yarış = Boyax), sayfa göstergesi elmaslar, ekranın
    // tek birincil eylemi "Sonraki / Başla".
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        key: const ValueKey('onboarding-surface'),
        decoration: BoxDecoration(color: t.bg),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final accessibilityText = textScale >= 2.0;
              final compact = constraints.maxHeight < 560 || accessibilityText;
              final wide = constraints.maxWidth >= 720;
              final wideCompact = compact && wide;
              final horizontalPadding = wide ? SahneSpace.x8 : SahneSpace.page;
              final verticalPadding = compact ? SahneSpace.x1 : SahneSpace.x2;
              // Kısa ekranda (< 560px) küçük başlık, orta (< 720px) ve
              // geniş ekranda tam başlık alanı. Başlık alanı sayfalar arası
              // sabittir: logo her sayfada aynı, üst kısım zıplamaz.
              const double kHeaderCompact = 88.0; // < 560px: mini logo
              const double kHeaderMedium = 128.0; // 560–719px: normal
              const double kHeaderFull = 148.0; // ≥ 720px: geniş
              final headerHeight = accessibilityText
                  ? 112.0
                  : (compact
                        ? kHeaderCompact
                        : (constraints.maxHeight < 720
                              ? kHeaderMedium
                              : kHeaderFull));
              final buttonMaxWidth = wide ? 520.0 : double.infinity;
              final skipButton = SahneButton.text(
                label: context.t(K.skip),
                arrow: false,
                onPressed: _completeIfAgeOk,
              );

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  // CTA'ya sabit bottom-safe mesafe (SafeArea içinde).
                  SahneSpace.x4,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const LanguageToggle(
                                      kuKey: ValueKey('onboarding-language-ku'),
                                      trKey: ValueKey('onboarding-language-tr'),
                                    ),
                                    const SizedBox(width: SahneSpace.x2),
                                    Expanded(
                                      child: Align(
                                        alignment: AlignmentDirectional.topEnd,
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
                                      // Logo her sayfada aynı; kontrolör
                                      // 900ms'de bir kez koşar, geç
                                      // sayfalarda zaten bitmiş durur
                                      // (2026-09-27).
                                      child: _AnimatedBrandLockup(
                                        scale: _brandScale,
                                        opacity: _brandOpacity,
                                        logoWidth: 40,
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
                                      ? AlignmentDirectional.centerStart
                                      : Alignment.topCenter,
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      top: compact ? 0 : SahneSpace.x1,
                                      start: wideCompact ? SahneSpace.x1 : 0,
                                    ),
                                    // Kısa pencerelerde sabit başlık
                                    // kutusunu taşırmasın diye gerekirse
                                    // küçülür.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: _AnimatedBrandLockup(
                                        scale: _brandScale,
                                        opacity: _brandOpacity,
                                        logoWidth: compact ? 40 : 64,
                                      ),
                                    ),
                                  ),
                                ),
                                // Dil seçimi ilk ekranda görünür olmalı:
                                // uygulama doğrudan Kurmancî açılıyor ve
                                // Türkçe okuyan kullanıcı, tanıtımı hiç
                                // anlamadan geçmek zorunda kalıyordu
                                // (2026-07-25 canlı denetimi).
                                const Align(
                                  alignment: AlignmentDirectional.topStart,
                                  child: LanguageToggle(
                                    kuKey: ValueKey('onboarding-language-ku'),
                                    trKey: ValueKey('onboarding-language-tr'),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.topEnd,
                                  child: skipButton,
                                ),
                              ],
                            ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: pages.length,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (context, index) => _OnboardingPage(
                          data: pages[index],
                          compact: compact,
                          wideCompact: wideCompact,
                          textRoom:
                              accessibilityText ||
                              (!compact && constraints.maxHeight < 700),
                          accessibilityText: accessibilityText,
                        ),
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    if (pages.length > 1)
                      ExcludeSemantics(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < pages.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SahneSpace.x1,
                                ),
                                child: _PageDiamond(
                                  key: ValueKey('onboarding-page-indicator-$i'),
                                  active: i == _page,
                                  role: pages[i].role,
                                  reduce: reduce,
                                ),
                              ),
                          ],
                        ),
                      ),
                    SizedBox(height: compact ? SahneSpace.x2 : SahneSpace.x3),
                    // Başarısız bir "Başla" denemesinden sonra kutu satırı
                    // Şaş halkasıyla vurgulanır; hemen altında ne
                    // yapılacağını söyleyen metin durur (bkz.
                    // [K.ageGateHint]).
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: SahneShape.withSide(
                          SahneShape.m,
                          _showAgeGateHint ? t.errTx : Colors.transparent,
                          width: SahneRing.r2,
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: CheckboxListTile(
                          key: const ValueKey('onboarding-age-gate'),
                          value: _ageConfirmed,
                          onChanged: (value) => setState(() {
                            _ageConfirmed = value ?? false;
                            if (_ageConfirmed) _showAgeGateHint = false;
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: SahneSpace.x1,
                          ),
                          shape: SahneShape.m,
                          title: Text(
                            context.t(K.ageGateLabel),
                            style: SahneType.body.copyWith(color: t.tx),
                          ),
                        ),
                      ),
                    ),
                    if (_showAgeGateHint) ...[
                      const SizedBox(height: SahneSpace.x1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SahneSpace.x2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                AppIcons.triangleExclamation,
                                size: 16,
                                color: t.errTx,
                              ),
                            ),
                            const SizedBox(width: SahneSpace.x2),
                            Expanded(
                              child: Text(
                                context.t(K.ageGateHint),
                                key: const ValueKey('onboarding-age-gate-hint'),
                                style: SahneType.captionStrong.copyWith(
                                  color: t.errTx,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: compact ? SahneSpace.x2 : SahneSpace.x3),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: buttonMaxWidth),
                      child: SahneButton.primary(
                        expand: true,
                        onPressed: last
                            ? _completeIfAgeOk
                            : () {
                                _controller.nextPage(
                                  duration: reduce
                                      ? const Duration(milliseconds: 1)
                                      : const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                        label: last ? context.t(K.start) : context.t(K.next),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
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
        // 2026-09-29 Şahnê: öğrenme slaytı Zimrût rolünü taşır; turuncu
        // yalnız alttaki tek birincil düğmede kalır.
        role: SahneRole.learn,
        // 2026-09-27: jenerik mezuniyet şapkası ikonu kategori yelpazesiyle
        // değiştirildi — bkz. _CategoryFan.
        art: _HeroArt.categoryFan,
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
      // çıkıyordu. İkinci kısa sayfa ürünün diğer yarısını gösterir; görsel
      // kimliği yarışın Boyax sahnesiyle ayrışır.
      _OnboardingData(
        role: SahneRole.race,
        art: _HeroArt.duel,
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
    this.logoWidth = 64,
  });

  final Animation<double> scale;
  final Animation<double> opacity;
  final double logoWidth;

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
            // Logo işareti plakada (gecede Kulis, gündüzde Perde + kenar):
            // dağlar koyu zeminde kaybolmaz.
            AppLogo(width: logoWidth, onBrandSurface: true),
          ],
        ),
      ),
    );
  }
}

/// Sayfa göstergesinin elması: etkin sayfa kendi rolünün metin renginde
/// dolu ve büyük (12), ötekiler Ray tonunda küçük (8). Hareketi azaltta
/// geçiş anında.
class _PageDiamond extends StatelessWidget {
  const _PageDiamond({
    required this.active,
    required this.role,
    required this.reduce,
    super.key,
  });

  final bool active;
  final SahneRole role;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final size = active ? 12.0 : 8.0;
    return SizedBox.square(
      dimension: 12,
      child: Center(
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : SahneMotion.answerReveal,
          curve: Curves.easeInOut,
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: active ? t.roleText(role) : t.s3,
            shape: SahneShape.diamond(size),
          ),
        ),
      ),
    );
  }
}

/// Hero panelinin içeriği — SAYFA NUMARASINA göre değil, sayfanın anlamına
/// göre seçilir. Sıraya bağlı bir `if (index == 0)` yerine `_OnboardingData`
/// üstünde alan olması, sayfa sırası ileride değişirse görsel kararın
/// sessizce yanlış sayfaya kaymamasını sağlar (2026-09-27).
enum _HeroArt {
  /// Sayfa 1: üç kategori görselinin yelpazesi (bkz. [_CategoryFan]).
  categoryFan,

  /// Sayfa 2: düello — VS amblemi (iki elmas avatar), Boyax sahnesinde.
  duel,
}

class _OnboardingData {
  const _OnboardingData({
    required this.role,
    required this.art,
    required this.title,
    required this.body,
    this.bullets = const [],
  });

  /// Slaytın Şahnê rolü: sahne kartının zemini, kilim şeridi, madde
  /// elmasları ve sayfa göstergesi bu rolün rengini taşır.
  final SahneRole role;
  final _HeroArt art;
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
    required this.accessibilityText,
  });

  final _OnboardingData data;
  final bool compact;
  final bool wideCompact;

  /// Dekoratif hero panelinin küçülüp yerini metne bırakması gereken ekran
  /// sınıfı: ya sistem metin ölçeği çok büyük ya da ekran kısa. Bkz.
  /// [_OnboardingPage.build] içindeki 2026-09-25 notu.
  final bool textRoom;

  /// Sistem yazı ölçeği ≥ 2: dekoratif sahne kartı tamamen çekilir. %200
  /// yazıda (iPhone SE) gövde ve maddeler bandı doldurur; kartın küçük bir
  /// dilimi bile madde listesini kaydırma alanının dışına iterdi. İçerik
  /// (başlık, gövde, maddeler) kaybolmaz; yalnız süs.
  final bool accessibilityText;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fanTile = compact ? 80.0 : 112.0;

    // 2026-09-25 iPhone SE denetimi: kısa ekranda ve XXXL yazıda dekoratif
    // hero yerini metne verir. Hero yalnız görsel kimliktir; başlık, gövde
    // ve maddeler içeriktir. Hero'nun yüksekliği < 300pt sınırı içinde
    // kalır (`onboarding_hierarchy_test.dart`).
    // Hero payı (%): metin bandı kalanı alır.
    final heroShare = accessibilityText
        ? 0.0
        : (textRoom ? 0.26 : (compact ? 0.36 : 0.44));

    final gap = accessibilityText
        ? 0.0
        : (compact ? SahneSpace.x4 : SahneSpace.x6);
    // Hero ve metin bandı payları elle bölünür ve tam piksele yuvarlanır:
    // `Expanded(flex)` kesirli sınırlar üretiyordu ve metin bandının
    // tepesi (kaydırma kabı) yarım piksele düşüyordu.
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = ((constraints.maxHeight - gap) * heroShare)
            .floorToDouble()
            // Uzun ekranda (tablet portre) kart içeriğinden çok büyüyüp
            // metni aşağı itmesin.
            .clamp(0.0, 280.0);
        return Column(
          children: [
            if (heroHeight > 0)
              SizedBox(
                height: heroHeight,
                child: SahneStageCard(
                  key: const ValueKey('onboarding-hero-panel'),
                  role: data.role,
                  padding: EdgeInsets.fromLTRB(
                    SahneSpace.x4,
                    compact ? SahneSpace.x3 : SahneSpace.x5,
                    SahneSpace.x4,
                    compact ? SahneSpace.x2 : SahneSpace.x4,
                  ),
                  child: SizedBox.expand(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: switch (data.art) {
                          // 2026-09-27: tek jenerik ikon neyin öğrenileceğini
                          // söylemiyordu; üç gerçek kategori çizimi aynı hissi
                          // ilk ekrandan kurar. Dekoratiftir: kart zaten başlık
                          // ve gövdeyle aynı bilgiyi verir.
                          _HeroArt.categoryFan => ExcludeSemantics(
                            child: _CategoryFan(size: fanTile),
                          ),
                          _HeroArt.duel => const SizedBox(
                            width: 208,
                            height: 160,
                            child: FittedBox(child: SahneVsEmblem()),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: gap),
            Expanded(
              // Kısa içerik bandın ortasında durur; uzun içerikte (büyük yazı,
              // uzun çeviri) aşağıdan kayar. 2026-09-25 iPhone SE denetimi:
              // `Column(mainAxisSize: min)` içeriğe göre küçülür — kısa metin
              // ortalanır, taşan metin aşağıdan kayar. `auth_onboarding_test`
              // bunu SE + %200 yazıda sözleşme olarak kilitler.
              child: LayoutBuilder(
                builder: (context, textBandConstraints) =>
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: textBandConstraints.maxHeight,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                data.title,
                                style:
                                    (compact
                                            ? SahneType.headline
                                            : SahneType.title)
                                        .copyWith(color: t.tx),
                              ),
                            ),
                            const SizedBox(height: SahneSpace.x2),
                            Text(
                              data.body,
                              style: SahneType.body.copyWith(color: t.tx2),
                            ),
                            if (data.bullets.isNotEmpty) ...[
                              SizedBox(
                                height: compact ? SahneSpace.x3 : SahneSpace.x4,
                              ),
                              for (final bullet in data.bullets) ...[
                                _BulletRow(text: bullet, role: data.role),
                                const SizedBox(height: SahneSpace.x2),
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
      },
    );
  }
}

/// Onboarding sayfasındaki madde satırı: rol metni renginde 8'lik elmas +
/// Gövde metni.
class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text, required this.role});

  final String text;
  final SahneRole role;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Elmas, 24'lük satırın ortasına oturur.
          padding: const EdgeInsets.only(top: SahneSpace.x2),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: t.roleText(role),
              shape: SahneShape.diamond(8),
            ),
            child: const SizedBox.square(dimension: 8),
          ),
        ),
        const SizedBox(width: SahneSpace.x3),
        Expanded(
          child: Text(text, style: SahneType.body.copyWith(color: t.tx)),
        ),
      ],
    );
  }
}

/// Sayfa 1 hero'sunun görsel çekirdeği: tek jenerik ikon yerine üç gerçek
/// kategori çiziminin yelpazesi (Ziman ortada üstte, Çand solda, Muzîk
/// sağda). Kartlar alt kategori ekranlarındaki AYNI görselleri kullanır
/// (`CategoryVisuals.imagePath`) — "burada ne öğreneceğim" sorusu ilk
/// ekrandan gerçek içerikle yanıtlanır (2026-09-27).
///
/// 2026-09-29 Şahnê: her kart mücevher karonun dilinde — L pah, nötr kaş
/// (Halka 1), gölgesiz; beyaz çerçeve ve bulanık gölge kalktı. Üç ayrı
/// çizim: aynı ekranda aynı çizim iki kez görünmez.
class _CategoryFan extends StatelessWidget {
  const _CategoryFan({required this.size});

  /// Tek bir kartın kenar uzunluğu.
  final double size;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: size * 2.2,
      height: size * 1.25,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Yan kartlar ÖNCE çizilir; Ziman son çizildiği için üstte durur.
          _fanCard(context, 'Çand', -1, devicePixelRatio),
          _fanCard(context, 'Muzîk', 1, devicePixelRatio),
          _fanCard(context, 'Ziman', 0, devicePixelRatio),
        ],
      ),
    );
  }

  /// [dir]: yön işareti — orta kart için 0 (kaymaz, dönmez), sol için -1,
  /// sağ için +1.
  Widget _fanCard(
    BuildContext context,
    String category,
    int dir,
    double devicePixelRatio,
  ) {
    final t = SahneTokens.of(context);
    final dx = dir * size * 0.62;
    final dy = 6.0 * dir.abs();
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: dir * 0.17,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: const ShapeBorderClipper(shape: SahneShape.l),
                child: ColoredBox(
                  color: SahneStageColors.art2,
                  child: Image.asset(
                    CategoryVisuals.imagePath(category),
                    fit: BoxFit.cover,
                    // Kart dekoratif yelpazenin bir parçası; üç görsel ekran
                    // okuyucuya ayrı ayrı duyurulmamalı.
                    excludeFromSemantics: true,
                    cacheWidth: (size * devicePixelRatio).round(),
                    // Görsel çözülemezse çizimsiz kategori karosunun ikonu
                    // kobalt zeminde durur (mücevher karonun dili).
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        CategoryVisuals.icon(category),
                        color: SahneTokens.night.tx,
                        size: size * 0.45,
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: ShapeDecoration(
                  shape: SahneShape.withSide(SahneShape.l, t.rim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
