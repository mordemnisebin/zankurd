import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/sahne.dart';
import '../zan_mascot.dart';
import 'sahne_foundation.dart';
import 'sahne_glyphs.dart';
import 'sahne_painters.dart';

/// "Vay" katmanı ortak parçaları (VAY_KATMANI A1–A3 + A5, 2026-10-29).
///
/// ## Kusur
///
/// Tasarım kurulu 6 turda düz yüzeyleri temizledi; geriye "temiz ama
/// cansız" bir arayüz kaldı: düğme düz turuncu bir dikdörtgen, kartlar
/// yassı. Rakipte (Duolingo düğmesi, TRT mod kartları) yüzeyin bir HACMİ var:
/// düğmenin koyu bir tabanı, kartın üstte ışığı, altta gölgesi.
///
/// ## Karar
///
/// Hacim üç küçük reçeteyle verilir ve her yerde AYNI reçete kullanılır:
/// birincil düğmenin tabanı ([SahneVolume]), kartların kabartması
/// ([SahneEmbossStyle] + [SahneEmbossPainter]) ve hero alt kenarındaki
/// kilim şeridi ([SahneKilimBorderPainter]). Hareket yardımcıları
/// ([SahneEnter], [SahneScaleIn], [SahneConfettiBurst]) "hareketi azalt"
/// açıkken ([sahneMotionReduced]) hiçbir şeyi oynatmaz.
/// "Hareketi azalt" açık mı ([sahneMotionReduced]).
bool _reduceMotion(BuildContext context) => sahneMotionReduced(context);

class SahneVolume {
  const SahneVolume._();

  /// Birincil düğmenin asgari yüksekliği (eski 52 → 56).
  static const double buttonHeight = 56;

  /// Düğme köşe yarıçapı.
  static const double buttonRadius = 18;

  /// Dinlenme hâlinde koyu taban kalınlığı; basınca 2 px'e iner.
  static const double base = 4;

  /// Basınca düğme yüzünün çöküşü.
  static const double press = 2;

  /// Koyu taban rengi (#B94D13).
  static const Color baseColor = SahneVayColors.buttonBase;

  /// Taban basınca 80 ms'de iner, bırakınca 120 ms'de döner.
  static const Duration pressDown = Duration(milliseconds: 80);
  static const Duration pressUp = Duration(milliseconds: 120);

  /// Düğme yüzünün gradyanı: üstte açık, altta jetonun kendisi.
  static LinearGradient face(Color act, {bool pressed = false}) {
    final top = Color.lerp(act, SahneVayColors.white, 0.22)!;
    final bottom = act;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: pressed
          ? [
              Color.lerp(top, SahneVayColors.black, 0.08)!,
              Color.lerp(bottom, SahneVayColors.black, 0.08)!,
            ]
          : [top, bottom],
    );
  }
}

/// Kabartma kartın ışık/gölge ayarı (A2).
///
/// [saturated] doygun yüzeylerde (oyun lobisi kartları) ışık %16'dır; açık
/// temadaki tonlu kartta %60, koyu temada %12 (üstteki beyaz parıltı).
class SahneEmbossStyle {
  const SahneEmbossStyle({required this.night, this.saturated = false});

  final bool night;
  final bool saturated;

  /// Üst %35'teki beyaz→saydam ışığın başlangıç opaklığı.
  double get lightAlpha => saturated ? 0.16 : (night ? 0.12 : 0.60);

  /// Üst kenardaki 1 px parlama.
  double get rimAlpha => saturated ? 0.34 : (night ? 0.16 : 0.70);

  /// Alt iç kenarın 2 px koyulaşması (siyah katman). Vay 2A (2026-10-29):
  /// gündüz %10 → %5 — Astra: kartın altı "çift katman" gibi duruyordu.
  double get shadeAlpha => saturated ? 0.14 : (night ? 0.18 : 0.05);

  /// Dış gölge: y=2 blur=8 (vay 2A; eskiden y=8 blur=14 kartın altında gri
  /// bir ikinci plaka gibi okunuyordu — Astra "kirli gri gölge", "kalın alt
  /// gölgeleri 2 dp derinliğe indirin").
  static const BoxShadow outerShadow = BoxShadow(
    color: SahneVayColors.cardShadow,
    offset: Offset(0, 2),
    blurRadius: 8,
  );

