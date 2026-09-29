import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// 44'lük ikon düğmesi — geri, kapat ve çubuk eylemleri (maketteki
/// `.sh-ibtn`).
///
/// M pah, Perde (`s1`) + gündüzde 1 px kenar, birincil metin ikonu.
///
/// Görsel 44, dokunma alanı 48 ([sahneTapTarget]): plaka 48'lik saydam bir
/// kutunun ortasında durur, ekran okuyucu tek bir 48'lik düğme görür.
/// Bileşenin kendi yerleşim boyu 48'dir; sayfa kenarına hizalarken plakanın
/// görsel kenarı için [inset] kadar içeri alınır.
///
/// [selected] verilirse düğme bir aç/kapa düğmesidir (ör. "kaydet"): `true`
/// iken dolu hâl — Zêr tonu + Halka 1 altın + altın ikon ([selectedIcon]
/// verilirse o) — ve ekran okuyucu seçili durumunu duyar. `null` → düz
/// düğme. Pasif (`onPressed: null`): üçüncül ikon.
class SahneIconButton extends StatelessWidget {
  const SahneIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.selected,
    this.selectedIcon,
    this.tooltip,
  });

  final IconData icon;
  final String semanticLabel;

  /// Uzun basış ipucu; varsayılan [semanticLabel].
  final String? tooltip;
  final VoidCallback? onPressed;

  /// Aç/kapa durumu; `null` → aç/kapa değil.
  final bool? selected;
  final IconData? selectedIcon;

  /// Görsel plakanın kenarı.
  static const double visualSize = 44;

  /// Dokunma kutusunun görsel plakadan taşan payı (her yanda 2).
  static const double inset = (sahneTapTarget - visualSize) / 2;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    final on = selected ?? false;
    final plate = SahneTappable(
      shape: on
          ? SahneShape.withSide(SahneShape.m, t.goldTx, width: SahneRing.r1)
          : SahneShape.withSide(SahneShape.m, t.edge, width: 1),
      color: on ? t.goldTint : t.s1,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: visualSize,
        child: Icon(
          on ? (selectedIcon ?? icon) : icon,
          size: 24,
          color: on ? t.goldTx : (enabled ? t.tx : t.tx3),
        ),
      ),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: selected,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip ?? semanticLabel,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: sahneTapTarget,
            child: Center(child: plate),
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
/// Marka satırı büyük yazıda sığmazsa çipler alt satıra iner (taşmaz) ve
/// orada da SAĞA yaslı kalır: marka solda, stat çipleri sağda — tek satırda
/// da iki satırda da aynı taraf. Başlık satır sınırı olmadan sarar.
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
            child: _BrandRow(
              gap: SahneSpace.x3,
              runSpacing: SahneSpace.x1,
              children: [
                _BrandMark(
                  name: brandName,
                  day: brightness == Brightness.light,
                ),
                if (stats.isNotEmpty)
                  Wrap(
                    alignment: WrapAlignment.end,
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
            // Büyük yazıda başlık sarar, kesilmez; tek bir uzun söz dar
            // ekranda harf harf bölünmez (bkz. [SahneUnbrokenText]).
            child: SahneUnbrokenText(
              title,
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

/// Marka satırının yerleşimi: [children]'ın ilki (marka) solda, ikincisi
/// (stat çipleri) sağda. İkisi yan yana sığmıyorsa ikincisi alt satıra
/// iner ve orada da sağa yaslanır (`Wrap` alt satırı sola yaslıyordu).
class _BrandRow extends MultiChildRenderObjectWidget {
  const _BrandRow({
    required super.children,
    required this.gap,
    required this.runSpacing,
  });

  final double gap;
  final double runSpacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBrandRow(gap, runSpacing, Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderBrandRow renderObject) {
    renderObject
      ..gap = gap
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }
}

class _BrandRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBrandRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BrandRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BrandRowParentData> {
  _RenderBrandRow(this._gap, this._runSpacing, this._textDirection);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double v) {
    if (v == _runSpacing) return;
    _runSpacing = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BrandRowParentData) {
      child.parentData = _BrandRowParentData();
    }
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      out.add(child);
      child = childAfter(child);
    }
    return out;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _kids.fold(
    0,
    (m, c) => math.max(m, c.getMinIntrinsicWidth(double.infinity)),
  );

  @override
  double computeMaxIntrinsicWidth(double height) {
    final kids = _kids;
    var w = 0.0;
    for (var i = 0; i < kids.length; i++) {
      if (i > 0) w += _gap;
      w += kids[i].getMaxIntrinsicWidth(double.infinity);
    }
    return w;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() {
    size = _layout(constraints, dry: false);
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final kids = _kids;
    final maxW = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxW);
    final sizes = [
      for (final k in kids)
        dry
            ? k.getDryLayout(loose)
            : (k..layout(loose, parentUsesSize: true)).size,
    ];
    if (kids.isEmpty) return constraints.smallest;
    final rtl = _textDirection == TextDirection.rtl;
    double startX(Size s) => rtl ? maxW - s.width : 0;
    double endX(Size s) => rtl ? 0 : maxW - s.width;
    final lead = sizes.first;
    if (kids.length == 1) {
      if (!dry) {
        (kids.first.parentData! as _BrandRowParentData).offset = Offset(
          startX(lead),
          0,
        );
      }
      return constraints.constrain(Size(maxW, lead.height));
    }
    final trail = sizes[1];
    final oneRow = lead.width + _gap + trail.width <= maxW;
    final double height;
    if (oneRow) {
      height = math.max(
        constraints.minHeight,
        math.max(lead.height, trail.height),
      );
      if (!dry) {
        (kids[0].parentData! as _BrandRowParentData).offset = Offset(
          startX(lead),
          (height - lead.height) / 2,
        );
        (kids[1].parentData! as _BrandRowParentData).offset = Offset(
          endX(trail),
          (height - trail.height) / 2,
        );
      }
    } else {
      // İki satırda marka satırı markanın kendi boyundadır (en az 44
      // değil): çipler markanın hemen altına iner, üstte boş bant kalmaz.
      final top = lead.height;
      height = math.max(
        constraints.minHeight,
        top + _runSpacing + trail.height,
      );
      if (!dry) {
        (kids[0].parentData! as _BrandRowParentData).offset = Offset(
          startX(lead),
          (top - lead.height) / 2,
        );
        (kids[1].parentData! as _BrandRowParentData).offset = Offset(
          endX(trail),
          top + _runSpacing,
        );
      }
    }
    return constraints.constrain(Size(maxW, height));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
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
/// düğmesi (48 dokunma) | Manşet 22 başlık + Açıklama alt satır] → içerik.
/// Sayfa adı içerikte tekrar edilmez; alt gezinme yok. Durum çubuğu biçemi
/// temaya uyar. Geri düğmesinin sözü verilmezse uygulamanın dilinden gelir
/// ([sahneBackLabel]).
///
/// Çubuk büyük yazıda uzar: başlık sarar, tek bir uzun söz harf harf
/// bölünmez ([SahneUnbrokenText]). [bottom] (tek birincil eylem) gövdenin
/// DIŞINDA, `Scaffold`un alt yuvasındadır: SnackBar onun üstünde açılır,
/// düğmeyi örtmez; klavye açılınca klavyenin üstüne çıkar.
class SahnePushedPage extends StatelessWidget {
  const SahnePushedPage({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backLabel,
    this.backKey,
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

  /// Geri düğmesinin anahtarı (testler ve sabit ekran sözleşmeleri için).
  final Key? backKey;

  /// Çubuğun sağındaki düğmeler (genelde [SahneIconButton]; 48 dokunma).
  final List<Widget> actions;
  final List<Widget> children;
  final List<Widget> slivers;

  /// İçeriğin altında sabit duran alan (ör. tek birincil eylem).
  final Widget? bottom;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final back = backLabel ?? sahneBackLabel(context);
    final bar = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        // Geri plakasının görsel kenarı sayfa kenarına (16) oturur; 48'lik
        // dokunma kutusu 2 px dışarı taşar.
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.page - SahneIconButton.inset,
          SahneSpace.x2,
          SahneSpace.page - SahneIconButton.inset,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            SahneIconButton(
              key: backKey,
              icon: AppIcons.arrowLeft,
              semanticLabel: back,
              onPressed: onBack ?? () => Navigator.maybePop(context),
            ),
            const SizedBox(width: SahneSpace.x3 - SahneIconButton.inset),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: SahneUnbrokenText(
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
              const SizedBox(width: SahneSpace.x1),
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
            ],
          ),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : SahneBottomDock(
                color: t.bg,
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  SahneSpace.x3,
                ),
                child: bottom!,
              ),
      ),
    );
  }
}

/// Sayfanın alt yuvası (`Scaffold.bottomNavigationBar`): tek birincil
/// eylem ya da joker dizisi.
///
/// Gövdenin dışındadır: `Scaffold` SnackBar'ı bu yuvanın ÜSTÜNDE açar
/// (gövdenin içindeyken SnackBar birincil düğmeyi örtüyordu). Klavye
/// açılınca yuva klavyenin üstüne çıkar (yuvanın altına klavye boyu kadar
/// boşluk eklenir; gövde de o kadar kısalır). Alt güvenli alanı kendisi
/// verir.
class SahneBottomDock extends StatelessWidget {
  const SahneBottomDock({
    super.key,
    required this.child,
    required this.color,
    required this.padding,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return ColoredBox(
      color: color,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            // Yuva içeriği sınırsız yükseklik alır (gövdedeki `Column`da
            // olduğu gibi): `Center` gibi genişleyen bir çocuk bütün ekranı
            // kaplamasın.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [child],
            ),
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
/// Kapat düğmesi görselde 44, dokunmada 48 ([SahneIconButton]); anahtarı
/// [closeKey]. Alt perde gövdenin DIŞINDA, `Scaffold`un alt yuvasındadır
/// ([SahneBottomDock]): SnackBar onun üstünde açılır, klavye açılınca
/// perde klavyenin üstüne çıkar. Sahne zemini (ışıma, huzme) perdenin
/// arkasına kadar uzanır (`extendBody`).
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
    this.closeKey,
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

  /// Kapat düğmesinin anahtarı.
  final Key? closeKey;
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
    final close = closeLabel ?? sahneCloseLabel(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final dockWidget = dock;

    final topBar = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Padding(
        // Kapat plakasının görsel kenarı sayfa kenarına (16) oturur; 48'lik
        // dokunma kutusu 2 px dışarı taşar. Sağ öğe yine 16'ya hizalanır
        // (bkz. [_GameBarLayout.trailingInset]).
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.page - SahneIconButton.inset,
        ),
        child: CustomMultiChildLayout(
          delegate: _GameBarLayout(),
          children: [
            LayoutId(
              id: _GameBarSlot.leading,
              child: SahneIconButton(
                key: closeKey,
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
        extendBody: dockWidget != null,
        bottomNavigationBar: dockWidget == null
            ? null
            : SahneBottomDock(
                color: t.bg,
                padding: EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  safeBottom > 0 ? SahneSpace.x3 : SahneSpace.x4,
                ),
                child: dockWidget,
              ),
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
              child: Builder(
                // `extendBody`: gövde alt perdenin arkasına uzanır; içerik
                // perdenin üstünde biter (perdenin boyu gövdenin alt
                // boşluğundadır).
                builder: (context) => Padding(
                  padding: EdgeInsets.only(
                    bottom: dockWidget == null
                        ? 0
                        : MediaQuery.paddingOf(context).bottom,
                  ),
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
                            if (dockWidget != null)
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
                    ],
                  ),
                ),
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

  /// Satır, kapat düğmesinin 48'lik dokunma kutusu için sayfa kenarından
  /// 2 px taşar; sağ öğe (skor) yine sayfa kenarına (16) oturur.
  static const double trailingInset = SahneIconButton.inset;

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
      tw = s.width + trailingInset;
      positionChild(
        _GameBarSlot.trailing,
        Offset(w - s.width - trailingInset, (size.height - s.height) / 2),
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
