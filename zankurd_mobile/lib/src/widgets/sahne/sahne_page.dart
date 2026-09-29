import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../theme/sahne.dart';
import 'sahne_foundation.dart';
import 'sahne_painters.dart';

/// Sahne sayfalarının durum çubuğu biçemi: zeminin parlaklığına göre.
SystemUiOverlayStyle _overlayFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      )
    : const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      );

/// 44'lük ikon düğmesi — geri ve kapat (maketteki `.sh-ibtn`).
///
/// M pah, Perde (`s1`) + gündüzde 1 px kenar, birincil metin ikonu.
class SahneIconButton extends StatelessWidget {
  const SahneIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        excludeFromSemantics: true,
        child: SahneTappable(
          shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
          color: t.s1,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 24, color: t.tx),
          ),
        ),
      ),
    );
  }
}

/// A · Sekme ana sayfası (Öğren, Yarış, Sıralama, Profil).
///
/// Maketteki yapı: durum çubuğu → 44'lük marka satırı [logo işareti Kulis
/// plakasında + "ZanKurd" | stat çipleri] → Başlık 28/32 (tam genişlik, en
/// çok 2 satır) → isteğe bağlı alt başlık (Gövde, ikincil) → 16 → içerik.
/// Başlık kartı yok, spot yok. Alt gezinme bu sayfanın değil, kabuğun
/// (`AppShell`) işidir.
///
/// Marka satırı büyük yazıda sığmazsa çipler alt satıra iner (taşmaz).
/// İçerik [children] (sayfa kenarı 16 verilir) ve ardından [slivers]
/// (kenarsız; ör. kenara taşan raf) olarak kayar.
class SahneTabPage extends StatelessWidget {
  const SahneTabPage({
    super.key,
    required this.title,
    this.subtitle,
    this.stats = const [],
    this.children = const [],
    this.slivers = const [],
    this.brandName = 'ZanKurd',
    this.controller,
  });

  final String title;
  final String? subtitle;

  /// Marka satırının sağındaki stat çipleri (`SahneStatChip`).
  final List<Widget> stats;
  final List<Widget> children;
  final List<Widget> slivers;
  final String brandName;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final brightness = Theme.of(context).brightness;
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: SahneSpace.x1,
              spacing: SahneSpace.x3,
              children: [
                _BrandMark(
                  name: brandName,
                  day: brightness == Brightness.light,
                ),
                if (stats.isNotEmpty)
                  Wrap(
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: stats,
                  ),
              ],
            ),
          ),
          const SizedBox(height: SahneSpace.x1),
          Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SahneType.title.copyWith(
                color: t.tx,
                letterSpacing: -0.28,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(subtitle!, style: SahneType.body.copyWith(color: t.tx2)),
          ],
          const SizedBox(height: SahneSpace.titleGap),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayFor(brightness),
      // Material: metin biçemleri temadan gelsin (çıplak bir ağaçta
      // `DefaultTextStyle.fallback` sarı alt çizgi basar).
      child: Material(
        color: t.bg,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(child: header),
              if (children.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SahneSpace.page,
                  ),
                  sliver: SliverList.list(children: children),
                ),
              ...slivers,
              const SliverToBoxAdapter(child: SizedBox(height: SahneSpace.x6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marka: 32'lik logo plakası (gecede Kulis, gündüzde beyaz + 1 px kenar;
/// dağlar kaybolmasın) + "ZanKurd" (düğme biçemi).
class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.name, required this.day});

  final String name;
  final bool day;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: day ? t.s1 : t.s2,
              shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
            ),
            child: SizedBox.square(
              dimension: 32,
              child: Center(
                child: Image.asset(
                  'assets/zankurd_icon.webp',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const SizedBox.square(dimension: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          Text(name, style: SahneType.button.copyWith(color: t.tx)),
        ],
      ),
    );
  }
}

/// B · Açılan sayfa (öğrenme yolu, kategori, mağaza, ayarlar, oda …).
///
/// Maketteki yapı: durum çubuğu → en az 64'lük çubuk [44'lük M pahlı geri
/// düğmesi | Manşet 22 başlık + Açıklama alt satır] → içerik. Sayfa adı
/// içerikte tekrar edilmez; alt gezinme yok. Durum çubuğu biçemi temaya
/// uyar. Geri düğmesinin sözü verilmezse Material yerelinden gelir.
class SahnePushedPage extends StatelessWidget {
  const SahnePushedPage({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backLabel,
    this.actions = const [],
    this.children = const [],
    this.slivers = const [],
    this.bottom,
    this.controller,
  });