  /// Kartın dış gölgesi: gündüz kartın KENDİ renginin koyusu (%22), gece
  /// siyah %32 ([SahneVayColors.cardShadowNight]); [tint] yoksa nötr.
  static BoxShadow shadowFor({Color? tint, required bool night}) {
    if (night) {
      return const BoxShadow(
        color: SahneVayColors.cardShadowNight,
        offset: Offset(0, 2),
        blurRadius: 8,
      );
    }
    if (tint == null) return outerShadow;
    return BoxShadow(
      color: Color.lerp(
        tint,
        SahneVayColors.black,
        0.55,
      )!.withValues(alpha: 0.22),
      offset: outerShadow.offset,
      blurRadius: outerShadow.blurRadius,
    );
  }

  static SahneEmbossStyle of(BuildContext context, {bool saturated = false}) =>
      SahneEmbossStyle(
        night: Theme.of(context).brightness == Brightness.dark,
        saturated: saturated,
      );
}

/// Kartın kabartma katmanı: yüzün ÜSTÜNE, içeriğin ALTINA çizilir
/// (`CustomPaint.painter`). Kartın şekline kırpılır.
class SahneEmbossPainter extends CustomPainter {
  const SahneEmbossPainter({required this.shape, required this.style});

  final ShapeBorder shape;
  final SahneEmbossStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipPath(shape.getOuterPath(rect));
    final topH = size.height * 0.35;
    final light = Rect.fromLTWH(0, 0, size.width, topH);
    canvas.drawRect(
      light,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            SahneVayColors.white.withValues(alpha: style.lightAlpha),
            SahneVayColors.white.withValues(alpha: 0),
          ],
        ).createShader(light),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 1),
      Paint()..color = SahneVayColors.white.withValues(alpha: style.rimAlpha),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 2, size.width, 2),
      Paint()..color = SahneVayColors.black.withValues(alpha: style.shadeAlpha),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneEmbossPainter old) =>
      old.shape != shape ||
      old.style.night != style.night ||
      old.style.saturated != style.saturated;
}

/// Kabartılmış kartın dış kabuğu: dış gölge + basınca 90 ms'de 2 px çökme.
///
/// İçine kartın kendisi (yüzü kendi çizen `SahneTappable`, `Ink` …) konur;
/// kabartma ışığı için kartın İÇERİĞİ [SahneEmbossPainter] ile sarılır
/// (`SahneTappable.emboss` ikisini birlikte yapar).
class SahneEmbossShell extends StatefulWidget {
  const SahneEmbossShell({
    required this.shape,
    required this.child,
    this.pressable = false,
    this.shadowColor,
    this.tint,
    super.key,
  });

  final ShapeBorder shape;
  final bool pressable;
  final Widget child;

  /// Kartın yüz rengi: gündüz gölgesi bu rengin koyusundan türer
  /// ([SahneEmbossStyle.shadowFor]).
  final Color? tint;

  /// Dış gölgenin rengi (varsayılan siyah %14). Doygun kartta kartın kendi
  /// rengi: gri bir "plaka" yerine renkli bir ışıma.
  final Color? shadowColor;

  @override
  State<SahneEmbossShell> createState() => _SahneEmbossShellState();
}

class _SahneEmbossShellState extends State<SahneEmbossShell> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final sink = widget.pressable && _down && !_reduceMotion(context);
    Widget body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: widget.shape,
        shadows: [
          if (widget.shadowColor == null)
            SahneEmbossStyle.shadowFor(
              tint: widget.tint,
              night: Theme.of(context).brightness == Brightness.dark,
            )
          else
            BoxShadow(
              color: widget.shadowColor!,
              offset: SahneEmbossStyle.outerShadow.offset,
              blurRadius: SahneEmbossStyle.outerShadow.blurRadius,
            ),
        ],
      ),
      child: widget.child,
    );
    if (!widget.pressable) return body;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: _SinkBy2(sink: sink, child: body),
    );
  }
}

