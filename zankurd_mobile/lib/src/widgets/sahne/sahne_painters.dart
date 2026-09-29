import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// Şahnê'nin bütün CustomPainter'ları: elmas göstergeler, kilim şeridi,
/// çizimsiz kategori karosu, sahne degradeleri ve ışık huzmesi.
///
/// Kural (spec `flutter.gölge`): hale ve huzme gradyandır; `saveLayer`,
/// `MaskFilter`, bulanıklık yok. Eliptik radyaller tuvali ölçekleyerek
/// çizilir ([paintEllipseGlow]).

/// Kutuya oturan elmas (45° dönmüş kare): tepe → sağ → alt → sol.
///
/// Yol TEPE köşeden başlar ve saat yönünde döner; sayaç ve ders elmasının
/// izi (`PathMetric.extractPath`) bu yüzden tepeden ölçülür.
Path sahneDiamondPath(Rect r) {
  return Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right, r.center.dy)
    ..lineTo(r.center.dx, r.bottom)
    ..lineTo(r.left, r.center.dy)
    ..close();
}

/// Eliptik radyal ışıma: CSS `radial-gradient(rx ry at c, color, şeffaf
/// stop)` karşılığı. Tuval merkezde ölçeklenir, böylece daire elips olur;
/// ayrı bir katman açılmaz.
void paintEllipseGlow(
  Canvas canvas,
  Rect bounds, {
  required Offset center,
  required double radiusX,
  required double radiusY,
  required List<Color> colors,
  List<double>? stops,
}) {
  if (radiusX <= 0 || radiusY <= 0) return;
  canvas.save();
  canvas.clipRect(bounds);
  canvas.translate(center.dx, center.dy);
  canvas.scale(radiusX, radiusY);
  final local = Rect.fromLTRB(
    (bounds.left - center.dx) / radiusX,
    (bounds.top - center.dy) / radiusY,
    (bounds.right - center.dx) / radiusX,
    (bounds.bottom - center.dy) / radiusY,
  );
  final paint = Paint()
    ..shader = RadialGradient(
      colors: colors,
      stops: stops,
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
  canvas.drawRect(local, paint);
  canvas.restore();
}

/// Kilim "göz" şeridi: delikli büyük baklava + küçük baklava, 16 px adım,
/// 8 px yükseklik. Desen ortalanır (maketteki `xMidYMid slice`).
class SahneKilimPainter extends CustomPainter {
  const SahneKilimPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const period = 16.0;
    final scale = size.height / 8;
    final step = period * scale;
    final count = (size.width / step).ceil() + 1;
    final start = (size.width - count * step) / 2;
    final path = Path()..fillType = PathFillType.evenOdd;
    for (var i = 0; i < count; i++) {
      final x = start + i * step;
      void dia(double cx, double cy, double r) {
        path
          ..moveTo(x + cx * scale, (cy - r) * scale)
          ..lineTo(x + (cx + r) * scale, cy * scale)
          ..lineTo(x + cx * scale, (cy + r) * scale)
          ..lineTo(x + (cx - r) * scale, cy * scale)
          ..close();
      }

      dia(4, 4, 4); // büyük baklava
      dia(4, 4, 1.5); // deliği (evenOdd)
      dia(12, 4, 2); // küçük baklava
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneKilimPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Dekoratif kilim şeridi (8 px). Ekran okuyucuya görünmez.
class SahneKilimStrip extends StatelessWidget {
  const SahneKilimStrip({super.key, required this.color, this.height = 8});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: SahneKilimPainter(color)),
      ),
    );
  }
}

/// Elmas göstergenin durumu (dizi hücresi, yol düğümü).
enum SahneDiamondState {
  /// Doğru: dolu Rast elmas + ✓.
  correct,

  /// Yanlış: boş Şaş elmas (ton dolgu + kontur) + ✗.
  wrong,

  /// Sürüyor: sol yarısı Zimrût dolu, Zimrût halka.
  half,

  /// Bekleyen / kilitli: yalnız ince çizgi.
  pending,
}

/// 24'lük elmas hücresi (maketteki `dia()`; 24 ızgarada çizilir).
///
/// Durum şekille ayrışır: doğru DOLU + ✓, yanlış BOŞ + ✗, bekleyen yalnız
/// çizgi, sürüyor yarım. Renk durum ailesinden (Rast / Şaş) gelir, ama
/// renksiz bir ekranda da okunur.
class SahneDiamondPainter extends CustomPainter {
  const SahneDiamondPainter({
    required this.state,
    required this.tokens,
    this.current = false,
    this.fillPending = false,
  });

