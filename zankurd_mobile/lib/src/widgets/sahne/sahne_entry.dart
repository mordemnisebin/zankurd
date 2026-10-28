import 'package:flutter/material.dart';

import '../../theme/sahne.dart';
import 'sahne_cards.dart';
import 'sahne_foundation.dart';
import 'sahne_painters.dart';

/// D · Giriş akışı iskeleti (karşılama, giriş, kayıt, ad sorma).
///
/// Dört ekran aynı sırayla aynı yerlerde konuşur:
///
/// 1. **Üst çubuk** (en az 56): solda [leading] (dil seçici), sağda [skip]
///    (metin düğmesi — atlama HER ZAMAN sağ üsttedir; "geri" ise HER ZAMAN
///    alttaki ikincil metin düğmesidir). Altında, adımlı akışlarda,
///    [progress] (`SahneProgressBar`, yerleşimi burada, biçimi ortak).
/// 2. **Kahraman yuvası** ([hero]): kilim şeritli sahne kartı
///    ([SahneEntryHero]). Marka sayfalarında logo, karşılamada ürünün
///    soru maketi.
/// 3. **Başlık ve gövde** ([title], [body]): Manşet 28 + Gövde ikincil,
///    hepsi sola yaslı ([SahneEntryHeading]).
/// 4. **İçerik** ([content]): form kartı ya da madde listesi.
/// 5. **Alt perde**: ekranın tek birincil eylemi [primary], altında ikincil
///    metin eylemi [secondary]; ikisinin üstünde isteğe bağlı bir satır
///    ([aboveAction], ör. yaş kutusu). Ekranın dibine sabittir ve her
///    ekranda aynı yerde durur.
///
/// ## Alt perde ne zaman sabit KALMAZ
///
/// Klavye açıkken, ekran kısaysa (< 560), yatayda ya da büyük yazıda
/// (≥ 1,5×) perde içeriğin SONUNA, kaydırılan sütuna iner. Sabit perde bu
/// koşullarda alanı bitiriyordu: iPhone SE'de klavye açıkken 568 − 300 −
/// 56 − 140 < 0 → alan kalmıyordu. Birincil eylem yine hemen formun
/// altındadır, yalnız ekranla birlikte kayar.
///
/// ## Genişlik
///
/// 440'a kadar tek sütun. 720'den geniş ya da kısa yatay telefonda
/// (≥ 640 × < 420) iki sütun: solda kahraman + başlık, sağda içerik +
/// perde.
///
/// [paged] verilirse kahraman/başlık/içerik yerine o gövde kullanılır
/// (karşılamanın `PageView`i); perde o durumda hep sabittir.
class SahneEntryScaffold extends StatelessWidget {
  const SahneEntryScaffold({
    super.key,
    this.leading,
    this.skip,
    this.progress,
    this.hero,
    this.title,
    this.body,
    this.content,
    this.paged,
    this.aboveAction,
    required this.primary,
    this.secondary,
    this.primaryFirstWhenFlowing = false,
    this.centerWhenAnchored = false,
    this.surfaceKey,
    this.dockKey = const ValueKey('entry-dock'),
  }) : assert(
         paged != null || title != null,
         'Sayfa ya paged gövde ya da başlık taşımalı',
       );

  /// Üst çubuğun solu (dil seçici).
  final Widget? leading;

  /// Üst çubuğun sağı: atla / şimdilik geç.
  final Widget? skip;

  /// Üst çubuğun altındaki adım göstergesi.
  final Widget? progress;

  /// Kahraman yuvası ([SahneEntryHero]).
  final Widget? hero;
  final String? title;
  final String? body;

  /// Başlığın altındaki içerik (form kartı ya da liste).
  final Widget? content;

  /// Sayfalı gövde (karşılama).
  final Widget? paged;

  /// Birincil eylemin hemen üstündeki satır (ör. yaş kutusu).
  final Widget? aboveAction;

  /// Ekranın tek birincil eylemi.
  final Widget primary;

  /// İkincil metin eylemi (geri, "hesabın var mı?").
  final Widget? secondary;

  /// Perde sabitlenemeyip (kısa/yatay/klavye/büyük yazı) içeriğin ALTINA
  /// aktığında birincil eylem içerikten ÖNCE gelir. Giriş ekranında birincil
  /// eylem "Hemen oyna"dır; formun altında kalırsa yatay telefonda ilk
  /// ekranın dışına düşüyordu.
  final bool primaryFirstWhenFlowing;

  /// Perde sabitken kahraman üst çubuğun altında kalır, başlık + içerik kalan
  /// alanda DİKEY ORTALANIR. İçerik kısa olduğunda (giriş ekranının ilk
  /// görünümü: kahraman, başlık, "Hesabım var") altta büyük bir boşluk kalıp
  /// düğmeyi perdeden koparıyordu (2026-10-28). Uzun içerik yine kayar.
  final bool centerWhenAnchored;

  /// Sayfa zemininin anahtarı (testler zemini bulur).
  final Key? surfaceKey;