/// 2 px'lik mutlak çökme (AnimatedSlide oransaldır; kart boyundan bağımsız
/// 2 px için [TweenAnimationBuilder]).
class _SinkBy2 extends StatelessWidget {
  const _SinkBy2({required this.sink, required this.child});

  final bool sink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: sink ? SahneVolume.press : 0),
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      builder: (context, dy, child) =>
          Transform.translate(offset: Offset(0, dy), child: child),
      child: child,
    );
  }
}

/// Kilim kenar boyacısı (A3): 24 birim GENİŞLİKTE tekrar eden birim — baklava,
/// basamaklı üçgen, kısa çizgi — şeridin yüksekliğine ölçeklenir.
///
/// Açık yüzeyde #245C69 %7, koyu sahnede beyaz %9 ([SahneKilimBorderPainter.lightOn],
/// [SahneKilimBorderPainter.darkOn]). Yalnız hero alt 4–6 px şeridi, bölüm
/// ayıracı ya da rozet çevresi için; ekran başına ≤ 2 bölge; metnin altına
/// girmez. Dekoratiftir.
class SahneKilimBorderPainter extends CustomPainter {
  const SahneKilimBorderPainter(this.color);

  /// Açık yüzey rengi (#245C69 %7).
  static const Color lightOn = SahneVayColors.kilimOnLight;

  /// Koyu sahne rengi (beyaz %9).
  static const Color darkOn = SahneVayColors.kilimOnDark;

  /// Tekrar biriminin genişliği.
  static const double unit = 24;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final h = size.height;
    final count = (size.width / unit).ceil();
    final paint = Paint()..color = color;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < count; i++) {
      final x = i * unit;
      // 1) baklava (0–10)
      canvas.drawPath(
        Path()
          ..moveTo(x + 5, 0)
          ..lineTo(x + 10, h / 2)
          ..lineTo(x + 5, h)
          ..lineTo(x, h / 2)
          ..close(),
        paint,
      );
      // 2) basamaklı üçgen (10–20)
      final s = h / 3;
      canvas.drawPath(
        Path()
          ..moveTo(x + 11, h)
          ..lineTo(x + 11, h - s)
          ..lineTo(x + 14, h - s)
          ..lineTo(x + 14, h - 2 * s)
          ..lineTo(x + 17, h - 2 * s)
          ..lineTo(x + 17, 0)
          ..lineTo(x + 19, 0)
          ..lineTo(x + 19, h)
          ..close(),
        paint,
      );
      // 3) kısa çizgi (20–24)
      canvas.drawRect(
        Rect.fromLTWH(x + 21, h / 2 - h * 0.12, 3, h * 0.24),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneKilimBorderPainter old) => old.color != color;
}

/// Kilim kenar şeridi (4–6 px). Dekoratif.
class SahneKilimBorder extends StatelessWidget {
  const SahneKilimBorder({required this.color, this.height = 6, super.key});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('sahne-kilim-border'),
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: SahneKilimBorderPainter(color)),
      ),
    );
  }
}

/// Giriş hareketi (A5): opaklık 0→1 + 6 px yükselme, 240 ms, tek sefer.
/// "Hareketi azalt" açıkken çocuk doğrudan, sabit çizilir.
class SahneEnter extends StatefulWidget {
  const SahneEnter({
    required this.child,
    this.delay = Duration.zero,
    super.key,
  });

  final Widget child;
  final Duration delay;

  @override
  State<SahneEnter> createState() => _SahneEnterState();
}

class _SahneEnterState extends State<SahneEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = Curves.easeOut.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 6 * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Ölçek girişi (A5): 0,94 → 1, 280 ms, tek sefer (madalya, avatar).
class SahneScaleIn extends StatefulWidget {
  const SahneScaleIn({required this.child, super.key});

  final Widget child;

  @override
  State<SahneScaleIn> createState() => _SahneScaleInState();
}

class _SahneScaleInState extends State<SahneScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_reduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.94,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
      child: widget.child,
    );
  }
}

