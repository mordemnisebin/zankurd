import 'package:flutter/material.dart';

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
    // 2026-10-28 kurul K10 (sadelik): her adım = TEK görsel + TEK başlık +
    // en çok iki kısa satır + alttaki "Devam". Eskiden dikey `spaceEvenly`
    // üstte ve altta ~100 pt'lik boşluk bırakıyor, kahraman karta konan
    // koyu kutu da içeriğe yer bırakmıyordu; kutu kalktı, görsel+metin
    // grubu dikeyde ortalanır (boşluk iki yana eşit pay edilir, ortada
    // delik kalmaz). Dil seçimi kendi adımıdır ve iki büyük karttır.
    //
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
              brand: _AnimatedBrandLockup(
                scale: _brandScale,
                opacity: _brandOpacity,
                logoWidth: compact ? 72 : 96,
              ),
            ),
          ),
          // 2026-10-24: yaş kutusu kalktı (bkz. giriş ekranındaki kabul
          // satırı). Birincil düğme her zaman etkindir.
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
            label: last ? context.t(K.start) : context.t(K.onbContinue),
          ),
          // "Geri" her yerde alttaki ikincil metin eylemidir; ilk adımda yok.
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
    return [
      // 1. adım: dil. Marka işareti + marka sözü + iki büyük dil kartı.
      _OnboardingData(
        role: SahneRole.neutral,
        icons: const [],
        languagePicker: true,
        title: context.t(K.languagePickerLabel),
        // Marka sözü ilk ekranda durur (S1); kartların üstünde.
        lines: [context.t(K.dozaSlogan)],
        sloganLast: true,
      ),
      // 2. adım: öğren. Başlık kep, iki kısa satır.
      _OnboardingData(
        // Zimrût rolü; turuncu yalnız alttaki tek birincil düğmede kalır.
        role: SahneRole.learn,
        // Dokunulmaz, soruya benzemeyen çizim (2026-10-24: kullanıcılar
        // sahte soru kartındaki şıklara dokunuyordu).
        icons: const [AppIcons.graduationCap],
        title: context.t(K.onbLearnTitle),
        lines: [context.t(K.onbLearnBody), context.t(K.onbDailyBullet)],
      ),
      // 3. adım: yarış (Boyax rolü).
      _OnboardingData(
        role: SahneRole.race,
        icons: const [AppIcons.swords, AppIcons.trophy],
        title: context.t(K.onbCompeteTitle),
        lines: [context.t(K.onbCompeteBody), context.t(K.onbDuelBullet)],
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
    required this.lines,
    this.languagePicker = false,
    this.sloganLast = false,
  });

  /// Adımın Şahnê rolü: görselin tonu bu rolün rengindedir.
  final SahneRole role;

  /// Görseldeki simgeler (öğren: tek, yarış: kılıçlar + kupa). Soru ya da
  /// şık içermez; dokunulmaz. Boşsa marka işareti çizilir.
  final List<IconData> icons;

  /// Yalnız ilk adım: iki büyük dil kartı.
  final bool languagePicker;
  final String title;

  /// En çok İKİ kısa satır (bekçi: `onboarding_sadelik_test.dart`).
  final List<String> lines;

  /// Son satır marka sözüdür: italik, rol renginde (S1).
  final bool sloganLast;
}

class _OnboardingPage extends StatefulWidget {
  const _OnboardingPage({
    required this.data,
    required this.compact,
    required this.wide,
    required this.brand,
  });

  final _OnboardingData data;
  final bool compact;
  final bool wide;

  /// Dil adımının görseli (marka işareti).
  final Widget brand;

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

/// Taşan sayfanın yanında her zaman görünen ince kaydırma çubuğu durur
/// (taşma yoksa çizilmez): 2026-09-30 simülatörde Ekstra Büyük yazıda metin
/// kesik görünüp "kaydırılamıyor" sanılmıştı. Bekçi:
/// `test/sim_son_2026_09_30_test.dart`.
class _OnboardingPageState extends State<_OnboardingPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final compact = widget.compact;
    final wide = widget.wide;
    final brand = widget.brand;
    final t = SahneTokens.of(context);
    return LayoutBuilder(
      builder: (context, outer) {
        // Görsel + başlık + satırlar TEK grup olarak dikeyde ortalanır;
        // sığmazsa grup kayar (büyük yazı, kısa ekran) ve hiçbir şey
        // kesilmez.
        return RawScrollbar(
          key: const ValueKey('onboarding-text-scrollbar'),
          controller: _scroll,
          thumbVisibility: true,
          thickness: 4,
          minThumbLength: 32,
          thumbColor: t.tx3,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.symmetric(
              horizontal: wide ? SahneSpace.x8 : SahneSpace.page,
              vertical: SahneSpace.x4,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: outer.maxHeight - SahneSpace.x4 * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: SahneEntryScaffold.columnWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: data.icons.isEmpty
                            ? brand
                            : _SceneArt(
                                icons: data.icons,
                                role: data.role,
                                size: compact ? 72 : 104,
                              ),
                      ),
                      SizedBox(height: compact ? SahneSpace.x4 : SahneSpace.x6),
                      Semantics(
                        header: true,
                        child: Text(
                          data.title,
                          textAlign: TextAlign.center,
                          style:
                              (compact ? SahneType.headline : SahneType.title)
                                  .copyWith(color: t.tx),
                        ),
                      ),
                      for (var i = 0; i < data.lines.length; i++) ...[
                        const SizedBox(height: SahneSpace.x2),
                        if (data.sloganLast && i == data.lines.length - 1)
                          Text(
                            data.lines[i],
                            key: const ValueKey('onboarding-slogan'),
                            textAlign: TextAlign.center,
                            style: SahneType.bodyStrong.copyWith(
                              color: t.roleText(data.role),
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Text(
                            data.lines[i],
                            textAlign: TextAlign.center,
                            style: SahneType.body.copyWith(color: t.tx2),
                          ),
                      ],
                      if (data.languagePicker) ...[
                        SizedBox(
                          height: compact ? SahneSpace.x4 : SahneSpace.x6,
                        ),
                        const LanguagePicker(
                          kuKey: ValueKey('onboarding-language-ku'),
                          trKey: ValueKey('onboarding-language-tr'),
                          showLabel: false,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Adımın görseli: soru DEĞİL, dokunulmaz, KUTUSUZ bir çizim — rolün ton
/// zeminli yuvarlak rozeti içinde büyük simge(ler).
///
/// 2026-10-24: eskiden burada bankadan gerçek bir soru duruyordu; kullanıcılar
/// şıklara dokunuyordu. 2026-10-28 K10: koyu kutulu sahne kartı da kalktı;
/// rozet düz zeminde durur. Şık, harf karosu ya da soru cümlesi yoktur;
/// bekçi `test/onboarding_hero_art_test.dart`.
class _SceneArt extends StatelessWidget {
  const _SceneArt({
    required this.icons,
    required this.role,
    required this.size,
  });

  final List<IconData> icons;
  final SahneRole role;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: Row(
        key: const ValueKey('onboarding-scene-art'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < icons.length; i++) ...[
            if (i > 0) SizedBox(width: size * 0.2),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: t.roleTint(role),
                shape: CircleBorder(
                  side: BorderSide(color: t.roleText(role), width: 2),
                ),
              ),
              child: SizedBox.square(
                dimension: size,
                child: Icon(
                  icons[i],
                  size: size * 0.5,
                  color: t.roleText(role),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