  final SahneDiamondState state;
  final SahneTokens tokens;

  /// Şimdiki soru: dışta altın halka.
  final bool current;

  /// Yol düğümünde bekleyen elmasın içi zeminle doldurulur (çizgi
  /// arkasından geçmesin).
  final bool fillPending;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.save();
    canvas.translate((size.width - 24 * s) / 2, (size.height - 24 * s) / 2);
    canvas.scale(s);

    const inner = Rect.fromLTRB(4.75, 4.75, 19.25, 19.25);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (current) {
      canvas.drawPath(
        sahneDiamondPath(const Rect.fromLTRB(0.75, 0.75, 23.25, 23.25)),
        stroke(tokens.gold, 1.5)..strokeJoin = StrokeJoin.miter,
      );
    }

    switch (state) {
      case SahneDiamondState.correct:
        canvas.drawPath(
          sahneDiamondPath(const Rect.fromLTRB(4, 4, 20, 20)),
          Paint()..color = tokens.okTx,
        );
        canvas.drawPath(
          Path()
            ..moveTo(9, 12.2)
            ..lineTo(11.1, 14.3)
            ..lineTo(15, 10.2),
          stroke(tokens.onOk, 2),
        );
      case SahneDiamondState.wrong:
        final d = sahneDiamondPath(inner);
        canvas.drawPath(d, Paint()..color = tokens.errTint);
        canvas.drawPath(d, stroke(tokens.errTx, 1.5));
        final x = stroke(tokens.errTx, 1.75);
        canvas.drawLine(
          const Offset(10.25, 10.25),
          const Offset(13.75, 13.75),
          x,
        );
        canvas.drawLine(
          const Offset(13.75, 10.25),
          const Offset(10.25, 13.75),
          x,
        );
      case SahneDiamondState.half:
        final d = sahneDiamondPath(inner);
        if (fillPending) canvas.drawPath(d, Paint()..color = tokens.bg);
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..lineTo(12, 20)
            ..lineTo(4, 12)
            ..close(),
          Paint()..color = tokens.learnTx,
        );
        canvas.drawPath(d, stroke(tokens.learnTx, 1.5));
      case SahneDiamondState.pending:
        final d = sahneDiamondPath(inner);
        if (fillPending) canvas.drawPath(d, Paint()..color = tokens.bg);
        canvas.drawPath(d, stroke(tokens.tx3, 1.5));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneDiamondPainter old) =>
      old.state != state ||
      old.current != current ||
      old.fillPending != fillPending ||
      old.tokens != tokens;
}

/// Elmas iz göstergesi (sayaç ve ders elması ortak ressamı).
///
/// Elmas kutunun 3 px içine oturur; üstüne 4 px iz çizilir. [fraction]
/// kadarı [trail] rengiyle boyanır:
///
/// * [fromTop] `true` (ders elması): iz tepeden başlar, saat yönünde
///   DOLAR.
/// * [fromTop] `false` (sayaç): kalan iz tepeye BİTER; süre aktıkça tepe
///   köşeden saat yönünde TÜKENİR.
///
/// [halo] verilirse (sayaç) kutunun dışına taşan radyal hale çizilir
/// (116 px kare, `closest-side`); bulanıklık yok.
class SahneDiamondTrackPainter extends CustomPainter {
  const SahneDiamondTrackPainter({
    required this.fill,
    required this.track,
    required this.trail,
    required this.fraction,
    required this.fromTop,
    this.halo,
    this.haloSize = 116,
  });

  final Color fill;
  final Color track;
  final Color trail;
  final double fraction;
  final bool fromTop;
  final Color? halo;
  final double haloSize;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final haloColor = halo;
    if (haloColor != null) {
      final r = haloSize / 2;
      final c = box.center;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [haloColor, haloColor.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }
    final diamond = sahneDiamondPath(box.deflate(3));
    canvas.drawPath(diamond, Paint()..color = fill);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.butt;
    canvas.drawPath(diamond, stroke..color = track);

    final f = fraction.clamp(0.0, 1.0);
    if (f <= 0) return;
    stroke.color = trail;
    if (f >= 1) {
      canvas.drawPath(diamond, stroke);
      return;
    }
    final metric = diamond.computeMetrics().first;
    final len = metric.length;
    final part = fromTop
        ? metric.extractPath(0, len * f)
        : metric.extractPath(len * (1 - f), len);
    canvas.drawPath(part, stroke);
  }