/// Konfeti (A5): 12–16 parça, 650 ms, TEK sefer. Hareketi azaltta hiç
/// çizilmez ([SizedBox.shrink]). Yalnız kutlanacak anda (≥ 2 yıldız) açılır.
class SahneConfettiBurst extends StatefulWidget {
  const SahneConfettiBurst({this.count = 14, this.colors, super.key});

  /// 12–16 arası kelepçelenir.
  final int count;

  /// Verilmezse Zêr + role renkleri.
  final List<Color>? colors;

  /// Süre (A5).
  static const Duration duration = Duration(milliseconds: 650);

  @override
  State<SahneConfettiBurst> createState() => _SahneConfettiBurstState();
}

class _SahneConfettiBurstState extends State<SahneConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Hareketi azaltta hiç kullanılmasa da burada kurulur: `dispose`da tembel
    // kurulum, kapanmış bir öğeden ata sorgular ve çöker.
    _c = AnimationController(
      vsync: this,
      duration: SahneConfettiBurst.duration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!_reduceMotion(context)) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final colors =
        widget.colors ?? [t.gold, t.act, t.learn, t.race, SahneVayColors.white];
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            key: const ValueKey('sahne-confetti-burst'),
            size: Size.infinite,
            painter: _ConfettiBurstPainter(
              progress: _c.value,
              count: widget.count.clamp(12, 16),
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfettiBurstPainter extends CustomPainter {
  const _ConfettiBurstPainter({
    required this.progress,
    required this.count,
    required this.colors,
  });

  final double progress;
  final int count;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final origin = Offset(size.width / 2, size.height * 0.28);
    final ease = Curves.easeOutCubic.transform(progress);
    final fade = 1 - Curves.easeIn.transform(progress);
    for (var i = 0; i < count; i++) {
      // Sabit tohumlu dağılım: her çizimde aynı parçalar.
      final a = (i / count) * 2 * math.pi + (i.isEven ? 0.2 : -0.2);
      final speed = 70 + (i * 37 % 60);
      final dx = math.cos(a) * speed * ease;
      final dy = math.sin(a) * speed * ease * 0.8 + 38 * progress * progress;
      final c = colors[i % colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(a + progress * 5);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 4),
        Paint()..color = c,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiBurstPainter old) => old.progress != progress;
}

/// Sonuç ödül kompozisyonu (VAY B5): 104 px madalya (#FFE6A0 → #D7A744),
/// arkasında 184 px ışın diski (%18) ve yanında maskot (≥ 2 yıldızda
/// kutlama, düşükte destek).
///
/// Madalyanın yüzünde kazanılan yıldızlar durur (doluluk ayrımı taşır).
/// Madalya 280 ms'de ölçeklenerek girer ([SahneScaleIn]); konfeti YALNIZ
/// [stars] ≥ 2 iken ve hareketi azalt kapalıyken ([SahneConfettiBurst]).
/// Işın diski de yalnız ≥ 2 yıldızda: düşük turda kutlama ışığı sonucu
/// yanlış okutur. Dekoratiftir; sonucu başlık ve puan söyler.
class SahneMedalScene extends StatelessWidget {
  const SahneMedalScene({required this.stars, super.key});

  /// Kazanılan yıldız (0–3).
  final int stars;

  /// Madalya, ışın diski ve maskot boyları. Vay 2A (2026-10-29): maskot
  /// 120 → 84 ve madalyanın sol altına BİNER — madalya ile maskot yan yana iki
  /// ayrı odak değil, tek bir kutlama kümesidir (Astra: "madalya, maskot ve
  /// yıldızlar yarışıyor").
  static const double medalSize = 104;
  static const double discSize = 184;
  static const double mascotSize = 84;

  /// Maskotun madalyanın üstüne bindiği pay.
  static const double overlap = 26;

  /// Kümenin yerleşim genişliği: madalya ORTADA durur (puanla aynı eksen);
  /// maskot solda taşar.
  static const double width = medalSize;

  /// Konfeti ve kutlama maskotu eşiği.
  static const int celebrateAt = 2;

  bool get celebrate => stars >= celebrateAt;

  @override
  Widget build(BuildContext context) {
    final pose = celebrate ? ZanPose.celebrate : ZanPose.support;
    final mascotH = mascotSize / pose.aspect;
    return SizedBox(
      key: const ValueKey('result-medal-scene'),
      width: width,
      height: medalSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 0,
            width: medalSize,
            height: medalSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (celebrate)
                  const OverflowBox(
                    maxWidth: discSize,
                    maxHeight: discSize,
                    child: SizedBox.square(
                      key: ValueKey('result-ray-disc'),
                      dimension: discSize,
                      child: SahneRayDisc(size: discSize),
                    ),
                  ),
                SahneScaleIn(child: SahneMedal(stars: stars)),
              ],
            ),
          ),
          Positioned(
            left: overlap - mascotSize,
            bottom: -4,
            width: mascotSize,
            height: mascotH,
            child: ZanMascot(pose: pose, size: mascotSize),
          ),
          if (celebrate) const Positioned.fill(child: SahneConfettiBurst()),
        ],
      ),
    );
  }
}

