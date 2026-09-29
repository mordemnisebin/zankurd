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
    // (öğren = Zimrût, yarış = Boyax), ekranın tek birincil eylemi
    // "Sonraki / Başla".
    //
    // 2026-09-29 doğallık: sayfa göstergesi elmas değil çubuk. Elmas
    // uygulamada yalnız iki şey söyler — soru ilerlemesi ve ders sayacı
    // (GORSEL_KARARLAR K5); sayfa göstergesinde üçüncü bir anlam
    // yükleniyordu.
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
                                child: _PageBar(
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
        // 2026-09-29 doğallık: üç eğik kategori çizimi yerine bankadan
        // gerçek bir soru — bkz. [OnboardingSampleQuestion].
        question: OnboardingSampleQuestion.learn,
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
        // 2026-09-29 doğallık: VS amblemi (iki elmas avatar) yerine yarış
        // sorusu: üstte soru ilerlemesi — elmasın iki anlamından biri.
        question: OnboardingSampleQuestion.race,
        showProgress: true,
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
            AppLogo(width: logoWidth),
          ],
        ),
      ),
    );
  }
}

/// Sayfa göstergesinin çubuğu: etkin sayfa kendi rolünün metin renginde
/// uzun (24), ötekiler Ray tonunda kısa (12); ikisi de 4 boyunda. Durum
/// yalnız renkle değil uzunlukla da ayrışır. Hareketi azaltta geçiş anında.
class _PageBar extends StatelessWidget {
  const _PageBar({
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
    return AnimatedContainer(
      duration: reduce ? Duration.zero : SahneMotion.answerReveal,
      curve: Curves.easeInOut,
      width: active ? 24 : 12,
      height: 4,
      color: active ? t.roleText(role) : t.s3,
    );
  }
}

/// Tanıtım kartındaki soru maketinin verisi.
///
/// Uydurma soru değildir: soru bankasında gerçekten bulunan bir sorunun
/// ([id]) metni ve şıkları, arayüz diline göre. İki soru da "kelimenin
/// Türkçesi" sorusudur; şıklar iki dilde aynıdır. Bekçi:
/// `test/onboarding_hero_art_test.dart` metnin ve şıkların bankadakiyle
/// aynı kaldığını denetler — banka değişirse maket sessizce yalana dönmez.
@visibleForTesting
class OnboardingSampleQuestion {
  const OnboardingSampleQuestion({
    required this.id,
    required this.promptKu,
    required this.promptTr,
    required this.answers,
  });

  /// `assets/data/editorial_questions.json` — kolay bir Ziman sorusu.
  static const learn = OnboardingSampleQuestion(
    id: 'edit_ziman_0021',
    promptKu: 'Peyva "dar" bi Tirkî çi ye?',
    promptTr: '"dar" Türkçede ne demektir?',
    answers: ['taş', 'yol', 'kapı', 'ağaç'],
  );

  /// `assets/data/expansion_2026_08_questions.json` — yarış slaytının
  /// sorusu (yine kolay bir Ziman sorusu).
  static const race = OnboardingSampleQuestion(
    id: 'ziman_x_0026',
    promptKu: 'Rengê "reş" bi tirkî çi ye?',
    promptTr: '"Reş" rengi Türkçede nedir?',
    answers: ['Beyaz', 'Siyah', 'Yeşil', 'Sarı'],
  );

  final String id;
  final String promptKu;
  final String promptTr;
  final List<String> answers;
}

class _OnboardingData {
  const _OnboardingData({
    required this.role,
    required this.question,
    required this.title,
    required this.body,
    this.showProgress = false,
    this.bullets = const [],
  });

  /// Slaytın Şahnê rolü: sahne kartının zemini, kilim şeridi, madde
  /// noktaları ve sayfa göstergesi bu rolün rengini taşır.
  final SahneRole role;

  /// Kahraman kartındaki soru maketi. Sayfa numarasına göre değil
  /// sayfanın verisinde durur: sıra değişirse maket yanlış sayfaya kaymaz.
  final OnboardingSampleQuestion question;