  @override
  bool shouldRepaint(SahneDiamondTrackPainter old) =>
      old.fill != fill ||
      old.track != track ||
      old.trail != trail ||
      old.fraction != fraction ||
      old.fromTop != fromTop ||
      old.halo != halo;
}

/// Sahne kartı zemini: gece degradesi (üst → alt) ya da yarış degradesi
/// (155°, race1 → race2 %52 → race3), üstüne sol üst köşeden rol radyali
/// (`radial-gradient(80% 90% at 0 0, rol %20, şeffaf %70)`).
class SahneStagePainter extends CustomPainter {
  const SahneStagePainter({required this.race, required this.glow});

  final bool race;

  /// Rol radyali; yarış sahnesinde yok (`null`).
  final Color? glow;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final base = race
        ? const LinearGradient(
            // CSS 155°: aşağı ve biraz sağa.
            begin: Alignment(-0.47, -1),
            end: Alignment(0.47, 1),
            colors: [
              SahneStageColors.race1,
              SahneStageColors.race2,
              SahneStageColors.race3,
            ],
            stops: [0, 0.52, 1],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SahneStageColors.top, SahneStageColors.bottom],
          );
    canvas.drawRect(box, Paint()..shader = base.createShader(box));
    final g = glow;
    if (g != null) {
      paintEllipseGlow(
        canvas,
        box,
        center: Offset.zero,
        radiusX: size.width * 0.8,
        radiusY: size.height * 0.9,
        colors: [g, g.withValues(alpha: 0)],
        stops: const [0, 0.7],
      );
    }
  }

  @override
  bool shouldRepaint(SahneStagePainter old) =>
      old.race != race || old.glow != glow;
}

/// Çizimsiz kategori karosu (Sinema ve çizimi olmayan her kategori):
/// kobalt radyal zemin + kilim şerit çerçeve + kemer + zemin bandı.
/// 128 ızgarada çizilir, karonun boyuna ölçeklenir. Renkler temadan
/// bağımsızdır (çizimin yerini tutar).
class SahneNoArtPainter extends CustomPainter {
  const SahneNoArtPainter({required this.gold, required this.dot});

  /// Şerit baklavaları ve kemer noktaları (Zêr).
  final Color gold;

  /// Şerit içi küçük baklavalar (Boyax).
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final s = size.shortestSide / 128;
    // Zemin: radial-gradient(70% 60% at 50% 46%, art1, art2 %55, art3).
    canvas.drawRect(box, Paint()..color = SahneStageColors.art3);
    paintEllipseGlow(
      canvas,
      box,
      center: Offset(size.width * 0.5, size.height * 0.46),
      radiusX: size.width * 0.7,
      radiusY: size.height * 0.6,
      colors: const [
        SahneStageColors.art1,
        SahneStageColors.art2,
        SahneStageColors.art3,
      ],
      stops: const [0, 0.55, 1],
    );

    canvas.save();
    canvas.scale(s);
    // Çerçeve kenarı.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(const Rect.fromLTWH(0, 0, 128, 128))
        ..addRect(const Rect.fromLTRB(11, 11, 117, 117)),
      Paint()..color = SahneStageColors.art3,
    );
    final band = Path();
    final dots = Path();
    void dia(Path p, double cx, double cy, double r) {
      p
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r, cy)
        ..close();
    }

    for (var i = 0.0; i < 128; i += 11) {
      final c = i + 5.5;
      dia(band, c, 5.5, 4);
      dia(band, c, 122.5, 4);
      dia(band, 5.5, c + 4, 4);
      dia(band, 122.5, c + 4, 4);
      dia(dots, c, 5.5, 1.5);
      dia(dots, c, 122.5, 1.5);
    }
    canvas.drawPath(band, Paint()..color = gold);
    canvas.drawPath(dots, Paint()..color = dot);

    // Kemer dolgusu, ışık dairesi, noktalı kemer çizgisi.
    final arch = Path()
      ..moveTo(26, 110)
      ..lineTo(26, 62)
      ..arcToPoint(const Offset(102, 62), radius: const Radius.circular(38))
      ..lineTo(102, 110);
    canvas.drawPath(
      Path.from(arch)..close(),
      Paint()..color = SahneStageColors.art3.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      const Offset(64, 62),
      34,
      Paint()..color = SahneStageColors.art1.withValues(alpha: 0.75),
    );
    final dotPaint = Paint()..color = gold.withValues(alpha: 0.9);
    for (final metric in arch.computeMetrics()) {
      for (var d = 0.5; d < metric.length; d += 6) {
        final t = metric.getTangentForOffset(d);
        if (t != null) canvas.drawCircle(t.position, 1, dotPaint);
      }
    }
    // Zemin bandı ve üç baklava.
    canvas.drawRect(
      const Rect.fromLTRB(11, 104, 117, 117),
      Paint()..color = SahneStageColors.art3,
    );
    final ground = Path();
    for (final cx in const [40.0, 64.0, 88.0]) {
      dia(ground, cx, 112, 4);
    }
    canvas.drawPath(ground, Paint()..color = gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneNoArtPainter old) =>
      old.gold != gold || old.dot != dot;
}