  /// Alt perdenin anahtarı.
  final Key dockKey;

  /// Tek sütunun en geniş hâli.
  static const double columnWidth = 440;

  /// Üst çubuğun en az boyu.
  static const double barHeight = 56;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Klavye: `Scaffold` gövdeyi küçültür ve gövdenin `MediaQuery`sinden
    // alt `viewInsets`i siler; bu yüzden klavye `Scaffold`un DIŞINDAKİ
    // bağlamdan okunur.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bigText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return Scaffold(
      backgroundColor: t.bg,
      body: Container(
        key: surfaceKey,
        decoration: BoxDecoration(color: t.bg),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide =
                  c.maxWidth > 720 || (c.maxWidth >= 640 && c.maxHeight < 420);
              final short = c.maxHeight < 560;
              final anchored =
                  paged != null ||
                  (!keyboardOpen && !wide && !short && !bigText);
              final width = wide ? 960.0 : columnWidth;
              Widget limited(Widget child) => Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width),
                  child: child,
                ),
              );

              final dockContent = _DockContent(
                aboveAction: aboveAction,
                primary: primary,
                secondary: secondary,
              );

              Widget scrollBody() {
                final head = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?hero,
                    if (hero != null) const SizedBox(height: SahneSpace.x4),
                    SahneEntryHeading(title: title!, body: body),
                  ],
                );
                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!anchored && primaryFirstWhenFlowing) ...[
                      dockContent,
                      const SizedBox(height: SahneSpace.x4),
                    ],
                    ?content,
                    if (!anchored && !primaryFirstWhenFlowing) ...[
                      const SizedBox(height: SahneSpace.x4),
                      dockContent,
                    ],
                  ],
                );
                final heading = SahneEntryHeading(title: title!, body: body);
                // Kısa ilk görünüm: kahraman üst çubuğun altında SABİT kalır
                // (sözleşme: dört ekranda aynı yer), başlık + içerik kalan
                // alanda dikey ortalanır (`centerWhenAnchored`).
                final centered = anchored && centerWhenAnchored && !wide;
                final Widget laidOut = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: head),
                          const SizedBox(width: SahneSpace.x8),
                          Expanded(flex: 6, child: main),
                        ],
                      )
                    : centered
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ?hero,
                          if (hero != null)
                            const SizedBox(height: SahneSpace.x4),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  heading,
                                  if (content != null)
                                    const SizedBox(height: SahneSpace.x5),
                                  main,
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          head,
                          if (content != null || !anchored)
                            const SizedBox(height: SahneSpace.x5),
                          main,
                        ],
                      );
                const padTop = SahneSpace.x2;
                final padBottom = anchored ? SahneSpace.x8 : SahneSpace.x6;
                return LayoutBuilder(
                  builder: (context, view) => SingleChildScrollView(
                    // Sabit perde varken alt pay büyür: kartın son satırı
                    // perdenin altında kalıp kesik görünmesin (kurul
                    // 2026-10-20).
                    padding: EdgeInsets.fromLTRB(
                      SahneSpace.page,
                      padTop,
                      SahneSpace.page,
                      padBottom,
                    ),
                    child: centered
                        ? ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (view.maxHeight - padTop - padBottom)
                                  .clamp(0.0, double.infinity),
                            ),
                            child: IntrinsicHeight(child: limited(laidOut)),
                          )
                        : limited(laidOut),
                  ),
                );
              }

              return Column(
                children: [
                  limited(
                    _TopBar(leading: leading, skip: skip, progress: progress),
                  ),
                  Expanded(
                    child: paged != null
                        ? paged!
                        : Stack(
                            children: [
                              Positioned.fill(child: scrollBody()),
                              if (anchored)
                                // Perdenin hemen üstünde zemin rengine
                                // sönen şerit: kart kesik değil, kayıyor.
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: SahneSpace.x6,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            t.bg.withValues(alpha: 0),
                                            t.bg,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (anchored)
                    DecoratedBox(
                      key: dockKey,
                      decoration: BoxDecoration(
                        color: t.bg,
                        border: Border(top: BorderSide(color: t.line)),
                      ),
                      child: limited(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            SahneSpace.page,
                            SahneSpace.x3,
                            SahneSpace.page,
                            SahneSpace.x2,
                          ),
                          child: dockContent,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Üst çubuk: [leading] solda, [skip] sağda; altında [progress].
class _TopBar extends StatelessWidget {
  const _TopBar({this.leading, this.skip, this.progress});

  final Widget? leading;
  final Widget? skip;
  final Widget? progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // W15 (2026-10-28 tur 5): dil seçici üstteki çevrimdışı şeride
          // yapışıyordu (ios_04/and_04); standart 8 üst boşluk.
          const SizedBox(height: SahneSpace.x2),
          ConstrainedBox(
            // a11y-tap-target: noninteractive — üst çubuğun yerleşim boyu;
            // içindeki düğmeler kendi 48'lik hedeflerini taşır.
            constraints: const BoxConstraints(
              minHeight: SahneEntryScaffold.barHeight,
            ),
            child: Row(
              children: [
                ?leading,
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: skip,
                  ),
                ),
              ],
            ),
          ),
          if (progress != null) ...[
            progress!,
            const SizedBox(height: SahneSpace.x2),
          ],
        ],
      ),
    );
  }
}

