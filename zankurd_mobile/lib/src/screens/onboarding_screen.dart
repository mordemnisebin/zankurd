import 'package:flutter/material.dart';

import '../config/category_visibility.dart';
import '../config/category_visuals.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/language_picker.dart';
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
    if (ReducedMotionProvider.isReducedIn(context)) {
      _brandController.value = 1;
    }
    final reduce = sahneMotionReduced(context);
    final pages = _pages(context);
    final last = _page == pages.length - 1;

    // 2026-10-01 giriş iskeleti (bkz. [SahneEntryScaffold]): giriş, kayıt ve
    // ad ekranıyla aynı yerleşim. Üstte dil seçici solda, "Atla" sağda, altında
    // ilerleme çubuğu (eskiden altta bir çubuk çifti, üstte 88–148 px'lik
    // logo/dil/atla yığını); ortada sayfa (kahraman kart + başlık + gövde +
    // maddeler); altta yaş kutusu, tek birincil "Sonraki / Başla" ve ikinci
    // sayfada ikincil "Geri". Logo artık üst yığında değil, kahraman kartın
    // içinde (giriş ve kayıt ekranlarındaki gibi).
    //
    // 2026-09-29 Şahnê: marka anı. Düz zemin (yumuşak ışık halkaları
    // kalktı); her slayt bir sahne kartı (öğren = Zimrût, yarış = Boyax).
    //
    // 2026-09-29 doğallık: sayfa göstergesi elmas değil çubuk. Elmas
    // uygulamada yalnız iki şey söyler — soru ilerlemesi ve ders sayacı
    // (GORSEL_KARARLAR K5); sayfa göstergesinde üçüncü bir anlam
    // yükleniyordu.
    // Ekran ölçüsü `MediaQuery`den değil kısıttan okunur: bölünmüş ekran,
    // katlanabilir cihaz ve testlerde `MediaQuery.size` gerçek yerleşim
    // alanını söylemeyebilir.
    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            constraints.maxHeight - MediaQuery.paddingOf(context).vertical;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final accessibilityText = textScale >= 2.0;
        final compact = height < 560 || accessibilityText;
        final wide = constraints.maxWidth >= 720;
        return SahneEntryScaffold(
          surfaceKey: const ValueKey('onboarding-surface'),
          // Dil seçici artık ilk sayfanın tepesinde, tam adlı ve büyük
          // ([LanguagePicker]); küçük KU|TR hapı yalnız ikinci sayfada gerekmiyor.
          skip: SahneButton.text(
            label: context.t(K.skip),
            arrow: false,
            onPressed: widget.onComplete,
          ),
          progress: pages.length > 1
              ? ExcludeSemantics(
                  child: SahneProgressBar(
                    key: const ValueKey('onboarding-progress'),
                    tone: SahneProgressTone.action,
                    value: (_page + 1) / pages.length,
                    trailing: '${_page + 1}/${pages.length}',
                  ),
                )
              : null,
          paged: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) => _OnboardingPage(
              data: pages[index],
              compact: compact,
              wide: wide,
              textRoom: accessibilityText || (!compact && height < 700),
              accessibilityText: accessibilityText,
              brand: _AnimatedBrandLockup(
                scale: _brandScale,
                opacity: _brandOpacity,
                logoWidth: 40,
              ),
            ),
          ),
          // 2026-10-24: yaş kutusu kalktı. Onay kutusu "Sonraki"yi pasif yapıp
          // ilk ekranda hata gösteriyordu ve kullanıcıların çoğu ilk ekrandaki
          // çizimi gerçek soru sanıp şıklara dokunuyordu. Yaş şartı artık
          // Kullanım Şartları'nda (web/terms.html) ve giriş ekranındaki kabul
          // satırında durur. "Sonraki/Başla" her zaman etkindir.
          primary: SahneButton.primary(
            expand: true,
            onPressed: last
                ? widget.onComplete
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
          // "Geri" her yerde alttaki ikincil metin eylemidir (kayıtta da öyle);
          // ilk sayfada geri yok.
          secondary: _page > 0
              ? SahneButton.text(
                  key: const ValueKey('onboarding-back'),
                  label: context.t(K.backStep),
                  arrow: false,
                  onPressed: () {
                    _controller.previousPage(
                      duration: reduce
                          ? const Duration(milliseconds: 1)
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                  },
                )
              : null,
        );
      },
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
        // 2026-10-24: sahte soru kartı kalktı (kullanıcılar şıklara
        // dokunuyordu); yerine dokunulmaz, soruya benzemeyen bir çizim.
        icons: const [AppIcons.graduationCap],
        languagePicker: true,
        title: context.t(K.onbLearnTitle),
        slogan: context.t(K.dozaSlogan),
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
        icons: const [AppIcons.swords, AppIcons.trophy],
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