/// Oyun sahnesinin ışık huzmesi: tepede dar, aşağıda geniş yamuk
/// (`polygon(43% 0, 57% 0, 82% 100%, 18% 100%)`), `beam → şeffaf`
/// doğrusal degrade. `saveLayer` yok.
///
/// [light] verilirse huzme kategorinin ışığını taşır ([SahneCategoryLight];
/// yoğunluk varsayılan huzmeyle aynı, %12). `null` → varsayılan huzme.
class SahneBeamPainter extends CustomPainter {
  const SahneBeamPainter({this.light});

  final Color? light;

  /// Çizilen huzme rengi (tepe).
  Color get color => SahneCategoryLight.beamOf(light);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.43, 0)
      ..lineTo(w * 0.57, 0)
      ..lineTo(w * 0.82, h)
      ..lineTo(w * 0.18, h)
      ..close();
    final beam = color;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [beam, beam.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(SahneBeamPainter oldDelegate) =>
      oldDelegate.light != light;
}

/// Sahne zemininin ufku: logodaki dağlardan türeyen alçak bir dağ sırtı
/// silueti (ortada yüksek tepe, yanlarda alçalan sırtlar).
///
/// Dekoratiftir ve neredeyse fısıltıdır: [color] genelde Perde'nin (`s1`)
/// %40'ı. Kutunun altına oturur, kutuyu yatayda doldurur; yükseklik
/// kutudan gelir (alçak tutulur, bkz. [SahneStageScaffold.ridge]).
/// Degrade, bulanıklık ve `saveLayer` yok — tek dolu yol.
class SahneRidgePainter extends CustomPainter {
  const SahneRidgePainter(this.color);

  final Color color;

  /// Sırt çizgisi, 0–1 ızgarasında (x soldan, y tepeden). Ortadaki tepe
  /// logodaki büyük dağ, sağ ve soldaki kırıklı sırtlar yan tepelerdir.
  static const List<Offset> ridgeLine = [
    Offset(0.00, 0.70),
    Offset(0.05, 0.58),
    Offset(0.09, 0.64),
    Offset(0.15, 0.44),
    Offset(0.19, 0.52),
    Offset(0.24, 0.40),
    Offset(0.30, 0.62),
    Offset(0.36, 0.48),
    Offset(0.40, 0.54),
    Offset(0.46, 0.22),
    Offset(0.50, 0.00),
    Offset(0.53, 0.14),
    Offset(0.56, 0.10),
    Offset(0.61, 0.36),
    Offset(0.66, 0.28),
    Offset(0.71, 0.50),
    Offset(0.76, 0.42),
    Offset(0.82, 0.60),
    Offset(0.87, 0.46),
    Offset(0.92, 0.58),
    Offset(0.96, 0.52),
    Offset(1.00, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = Path()..moveTo(0, size.height);
    for (final p in ridgeLine) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SahneRidgePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Oyun sahnesinin alttan ışıması:
/// `radial-gradient(90% 30% at 50% 108%, underglow, şeffaf %70)`.
class SahneUnderglowPainter extends CustomPainter {
  const SahneUnderglowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    paintEllipseGlow(
      canvas,
      Offset.zero & size,
      center: Offset(size.width / 2, size.height * 1.08),
      radiusX: size.width * 0.9,
      radiusY: math.max(size.height * 0.3, 1),
      colors: [
        SahneStageColors.underglow,
        SahneStageColors.underglow.withValues(alpha: 0),
      ],
      stops: const [0, 0.7],
    );
  }

  @override
  bool shouldRepaint(SahneUnderglowPainter oldDelegate) => false;
}