class _DockContent extends StatelessWidget {
  const _DockContent({required this.primary, this.secondary, this.aboveAction});

  final Widget primary;
  final Widget? secondary;
  final Widget? aboveAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aboveAction != null) ...[
          aboveAction!,
          const SizedBox(height: SahneSpace.x2),
        ],
        primary,
        const SizedBox(height: SahneSpace.x1),
        // İkincil eylem yoksa da yeri ayrılır: birincil düğme dört ekranda
        // (ve karşılamanın iki sayfasında) ekranın AYNI yerinde durur.
        // Yer ayrılmadığında "Geri" olan sayfayla olmayan sayfa arasında
        // düğme 48 px zıplıyordu.
        ConstrainedBox(
          // a11y-tap-target: noninteractive — yer tutucu; içindeki metin
          // düğmesi kendi 48'lik hedefini taşır. Sabit boy DEĞİL: büyük
          // yazıda ikincil eylem sarar ve satır uzar.
          constraints: const BoxConstraints(minHeight: sahneTapTarget),
          child: Center(child: secondary),
        ),
      ],
    );
  }
}

/// Kahraman yuvası: kilim şeritli sahne kartı. İçerik serbest (logo, soru
/// maketi); kartın boyu içeriğin boyudur.
class SahneEntryHero extends StatelessWidget {
  const SahneEntryHero({
    super.key,
    required this.child,
    this.role = SahneRole.learn,
    this.padding = const EdgeInsets.fromLTRB(
      SahneSpace.x4,
      SahneSpace.x5,
      SahneSpace.x4,
      SahneSpace.x4,
    ),
  });

  final Widget child;
  final SahneRole role;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Kilim şeridi açık kalan üç yerden biri (K4): giriş akışı hepsinde.
    return SahneStageCard(
      role: role,
      kilim: true,
      padding: padding,
      child: child,
    );
  }
}

/// Başlık (Manşet 28) ve isteğe bağlı gövde (Gövde, ikincil). Dört giriş
/// ekranının tek yazı ölçeği; hepsi sola yaslı.
class SahneEntryHeading extends StatelessWidget {
  const SahneEntryHeading({
    super.key,
    required this.title,
    this.body,
    this.compact = false,
  });

  final String title;
  final String? body;

  /// Kısa ekran: Manşet yerine Başlık.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: (compact ? SahneType.headline : SahneType.title).copyWith(
              color: t.tx,
            ),
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(body!, style: SahneType.body.copyWith(color: t.tx2)),
        ],
      ],
    );
  }
}

/// Giriş akışının MANZARA sahnesi (2026-10-28 kurul turu 2, R4).
///
/// Giriş ve açılış ekranlarının ortası boş kalıyordu (kurul: "logo üstte,
/// metin altta, arası delik"). Ana sayfadaki görev kartının dağ + güneş
/// manzarası ([SahneVistaPainter], gece yıldızlı) burada büyük bir kart olur;
/// [child] (logo ya da adım çizimi) gökyüzünün üst yarısında ortalanır.
/// Tek kaynak: ana sayfadaki şeritle aynı çizici, aynı palet, aynı dönem.
/// Gövde metni manzaranın ÜSTÜNE binmez; kart kendi satırıdır.
/// Büyük yazıda ya da kısa ekranda alçalır ([compactHeight]).
class SahneEntryScene extends StatelessWidget {
  const SahneEntryScene({
    super.key,
    this.child,
    this.height = regularHeight,
    this.embedded = false,
  });

  final Widget? child;
  final double height;

  /// Bir hero kartın içine gömülü: kendi pahlı kırpması yok (kartın kırpması
  /// geçerli), ayrı bir blok gibi görünmez (U2, 2026-10-28 tur 4).
  final bool embedded;

  static const double regularHeight = 176;
  static const double compactHeight = 104;

  /// Kayıt ve ad ekranı: form uzun olduğundan giriş manzarasının kısa hâli.
  static const double entryCompactHeight = 136;

  @override
  Widget build(BuildContext context) {
    final bigText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final h = bigText ? compactHeight : height;
    return ClipPath(
      clipper: embedded
          ? const _NoClip()
          : const ShapeBorderClipper(shape: SahneShape.l),
      child: SizedBox(
        height: h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                key: const ValueKey('entry-scene-vista'),
                painter: SahneVistaPainter.of(SahneVistaPhase.now()),
              ),
            ),
            if (child != null)
              Align(alignment: const Alignment(0, -0.45), child: child),
          ],
        ),
      ),
    );
  }
}

/// Kırpmayan kırpıcı: [SahneEntryScene.embedded] için.
class _NoClip extends CustomClipper<Path> {
  const _NoClip();

  @override
  Path getClip(Size size) => Path()..addRect(Offset.zero & size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
