import 'package:flutter/material.dart';

import '../../theme/sahne.dart';
import 'sahne_cards.dart';
import 'sahne_foundation.dart';

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
                    ?content,
                    if (!anchored) ...[
                      const SizedBox(height: SahneSpace.x4),
                      dockContent,
                    ],
                  ],
                );
                final Widget laidOut = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: head),
                          const SizedBox(width: SahneSpace.x8),
                          Expanded(flex: 6, child: main),
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
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.page,
                    SahneSpace.x2,
                    SahneSpace.page,
                    SahneSpace.x6,
                  ),
                  child: limited(laidOut),
                );
              }

              return Column(
                children: [
                  limited(
                    _TopBar(leading: leading, skip: skip, progress: progress),
                  ),
                  Expanded(child: paged ?? scrollBody()),
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