  final String title;
  final String? subtitle;

  /// Varsayılan: `Navigator.maybePop`.
  final VoidCallback? onBack;
  final String? backLabel;

  /// Çubuğun sağındaki 44'lük düğmeler (isteğe bağlı).
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget> slivers;

  /// İçeriğin altında sabit duran alan (ör. tek birincil eylem).
  final Widget? bottom;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final back =
        backLabel ?? MaterialLocalizations.of(context).backButtonTooltip;
    final bar = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.page,
          vertical: SahneSpace.x2,
        ),
        child: Row(
          children: [
            SahneIconButton(
              icon: AppIcons.arrowLeft,
              semanticLabel: back,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: SahneType.headline.copyWith(color: t.tx),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                ],
              ),
            ),
            for (final a in actions) ...[
              const SizedBox(width: SahneSpace.x2),
              a,
            ],
          ],
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayFor(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Column(
            children: [
              bar,
              Expanded(
                child: CustomScrollView(
                  controller: controller,
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: SahneSpace.x2),
                    ),
                    if (children.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SahneSpace.page,
                        ),
                        sliver: SliverList.list(children: children),
                      ),
                    ...slivers,
                    const SliverToBoxAdapter(
                      child: SizedBox(height: SahneSpace.x6),
                    ),
                  ],
                ),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.page,
                    SahneSpace.x2,
                    SahneSpace.page,
                    SahneSpace.x3,
                  ),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// C · Oyun sahnesi (soru, sonuç, düello, etkinlik oyunu).
///
/// Her iki temada GECE çizilir (`AppTheme.stage`). Katmanlar, alttan üste:
/// alttan ışıma → isteğe bağlı sahne zemini ([backdrop]: kategori çizimi
/// %14 opaklık, üst 320 px, altta zemine degrade; bulanıklık ve `Opacity`
/// katmanı yok) → dar ışık huzmesi ([beam]; `Path` + `LinearGradient`) →
/// üst satır [kapat 44 | ortada [center] (sayaç ya da bağlam) | [score]]
/// → isteğe bağlı elmas dizisi ([progress]) → içerik ([body]) → alt perde
/// ([dock]: zemine kararan 24 px degrade, altında tek birincil eylem ya
/// da joker dizisi).
///
/// İki isteğe bağlı katman (soru sahnesi için):
///
/// * [light] — kategori ışığı ([SahneCategoryLight]): huzme bu renkle
///   çizilir. `null` → varsayılan huzme.
/// * [ridge] — sahnenin ufku: logodaki dağlardan alçak bir dağ sırtı
///   silueti (Perde'nin %40'ı, [SahneRidgePainter]). Gövdenin DİBİNE,
///   alt perdenin hemen üstüne oturur: alttan ışımanın önünde siluet olarak
///   okunur ve içeriğin altında kalan boş sahneye bir zemin çizgisi verir.
///   İçerik uzunsa sırtın önünden kayar (sırt hep arkadadır).
class SahneStageScaffold extends StatelessWidget {
  const SahneStageScaffold({
    super.key,
    required this.body,
    this.onClose,
    this.closeLabel,
    this.center,
    this.score,
    this.progress,
    this.dock,
    this.backdrop,
    this.beam = true,
    this.light,
    this.ridge = false,
  });

  final Widget body;

  /// Varsayılan: `Navigator.maybePop`.
  final VoidCallback? onClose;
  final String? closeLabel;
  final Widget? center;
  final Widget? score;
  final Widget? progress;
  final Widget? dock;
  final ImageProvider? backdrop;
  final bool beam;

  /// Kategori ışığı: huzmenin rengi (yalnız ışık; dolgu değil).
  final Color? light;

  /// Gövdenin dibinde (alt perdenin üstünde) dağ sırtı ufku.
  final bool ridge;

  /// Sahne zemini bölgesinin yüksekliği (kategori çizimi bunun içinde).
  static const double backdropHeight = 320;

  /// Dağ sırtının yüksekliği: alçak kalır, çizimi örtmez.
  static const double ridgeHeight = 56;

  /// Bağlam metni ("Karışık • 3 soru") için orta yuva biçemi.
  static TextStyle contextStyle(BuildContext context) =>
      SahneType.captionStrong.copyWith(color: SahneTokens.of(context).tx2);