/// Madalya: altın gradyan disk + iç halka + kazanılan yıldızlar.
class SahneMedal extends StatelessWidget {
  const SahneMedal({required this.stars, super.key});

  final int stars;

  static const Color goldTop = SahneVayColors.medalTop;
  static const Color goldBottom = SahneVayColors.medalBottom;
  static const Color rim = SahneVayColors.medalRim;
  static const Color starOn = SahneVayColors.medalStar;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        key: const ValueKey('result-medal'),
        dimension: SahneMedalScene.medalSize,
        child: CustomPaint(
          painter: const _MedalPainter(),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  SahneGlyph(
                    SahneGlyphKind.star,
                    size: i == 1 ? 28 : 21,
                    filled: i < stars,
                    color: i < stars
                        ? starOn
                        : SahneVayColors.white.withValues(alpha: 0.5),
                    edgeColor: Colors.transparent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SahneMedal.goldTop, SahneMedal.goldBottom],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = SahneMedal.rim,
    );
    canvas.drawCircle(
      c,
      r - 11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = SahneVayColors.white.withValues(alpha: 0.55),
    );
    // Üst-sol parlama yayı.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 6),
      math.pi * 1.05,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = SahneVayColors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_MedalPainter old) => false;
}

/// Madalyanın arkasındaki 184 px ışın diski: %18 altın ışınlar, merkezden
/// kenara sönen.
class _RayDiscPainter extends CustomPainter {
  const _RayDiscPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final fade = const RadialGradient(
      colors: [SahneVayColors.rayCenter, SahneVayColors.rayEdge],
      stops: [0.35, 1],
    ).createShader(rect);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    const rays = 14;
    final paint = Paint()..shader = fade;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      const half = math.pi / rays * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + r * math.cos(a - half), c.dy + r * math.sin(a - half))
          ..lineTo(c.dx + r * math.cos(a + half), c.dy + r * math.sin(a + half))
          ..close(),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RayDiscPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════
//  Vay 2A (2026-10-29): oyun dünyası parçaları
// ═══════════════════════════════════════════════════════════════════════
//
// Kusur (GPT-6 Astra ekran denetimi, rakip TRT / Trivia Crack / Clash):
// yarış lobisi "özellik menüsü", eşleşme "ayarlar listesi", turnuva yolu
// "birkaç etiket", çark "hazır bileşen" gibi okunuyordu. Karar: aşağıdaki
// paylaşılan parçalar; her biri tema belirteçleri ya da [SahneVayColors]
// ile boyanır, dekoratif kısımları ekran okuyucudan gizlidir ve hiçbiri
// "hareketi azalt" açıkken oynamaz.

/// Doygun kartın dibindeki alçak dağ silueti (logodaki sırt, siyah %14).
/// [layers] = 2 iken arkada aynalı ikinci bir katman (%8) durur.
class SahneTileRidge extends StatelessWidget {
  const SahneTileRidge({super.key, this.layers = 1});