class _OnboardingData {
  const _OnboardingData({
    required this.role,
    required this.icons,
    required this.title,
    required this.body,
    this.languagePicker = false,
    this.bullets = const [],
    this.slogan,
  });

  /// Slaytın Şahnê rolü: sahne kartının zemini, kilim şeridi, madde
  /// noktaları ve sayfa göstergesi bu rolün rengini taşır.
  final SahneRole role;

  /// Kahraman kartındaki çizimin simgeleri (öğren: tek, yarış: kılıçlar +
  /// kupa). Soru ya da şık içermez; dokunulmaz.
  final List<IconData> icons;

  /// Yalnız ilk sayfa: tepede büyük dil seçici.
  final bool languagePicker;
  final String title;
  final String body;
  final List<String> bullets;

  /// Başlığın altında küçük, vurgulu söz (yalnız ilk ekran: S1).
  final String? slogan;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.compact,
    required this.wide,
    required this.textRoom,
    required this.accessibilityText,
    required this.brand,
  });

  final _OnboardingData data;
  final bool compact;
  final bool wide;

  /// Kahraman kartın tepesindeki logo (giriş, kayıt ve ad ekranındaki kartlar
  /// da logo taşır). Yer yoksa çizilmez.
  final Widget brand;

  /// Dekoratif hero panelinin küçülüp yerini metne bırakması gereken ekran
  /// sınıfı: ya sistem metin ölçeği çok büyük ya da ekran kısa. Bkz.
  /// [_OnboardingPage.build] içindeki 2026-09-25 notu.
  final bool textRoom;

  /// Sistem yazı ölçeği ≥ 2: dekoratif sahne kartı tamamen çekilir. %200
  /// yazıda (iPhone SE) gövde ve maddeler bandı doldurur; kartın küçük bir
  /// dilimi bile madde listesini kaydırma alanının dışına iterdi. İçerik
  /// (başlık, gövde, maddeler) kaybolmaz; yalnız süs.
  final bool accessibilityText;

  /// Kahraman kartın boy tavanı; logo kartın içindeyken ikincisi.
  static const double _heroCap = 296;
  static const double _brandHeroCap = 340;
  static const double _pickerReserve = 96;

  @override
  Widget build(BuildContext context) {
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
      builder: (context, outer) {
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? SahneSpace.x8 : SahneSpace.page,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: SahneEntryScaffold.columnWidth,
              ),
              child: _buildPage(context, outer.maxHeight, gap, heroShare),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    double maxHeight,
    double gap,
    double heroShare,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dil seçici (etiket + 56'lık segment) kahramanın payından düşer.
        final pickerReserve = data.languagePicker ? _pickerReserve : 0.0;
        final room = (maxHeight - gap - pickerReserve) * heroShare;
        // Logo kartın içindeyse (yer varsa) tavan logonun yüksekliği kadar
        // artar: eskiden logo kartın DIŞINDA, 88–148 px'lik üst yığındaydı;
        // net dikey kullanım aynı kalır.
        final showBrand = !accessibilityText && room >= 240;
        // 120'den kısa tavanda soru maketi okunmaz bir şeride ezilir (kısa
        // yatay telefon): kahraman çekilir, metin tüm yeri alır. İçerik
        // (başlık, gövde, maddeler) kaybolmaz; yalnız süs.
        final heroMax = room < 120
            ? 0.0
            : room.floorToDouble().clamp(
                0.0,
                showBrand ? _brandHeroCap : _heroCap,
              );
        final mockWidth = (constraints.maxWidth - SahneSpace.x4 * 2).clamp(
          0.0,
          420.0,
        );
        // Kahraman ile metin sayfanın TEPESİNDEN başlar (giriş, kayıt ve ad
        // ekranlarıyla aynı hiza); aralarında yalnız [gap] kalır.
        //
        // Tur 10a: içerik kısaysa artan boşluk (yaş onayının üstünde ~100 pt)
        // tek yerde (altta) birikmesin diye `spaceEvenly` ile dört eşit paya
        // bölünür: üst 1, kart-metin 2 (araya konan sıfır boyutlu çocuk), alt 1.
        // İçerik sığmıyorsa boşluk 0'dır ve düzen aynıdır.
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.languagePicker)
              const Padding(
                padding: EdgeInsets.only(bottom: SahneSpace.x3),
                child: LanguagePicker(
                  kuKey: ValueKey('onboarding-language-ku'),
                  trKey: ValueKey('onboarding-language-tr'),
                ),
              ),
            if (heroMax > 0)
              Center(
                child: ConstrainedBox(
                  // Kart HER ZAMAN tam genişlikte: içerik sığmak için
                  // küçülürse kenarlarda boşluk kartın içinde kalır, kart
                  // daralıp sayfanın kenarından kopmaz.
                  constraints: BoxConstraints(
                    minWidth: mockWidth + SahneSpace.x4 * 2,
                    maxHeight: heroMax,
                    maxWidth: mockWidth + SahneSpace.x4 * 2,
                  ),
                  child: SahneEntryHero(
                    key: const ValueKey('onboarding-hero-panel'),
                    role: data.role,
                    padding: EdgeInsets.fromLTRB(
                      SahneSpace.x4,
                      compact ? SahneSpace.x4 : SahneSpace.x5,
                      SahneSpace.x4,
                      compact ? SahneSpace.x3 : SahneSpace.x4,
                    ),
                    // `Center` değil: gevşek kısıtta boyu tavana kadar
                    // doldururdu. `FittedBox` içeriğin boyunu alır, tavanı
                    // aşarsa küçültür.
                    child: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        // Maket: dokunulmaz, ekran okuyucuya duyurulmaz.
                        // Başlık ve gövde aynı şeyi metinle söyler.
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: mockWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showBrand) ...[
                                  Center(child: brand),
                                  const SizedBox(height: SahneSpace.x3),
                                ],
                                _SceneArt(icons: data.icons),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (heroMax > 0) const SizedBox.shrink(),
            Flexible(
              // Kısa içerik kendi boyundadır; uzun içerikte (büyük yazı, uzun
              // çeviri) bant kalan yüksekliğe sınırlanır ve aşağıdan kayar.
              // `auth_onboarding_test` bunu SE + %200 yazıda sözleşme olarak
              // kilitler.
              child: Padding(
                padding: EdgeInsets.only(top: heroMax > 0 ? gap : 0),
                child: _OnboardingTextBand(data: data, compact: compact),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sayfanın metin bandı: başlık, gövde ve maddeler. İçerik kalan yüksekliğe
/// sığmazsa aşağı kayar.
///
/// 2026-09-30 simülatör: Ekstra Büyük yazıda (2.35x, iPhone 17e) ikinci
/// maddenin son satırı bandın alt kenarında yarıda kesik kalıyordu ve band
/// kayabildiği hâlde hiçbir şey kaydığını söylemiyordu; kullanıcı kesik
/// metni "kaydırılamıyor" diye okudu. Taşan bandın yanında artık her zaman
/// görünen ince bir kaydırma çubuğu durur (taşma yoksa çizilmez); metin
/// yine kesilmez, kaydırılınca tamamı görünür. Bekçi:
/// `test/sim_son_2026_09_30_test.dart`.
class _OnboardingTextBand extends StatefulWidget {
  const _OnboardingTextBand({required this.data, required this.compact});

  final _OnboardingData data;
  final bool compact;

  @override
  State<_OnboardingTextBand> createState() => _OnboardingTextBandState();
}

class _OnboardingTextBandState extends State<_OnboardingTextBand> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final data = widget.data;
    final compact = widget.compact;
    return RawScrollbar(
      key: const ValueKey('onboarding-text-scrollbar'),
      controller: _scroll,
      thumbVisibility: true,
      thickness: 4,
      minThumbLength: 32,
      thumbColor: t.tx3,
      child: SingleChildScrollView(
        controller: _scroll,
        // Çubuk metnin üstüne binmesin.
        padding: const EdgeInsetsDirectional.only(end: SahneSpace.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SahneEntryHeading(
              title: data.title,
              body: data.body,
              compact: compact,
            ),
            if (data.slogan != null) ...[
              const SizedBox(height: SahneSpace.x2),
              Text(
                data.slogan!,
                key: const ValueKey('onboarding-slogan'),
                style: SahneType.bodyStrong.copyWith(
                  color: t.roleText(data.role),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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

/// Kahraman kartının içeriği: soru DEĞİL, dokunulmaz bir sahne çizimi.
///
/// 2026-10-24: eskiden burada bankadan gerçek bir soru ve dört şık duruyordu;
/// ilk açılışta kullanıcılar onu gerçek soru sanıp şıklara dokunuyordu
/// (canlı gözlem). Şimdi yalnız rolün simgeleri: öğrenmede başlık kep,
/// yarışta kılıçlar ve kupa. Şık, harf karosu ya da soru cümlesi yoktur;
/// bekçi `test/onboarding_hero_art_test.dart`.
class _SceneArt extends StatelessWidget {
  const _SceneArt({required this.icons});

  final List<IconData> icons;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      key: const ValueKey('onboarding-scene-art'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: SahneSpace.x4),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
              ),
            ),
            child: SizedBox.square(
              dimension: 88,
              child: Icon(icons[i], size: 44, color: t.tx),
            ),
          ),
        ],
      ],
    );
  }
}