  @override
  Widget build(BuildContext context) {
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final t = SahneTokens.of(context);
    final close =
        closeLabel ?? MaterialLocalizations.of(context).closeButtonTooltip;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final topBar = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
        child: CustomMultiChildLayout(
          delegate: _GameBarLayout(),
          children: [
            LayoutId(
              id: _GameBarSlot.leading,
              child: SahneIconButton(
                icon: AppIcons.xmark,
                semanticLabel: close,
                onPressed: onClose ?? () => Navigator.maybePop(context),
              ),
            ),
            if (center != null)
              LayoutId(
                id: _GameBarSlot.center,
                child: DefaultTextStyle.merge(
                  style: contextStyle(context),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: center!,
                ),
              ),
            if (score != null)
              LayoutId(id: _GameBarSlot.trailing, child: score!),
          ],
        ),
      ),
    );

    final artwork = backdrop;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayFor(Brightness.dark),
      child: Scaffold(
        backgroundColor: t.bg,
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: SahneUnderglowPainter()),
              ),
            ),
            if (artwork != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: backdropHeight,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: artwork,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.4),
                          color: SahneStageColors.backdropTint,
                          colorBlendMode: BlendMode.modulate,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [t.bg.withValues(alpha: 0), t.bg],
                              stops: const [0, 0.92],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (beam)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 440,
                child: IgnorePointer(
                  child: Center(
                    child: SizedBox(
                      width: 360,
                      height: 440,
                      child: CustomPaint(
                        key: const ValueKey('sahne-stage-beam'),
                        painter: SahneBeamPainter(light: light),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topBar,
                  if (progress != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SahneSpace.page,
                      ),
                      child: Center(child: progress),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        if (ridge)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: ridgeHeight,
                            child: IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey('sahne-stage-ridge'),
                                painter: SahneRidgePainter(
                                  t.s1.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        Positioned.fill(child: body),
                        if (dock != null)
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
                                    colors: [t.bg.withValues(alpha: 0), t.bg],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (dock != null)
                    ColoredBox(
                      color: t.bg,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          SahneSpace.page,
                          SahneSpace.x2,
                          SahneSpace.page,
                          safeBottom > 0
                              ? safeBottom + SahneSpace.x3
                              : SahneSpace.x4,
                        ),
                        child: dock,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyun sahnesinin gövdesi için kolaylık: sayfa kenarı 16, kayar.
/// ([SahneStageScaffold.body] çoğu ekranda budur.)
class SahneStageBody extends StatelessWidget {
  const SahneStageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x4,
        SahneSpace.page,
        SahneSpace.x6,
      ),
      children: children,
    );
  }
}

enum _GameBarSlot { leading, center, trailing }

/// Oyun sahnesinin üst satırı: CSS `grid-template-columns: 1fr auto 1fr`
/// karşılığı. Orta yuva her zaman TAM ortadadır (yan öğelerin genişliği
/// farklı olsa da); genişliği iki yandaki geniş öğeye göre sınırlanır.
/// Yükseklik 68 (en az); büyük yazıda orta metin uzarsa satır uzar.
class _GameBarLayout extends MultiChildLayoutDelegate {
  static const double _height = 68;

  @override
  Size getSize(BoxConstraints constraints) => Size(
    constraints.maxWidth,
    _height.clamp(constraints.minHeight, constraints.maxHeight),
  );

  @override
  void performLayout(Size size) {
    final w = size.width;
    final loose = BoxConstraints(
      maxWidth: w / 2 - SahneSpace.x1,
      maxHeight: size.height,
    );
    var lw = 0.0;
    var tw = 0.0;
    if (hasChild(_GameBarSlot.leading)) {
      final s = layoutChild(_GameBarSlot.leading, loose);
      lw = s.width;
      positionChild(
        _GameBarSlot.leading,
        Offset(0, (size.height - s.height) / 2),
      );
    }
    if (hasChild(_GameBarSlot.trailing)) {
      final s = layoutChild(_GameBarSlot.trailing, loose);
      tw = s.width;
      positionChild(
        _GameBarSlot.trailing,
        Offset(w - s.width, (size.height - s.height) / 2),
      );
    }
    if (hasChild(_GameBarSlot.center)) {
      final side = lw > tw ? lw : tw;
      final maxW = (w - 2 * (side + SahneSpace.x2)).clamp(0.0, w);
      final s = layoutChild(
        _GameBarSlot.center,
        BoxConstraints(maxWidth: maxW, maxHeight: size.height),
      );
      positionChild(
        _GameBarSlot.center,
        Offset((w - s.width) / 2, (size.height - s.height) / 2),
      );
    }
  }

  @override
  bool shouldRelayout(_GameBarLayout oldDelegate) => false;
}