  final int layers;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          key: const ValueKey('sahne-tile-ridge'),
          painter: _TileRidgePainter(layers: layers),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TileRidgePainter extends CustomPainter {
  const _TileRidgePainter({required this.layers});

  final int layers;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (layers > 1) {
      canvas.save();
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(
        SahneRidgePainter.ridgePath(Offset.zero & size),
        Paint()..color = SahneVayColors.tileRidge.withValues(alpha: 0.08),
      );
      canvas.restore();
    }
    final near = Rect.fromLTWH(
      0,
      size.height * 0.35,
      size.width,
      size.height * 0.65,
    );
    canvas.drawPath(
      SahneRidgePainter.ridgePath(near, floor: 1),
      Paint()..color = SahneVayColors.tileRidge,
    );
  }

  @override
  bool shouldRepaint(_TileRidgePainter old) => old.layers != layers;
}

/// Kabartmalı cam ikon diski (VAY B2: 68 px): beyaz %30 → %8 degrade, ince
/// beyaz kenar; doygun yüzeyin üstünde durur.
class SahneIconDisc extends StatelessWidget {
  const SahneIconDisc({
    super.key,
    required this.icon,
    required this.color,
    this.size = 68,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        key: const ValueKey('sahne-icon-disc'),
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              SahneVayColors.white.withValues(alpha: 0.30),
              SahneVayColors.white.withValues(alpha: 0.08),
            ],
          ),
          shape: CircleBorder(
            side: BorderSide(
              color: SahneVayColors.white.withValues(alpha: 0.30),
            ),
          ),
          shadows: [
            BoxShadow(
              color: SahneVayColors.black.withValues(alpha: 0.16),
              offset: const Offset(0, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: size * 0.46, color: color),
        ),
      ),
    );
  }
}

/// "VS" rozeti (VAY B3): 44 px madalya altını disk, koyu yazı.
class SahneVsBadge extends StatelessWidget {
  const SahneVsBadge({super.key, this.size = 44, this.lit = true});

  final double size;