  /// Yarış slaytı: sorunun üstünde soru ilerlemesi elmasları.
  final bool showProgress;
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

    // 2026-09-25 iPhone SE denetimi: kısa ekranda ve XXXL yazıda kahraman
    // yerini metne verir. Kahraman ürünün bir örneğidir; başlık, gövde ve
    // maddeler içeriktir. Yüksekliği < 300pt sınırı içinde kalır
    // (`onboarding_hierarchy_test.dart`).
    //
    // 2026-09-29 doğallık: kahraman artık sabit bir pay DOLDURMAZ, soru
    // kartının kendi boyundadır; pay yalnız tavandır. Eskiden kart payı
    // doldurup ortasına küçük bir çizim kolajı koyuyordu — kartın boşluğu
    // içerikten değil orandan geliyordu.
    final heroShare = accessibilityText
        ? 0.0
        : ((textRoom || compact) ? 0.44 : 0.52);

    final gap = accessibilityText
        ? 0.0
        : (compact ? SahneSpace.x4 : SahneSpace.x6);
    // Tavan elle bölünür ve tam piksele yuvarlanır: kesirli sınır metin
    // bandının tepesini (kaydırma kabı) yarım piksele düşürüyordu.
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroMax = ((constraints.maxHeight - gap) * heroShare)
            .floorToDouble()
            .clamp(0.0, 296.0);
        // Dört şık alt alta ~260pt ister; daha dar tavanda şıklar ikişerli
        // iki sıraya dizilir, kalan fark ölçeklenerek kapanır. Yarış
        // slaytında şıklar her zaman ikişerli: üstteki ilerleme sırasına
        // yer açar ve iki slayt bir bakışta ayrışır.
        final grid = data.showProgress || heroMax < 260;
        final mockWidth = (constraints.maxWidth - SahneSpace.x4 * 2).clamp(
          0.0,
          420.0,
        );
        // Kahraman ile metin bir grup olarak dikeyde ortalanır; aralarında
        // yalnız [gap] kalır. Eskiden metin bandı kalan yüksekliği
        // dolduruyor ve içeriğini kendi ortasına koyuyordu: kahraman
        // içeriğin boyuna inince aradaki boşluk büyüyordu.
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heroMax > 0)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: heroMax,
                    maxWidth: mockWidth + SahneSpace.x4 * 2,
                  ),
                  child: SahneStageCard(
                    key: const ValueKey('onboarding-hero-panel'),
                    role: data.role,
                    // Kilim şeridi açık kalan üç yerden biri (K4).
                    kilim: true,
                    padding: EdgeInsets.fromLTRB(
                      SahneSpace.x4,
                      compact ? SahneSpace.x4 : SahneSpace.x5,
                      SahneSpace.x4,
                      compact ? SahneSpace.x3 : SahneSpace.x4,
                    ),
                    // `Center` değil: gevşek kısıtta boyu tavana kadar
                    // doldururdu. `FittedBox` içeriğin boyunu alır, tavanı
                    // aşarsa küçültür.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      // Maket: dokunulmaz, ekran okuyucuya duyurulmaz.
                      // Başlık ve gövde aynı şeyi metinle söyler.
                      child: ExcludeSemantics(
                        child: SizedBox(
                          width: mockWidth,
                          child: _QuestionMock(
                            question: data.question,
                            grid: grid,
                            // Kısa ekranda ilerleme sırası düşer: soru ve
                            // şıklar okunur boyda kalsın.
                            progress: data.showProgress && heroMax >= 190,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(height: gap),
            Flexible(
              // Kısa içerik kendi boyundadır (grup ortalanır); uzun içerikte
              // (büyük yazı, uzun çeviri) bant kalan yüksekliğe sınırlanır ve
              // aşağıdan kayar. `auth_onboarding_test` bunu SE + %200 yazıda
              // sözleşme olarak kilitler.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        data.title,
                        style: (compact ? SahneType.headline : SahneType.title)
                            .copyWith(color: t.tx),
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x2),
                    Text(
                      data.body,
                      style: SahneType.body.copyWith(color: t.tx2),
                    ),
                    if (data.bullets.isNotEmpty) ...[
                      SizedBox(height: compact ? SahneSpace.x3 : SahneSpace.x4),
                      for (final bullet in data.bullets) ...[
                        _BulletRow(text: bullet, role: data.role),
                        const SizedBox(height: SahneSpace.x2),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Onboarding sayfasındaki madde satırı: rol metni renginde 6'lık düz nokta
/// + Gövde metni. (2026-09-29 doğallık: elmas değil — K5.)
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
          // Nokta, 24'lük satırın ortasına oturur.
          padding: const EdgeInsets.only(top: 9),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: t.roleText(role),
              shape: const CircleBorder(),
            ),
            child: const SizedBox.square(dimension: 6),
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

/// Kahraman kartının içeriği: bankadaki gerçek bir sorunun statik maketi —
/// soru metni ve dört şık, soru ekranının şık diliyle.
///
/// 2026-09-29 doğallık: eskiden burada üç kategori çizimi eğik bir yelpaze
/// hâlinde duruyordu (2026-09-27 kararı). Denetimde en çok "üretilmiş"
/// görünen yer orasıydı: çizim kolajı neyin oynanacağını söylemiyordu,
/// yalnız süstü. Maket ilk ekrandan uygulamanın asıl işini gösterir: kısa
/// bir soru ve dört şık (GORSEL_KARARLAR K1).
///
/// [grid]: şıklar ikişerli iki sıraya dizilir (yarış slaytı, dar tavan).
class _QuestionMock extends StatelessWidget {
  const _QuestionMock({
    required this.question,
    required this.grid,
    required this.progress,
  });

  final OnboardingSampleQuestion question;
  final bool grid;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    // Sahne kartının içi gece belirteçleridir.
    final t = SahneTokens.of(context);
    final ku = context.isKu;
    final answers = question.answers;
    Widget option(int i) => _MockOption(letter: 'ABCD'[i], text: answers[i]);
    const rowGap = SahneSpace.x2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress) ...[
          // Yarışın soru ilerlemesi: ikisi cevaplandı, üçüncüsü sürüyor.
          const Center(
            child: SahneDiamondRow(
              states: [
                SahneDiamondState.correct,
                SahneDiamondState.wrong,
                SahneDiamondState.pending,
                SahneDiamondState.pending,
                SahneDiamondState.pending,
              ],
              currentIndex: 2,
              semanticLabel: '',
            ),
          ),
          const SizedBox(height: SahneSpace.x3),
        ],
        Text(
          ku ? question.promptKu : question.promptTr,
          // İkişerli dizilişte kart dar tavandadır: soru bir basamak
          // küçük yazılır ki ölçeklenip okunmaz hâle gelmesin.
          style: (grid ? SahneType.bodyStrong : SahneType.headline).copyWith(
            color: t.tx,
          ),
        ),
        const SizedBox(height: SahneSpace.x3),
        if (grid)
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: rowGap),
            Row(
              children: [
                Expanded(child: option(row * 2)),
                const SizedBox(width: rowGap),
                Expanded(child: option(row * 2 + 1)),
              ],
            ),
          ]
        else
          for (var i = 0; i < answers.length; i++) ...[
            if (i > 0) const SizedBox(height: rowGap),
            option(i),
          ],
      ],
    );
  }
}

/// Maketin tek şıkkı: soru ekranındaki şık çubuğunun sakin hâli (Kulis
/// zemin, M pah, renksiz harf karosu) — cevaptan önce hiçbir şıkta renk
/// yoktur. Dokunulmaz; yalnız görünüştür.
class _MockOption extends StatelessWidget {
  const _MockOption({required this.letter, required this.text});

  final String letter;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x2,
          vertical: 6,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(color: t.s3, shape: SahneShape.s),
              child: SizedBox.square(
                dimension: 28,
                child: Center(
                  child: Text(
                    letter,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SahneType.bodyStrong.copyWith(color: t.tx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