  /// `false` → rakip aranırken sönük (cam) rozet.
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        key: const ValueKey('sahne-vs-badge'),
        decoration: ShapeDecoration(
          gradient: lit
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [SahneMedal.goldTop, SahneMedal.goldBottom],
                )
              : null,
          color: lit ? null : SahneVayColors.white.withValues(alpha: 0.14),
          shape: CircleBorder(
            side: BorderSide(
              color: lit
                  ? SahneMedal.rim
                  : SahneVayColors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: MediaQuery.withNoTextScaling(
              child: Text(
                'VS',
                style: SahneType.button.copyWith(
                  color: lit ? SahneVayColors.vsInk : SahneVayColors.white,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Altın ışın diski (madalya ve çark ödül patlaması). Dekoratif.
class SahneRayDisc extends StatelessWidget {
  const SahneRayDisc({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _RayDiscPainter()),
      ),
    );
  }
}

/// Oyun seçimi karosu (TRT "Kategorini seç"): konunun DOYGUN rengi, 48 px
/// cam ikon diski, kalın beyaz ad; altta alçak dağ. En az 112 yükseklik.
///
/// [fill] üstünde beyaz yazı ≥ 4,5:1 olmalı (konu dolguları bunu sağlar,
/// `konu_tonu_kontrast_test`). Basınca %3 küçülür; hareketi azaltta değil.
class SahnePickTile extends StatefulWidget {
  const SahnePickTile({
    super.key,
    required this.icon,
    required this.title,
    required this.fill,
    this.subtitle,
    this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color fill;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double minHeight = 112;

  @override
  State<SahnePickTile> createState() => _SahnePickTileState();
}

class _SahnePickTileState extends State<SahnePickTile> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final deep = Color.lerp(widget.fill, SahneVayColors.black, 0.22)!;
    final reduced = _reduceMotion(context);
    final enabled = widget.onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label:
          widget.semanticLabel ?? [widget.title, ?widget.subtitle].join('. '),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Listener(
        onPointerDown: enabled ? (_) => _set(true) : null,
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down && !reduced ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: SahneEmbossShell(
            shape: SahneShape.l,
            // Doygun karoda dış gölge YOK (Astra: kalın alt gölge ikinci
            // plaka gibi); derinliği iç ışık + dağ silueti verir.
            shadowColor: SahneVayColors.black.withValues(alpha: 0),
            child: Material(
              type: MaterialType.transparency,
              shape: SahneShape.l,
              clipBehavior: Clip.antiAlias,
              child: Ink(
                key: const ValueKey('sahne-pick-tile'),
                decoration: ShapeDecoration(
                  shape: SahneShape.l,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [widget.fill, deep],
                  ),
                ),
                child: InkWell(
                  customBorder: SahneShape.l,
                  onTap: widget.onTap,
                  child: CustomPaint(
                    painter: SahneEmbossPainter(
                      shape: SahneShape.l,
                      style: SahneEmbossStyle.of(context, saturated: true),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: SahnePickTile.minHeight,
                      ),
                      child: Stack(
                        children: [
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 26,
                            child: SahneTileRidge(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(SahneSpace.x3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SahneIconDisc(
                                  icon: widget.icon,
                                  color: SahneVivid.onFill,
                                  size: 48,
                                ),
                                const SizedBox(height: SahneSpace.x2),
                                Text(
                                  widget.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: SahneType.bodyStrong.copyWith(
                                    color: SahneVivid.onFill,
                                  ),
                                ),
                                if (widget.subtitle != null)
                                  Text(
                                    widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: SahneType.caption.copyWith(
                                      color: SahneVivid.onFillSoft,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eleme şemasının bir oyuncu yuvası.
class SahneBracketEntrant {
  const SahneBracketEntrant({this.label, this.avatar, this.me = false});

  /// Yuvanın yanında kısa ad ("Sen"); `null` → yalnız "?" yuvası.
  final String? label;

  /// Yuvanın içindeki avatar; `null` → "?".
  final Widget? avatar;

  /// Oyuncunun kendisi: yarış tonu halka.
  final bool me;
}

/// Eleme şeması (Astra turnuva önerisi: "4 → 2 → 1 avatarı bağlayan 2 dp
/// çizgilerle eleme ağacı"; Clash/TRT braket deseni).
///
/// Sütunlar soldan sağa turlardır; ilk sütun [entrants], sonrakiler henüz
/// belli olmayan "?" yuvaları, son sütun altın taçlı şampiyon yuvası. Üstte
/// her sütunun adı ([roundLabels], sütun sayısı kadar). Çizgiler 2 px,
/// belirteç renginde; standart kart üstünde durur (ekranın tek doygun bloğu
/// kahraman kalır). Bütün şema TEK bir ekran okuyucu düğümüdür
/// ([semanticLabel]).
class SahneBracket extends StatelessWidget {
  const SahneBracket({
    super.key,
    required this.entrants,
    required this.roundLabels,
    required this.semanticLabel,
  });

  final List<SahneBracketEntrant> entrants;
  final List<String> roundLabels;
  final String semanticLabel;

  static const double rowHeight = 66;
  static const double slot = 40;
  static const double crown = 52;

  int get columns {
    var n = entrants.length;
    var c = 1;
    while (n > 1) {
      n ~/= 2;
      c++;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final cols = columns;
    final height = entrants.length * rowHeight;
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final colW = w / cols;
          // Bir sütundaki j. yuvanın merkezi.
          Offset center(int col, int j) {
            final count = entrants.length >> col;
            return Offset(colW * col + colW / 2, (j + 0.5) * height / count);
          }

          final children = <Widget>[];
          for (var c = 0; c < cols; c++) {
            final count = entrants.length >> c;
            for (var j = 0; j < count; j++) {
              final p = center(c, j);
              final last = c == cols - 1;
              final size = last ? crown : slot;
              final Widget node;
              if (last) {
                node = DecoratedBox(
                  key: const ValueKey('bracket-champion'),
                  decoration: ShapeDecoration(
                    color: t.goldTint,
                    shape: CircleBorder(
                      side: BorderSide(color: t.gold, width: SahneRing.r2),
                    ),
                  ),
                  child: const Center(
                    child: SahneGlyph(SahneGlyphKind.crown, size: 26),
                  ),
                );
              } else {
                final e = c == 0 ? entrants[j] : null;
                node = DecoratedBox(
                  key: ValueKey('bracket-slot-$c-$j'),
                  decoration: ShapeDecoration(
                    color: t.s2,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: e?.me == true ? t.raceTx : t.edge,
                        width: e?.me == true ? SahneRing.r2 : 1,
                      ),
                    ),
                  ),
                  child: Center(
                    child:
                        e?.avatar ??
                        MediaQuery.withNoTextScaling(
                          child: Text(
                            '?',
                            style: SahneType.bodyStrong.copyWith(color: t.tx3),
                          ),
                        ),
                  ),
                );
              }
              children.add(
                Positioned(
                  left: p.dx - size / 2,
                  top: p.dy - size / 2,
                  width: size,
                  height: size,
                  child: node,
                ),
              );
              final label = c == 0 ? entrants[j].label : null;
              if (label != null) {
                children.add(
                  Positioned(
                    left: colW * c,
                    width: colW,
                    top: p.dy + size / 2 + 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaler: TextScaler.noScaling,
                      style: SahneType.caption.copyWith(
                        color: entrants[j].me ? t.raceTx : t.tx2,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                );
              }
            }
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  for (var c = 0; c < cols; c++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          c < roundLabels.length ? roundLabels[c] : '',
                          key: ValueKey('bracket-round-$c'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: SahneType.captionStrong.copyWith(
                            color: c == cols - 1 ? t.goldTx : t.tx2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SahneSpace.x2),
              SizedBox(
                height: height + 14,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey('bracket-lines'),
                        painter: _BracketLinePainter(
                          entrants: entrants.length,
                          columns: cols,
                          rowHeight: rowHeight,
                          color: t.tx3.withValues(alpha: 0.7),
                          slot: slot,
                          crown: crown,
                        ),
                      ),
                    ),
                    ...children,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BracketLinePainter extends CustomPainter {
  const _BracketLinePainter({
    required this.entrants,
    required this.columns,
    required this.rowHeight,
    required this.color,
    required this.slot,
    required this.crown,
  });

  final int entrants;
  final int columns;
  final double rowHeight;
  final Color color;
  final double slot;
  final double crown;

  @override
  void paint(Canvas canvas, Size size) {
    final colW = size.width / columns;
    final height = entrants * rowHeight;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    Offset center(int col, int j) {
      final count = entrants >> col;
      return Offset(colW * col + colW / 2, (j + 0.5) * height / count);
    }

    for (var c = 0; c < columns - 1; c++) {
      final count = entrants >> c;
      final nextIsLast = c + 1 == columns - 1;
      for (var j = 0; j < count; j += 2) {
        final a = center(c, j);
        final b = center(c, j + 1);
        final to = center(c + 1, j ~/ 2);
        final startX = a.dx + slot / 2;
        final midX = (startX + to.dx - (nextIsLast ? crown : slot) / 2) / 2;
        final endX = to.dx - (nextIsLast ? crown : slot) / 2;
        canvas.drawPath(
          Path()
            ..moveTo(startX, a.dy)
            ..lineTo(midX, a.dy)
            ..lineTo(midX, b.dy)
            ..lineTo(startX, b.dy)
            ..moveTo(midX, to.dy)
            ..lineTo(endX, to.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BracketLinePainter old) =>
      old.entrants != entrants || old.columns != columns || old.color != color;
}

/// Oyun sahnesinin CAM kartı: beyaz %8 yüzey + beyaz %12 kenar
/// ([SahneVivid.sheet], [SahneVivid.sheetEdge]). Gece-dağ sahnesinin üstünde
/// nötr gri Perde yerine sahnenin rengini geçiren yüzey (sonuç "Ayrıntılar").
class SahneGlassCard extends StatelessWidget {
  const SahneGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SahneSpace.x4),
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = SahneShape.withSide(
      SahneShape.l,
      SahneVivid.sheetEdge,
      width: 1,
    );
    final card = Material(
      key: const ValueKey('sahne-glass-card'),
      color: SahneVivid.sheet,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (semanticLabel == null && onTap == null) return card;
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: card,
    );
  }
}
