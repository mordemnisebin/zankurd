import 'dart:async';
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
    if (size.isEmpty) return;
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
      old.halo != halo ||
      old.haloSize != haloSize;
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
    // 2026-10-19 sadeleşme (ikinci tur): büyük koyu kartlarda degrade
    // yok. Eski doğrusal degrade (yarışta üç duraklı lal, öğrenmede
    // çivit) koyu temada kartı "ışıklı panel" gibi gösteriyor ve ana
    // ekrandaki sakin yüzeylerle çelişiyordu; artık düz dolgu (yarış: orta
    // lal `race2`, öteki: sahne kartı üst tonu). Rol radyali (ince köşe ışığı)
    // aynen kalır.
    canvas.drawRect(
      box,
      Paint()..color = race ? SahneStageColors.race2 : SahneStageColors.top,
    );
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

/// Çizimsiz kategori karosu: kategorinin renk ailesinden düz zemin + ince
/// bir pah yüzeyi (sağ üst köşe).
///
/// 2026-09-29 doğallık (K1): eski ressam her çizimsiz kategoriye aynı kobalt
/// radyali, kilim şerit çerçeveyi, noktalı kemeri ve üç baklavayı
/// çiziyordu — süs yığını, "üretilmiş görsel" izinin kendisi. Artık düz
/// zemin ([SahneCategoryTone.ground]) ve karonun pah diliyle aynı açıda
/// tek bir yüzey ([SahneCategoryTone.detail], %28); degrade, çerçeve ve
/// kilim yok. Bütün kategoriler için kullanılır: ana sayfa ızgarası,
/// liste küçüğü, görseli yüklenemeyen karo. Renkler temadan bağımsızdır
/// (karo kimlik taşır, sahne gibi).
class SahneNoArtPainter extends CustomPainter {
  const SahneNoArtPainter({this.tone = SahneCategoryTone.fallback});

  final SahneCategoryTone tone;

  /// Pah yüzeyinin karonun kısa kenarına oranı.
  static const double facet = 0.34;

  /// Pah yüzeyinin örtücülüğü.
  static const double facetAlpha = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final box = Offset.zero & size;
    canvas.drawRect(box, Paint()..color = tone.ground);
    final f = size.shortestSide * facet;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - f, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, f)
        ..close(),
      Paint()..color = tone.detail.withValues(alpha: facetAlpha),
    );
  }

  @override
  bool shouldRepaint(SahneNoArtPainter old) => old.tone != tone;
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

  /// Sırt silueti [box] içinde: sırt çizgisi kutunun tepesinden, taban
  /// kutunun altından [floor] kadar aşağıda kapanır.
  static Path ridgePath(Rect box, {double floor = 0}) {
    final base = box.bottom + floor;
    final path = Path()..moveTo(box.left, base);
    for (final p in ridgeLine) {
      path.lineTo(box.left + p.dx * box.width, box.top + p.dy * box.height);
    }
    return path
      ..lineTo(box.right, base)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(ridgePath(Offset.zero & size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(SahneRidgePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Günün dersi kartının tepesindeki manzara ("Çiya", 2026-10-20).
///
/// Uygulamanın dağ sırtı ([SahneRidgePainter.ridgeLine], logodaki dağ)
/// büyür ve manzaraya döner: gökyüzü degradesi, üç katman sırt (uzak açık,
/// orta = logo sırtı, yakın koyu taban) ve güneş. Gecede gökte yıldızlar,
/// güneş yerine zirvede TEK turuncu ışık. Renkler belirteçtir
/// ([SahneTokens.vistaSkyTop] …); degrade yalnız gökte, bulanıklık ve
/// `saveLayer` yok. Metin ve düğme manzaranın üstüne binmez: şerit kartın
/// ayrı bir satırıdır.
class SahneVistaPainter extends CustomPainter {
  const SahneVistaPainter(this.palette);

  SahneVistaPainter.of(SahneVistaPhase phase)
    : this(SahneVistaPalette.of(phase));

  final SahneVistaPalette palette;

  /// Uzak sırt (maketteki açık katman), 0–1 ızgarasında.
  static const List<Offset> farLine = [
    Offset(0.00, 0.40),
    Offset(0.08, 0.30),
    Offset(0.14, 0.35),
    Offset(0.22, 0.18),
    Offset(0.27, 0.24),
    Offset(0.33, 0.12),
    Offset(0.40, 0.27),
    Offset(0.48, 0.22),
    Offset(0.55, 0.33),
    Offset(0.63, 0.15),
    Offset(0.70, 0.21),
    Offset(0.76, 0.08),
    Offset(0.83, 0.25),
    Offset(0.90, 0.19),
    Offset(1.00, 0.34),
  ];

  /// Gece yıldızları (sabit, 0–1 ızgarasında; zirvenin çevresi boş).
  static const List<Offset> stars = [
    Offset(0.06, 0.14),
    Offset(0.13, 0.32),
    Offset(0.21, 0.08),
    Offset(0.30, 0.22),
    Offset(0.37, 0.06),
    Offset(0.62, 0.10),
    Offset(0.69, 0.28),
    Offset(0.78, 0.07),
    Offset(0.86, 0.20),
    Offset(0.94, 0.09),
  ];

  static Path _line(List<Offset> line, Rect box) {
    final path = Path()..moveTo(box.left, box.bottom);
    for (final p in line) {
      path.lineTo(box.left + p.dx * box.width, box.top + p.dy * box.height);
    }
    return path
      ..lineTo(box.right, box.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(rect),
    );
    final h = size.height;
    final w = size.width;
    // Orta sırt (logo sırtı) şeridin %25'inden başlar; zirvesi oradadır.
    final midBox = Rect.fromLTWH(0, h * 0.25, w, h * 0.75);
    final peak = Offset(
      midBox.left + 0.50 * midBox.width,
      midBox.top + 0.00 * midBox.height,
    );
    if (palette.stars) {
      final starPaint = Paint()..color = palette.star.withValues(alpha: 0.7);
      for (final p in stars) {
        canvas.drawCircle(Offset(p.dx * w, p.dy * h), 1.1, starPaint);
      }
    } else {
      // Güneş zirvenin sağ arkasında, sırtın ardından doğar.
      final c = Offset(w * palette.sunX, h * palette.sunY);
      final r = h * palette.sunR;
      final sun = palette.sun;
      canvas.drawCircle(
        c,
        r * 1.5,
        Paint()..color = sun.withValues(alpha: 0.22),
      );
      // 21 ışınlı Roj (Kürt güneşi; tasarım oylaması 2026-10-22, 19 modelden
      // 15'i EVET): ince üçgen ışınlar diskin çevresinde. Gece paletinde
      // güneş yoktur (yıldızlar + zirvede tek ışık), ışınlar da yoktur.
      final rays = Path();
      const count = 21;
      for (var i = 0; i < count; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / count;
        const half = math.pi / count * 0.42;
        final inner = r * 1.12;
        final outer = r * 1.62;
        rays
          ..moveTo(
            c.dx + inner * math.cos(a - half),
            c.dy + inner * math.sin(a - half),
          )
          ..lineTo(c.dx + outer * math.cos(a), c.dy + outer * math.sin(a))
          ..lineTo(
            c.dx + inner * math.cos(a + half),
            c.dy + inner * math.sin(a + half),
          )
          ..close();
      }
      canvas.drawPath(rays, Paint()..color = sun.withValues(alpha: 0.85));
      canvas.drawCircle(c, r, Paint()..color = sun);
    }
    canvas.drawPath(
      _line(farLine, Rect.fromLTWH(0, h * 0.40, w, h * 0.60)),
      Paint()..color = palette.ridgeFar,
    );
    canvas.drawPath(
      SahneRidgePainter.ridgePath(midBox),
      Paint()..color = palette.ridgeMid,
    );
    // Yakın taban: alçak, dalgasız koyu şerit.
    canvas.drawPath(
      _line(const [
        Offset(0.00, 0.30),
        Offset(0.20, 0.45),
        Offset(0.42, 0.25),
        Offset(0.66, 0.50),
        Offset(0.86, 0.20),
        Offset(1.00, 0.35),
      ], Rect.fromLTWH(0, h * 0.80, w, h * 0.20)),
      Paint()..color = palette.ridgeNear,
    );
    if (palette.stars) {
      final sun = palette.sun;
      // Zirvede TEK turuncu ışık: küçük hale + nokta.
      canvas.drawCircle(peak, 6, Paint()..color = sun.withValues(alpha: 0.25));
      canvas.drawCircle(peak, 2.5, Paint()..color = sun);
    }
  }

  @override
  bool shouldRepaint(SahneVistaPainter old) => old.palette != palette;
}

/// Manzara şeridi: kartın tepesinde tam genişlik, en çok [maxHeight].
/// Dekoratiftir, ekran okuyucuya görünmez.
class SahneVistaStrip extends StatefulWidget {
  const SahneVistaStrip({super.key, this.height = defaultHeight});

  /// Kurulun tek itirazı manzaranın kartı büyütüp konuları aşağı itmesiydi:
  /// şerit ALÇAKTIR (≤ [maxHeight]); 390×844'te konu ızgarasının ilk satırı
  /// ilk ekranda kalır (bekçi: `manzara_seridi_test.dart`).
  static const double defaultHeight = 88;
  static const double maxHeight = 100;

  final double height;

  @override
  State<SahneVistaStrip> createState() => _SahneVistaStripState();
}

/// Dönemi cihaz saatinden alır ([SahneClock]); açıkken dakikada bir bakar,
/// dönem değişirse (19:59→20:00) yeniden çizer. Tema dönemi etkilemez.
class _SahneVistaStripState extends State<SahneVistaStrip> {
  late SahneVistaPhase _phase = SahneVistaPhase.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final next = SahneVistaPhase.now();
      if (next != _phase && mounted) setState(() => _phase = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('sahne-vista-strip'),
        height: widget.height.clamp(0, SahneVistaStrip.maxHeight),
        width: double.infinity,
        child: CustomPaint(painter: SahneVistaPainter.of(_phase)),
      ),
    );
  }
}

/// Sonuç kahramanının arkası: sonuç ışınları + dağ sırtı ufku (solo ve
/// düello sonucu).
///
/// 2026-09-29 doğallık (K9): ışınlar ([rays]) varsayılan KAPALI. Parıltı
/// yalnız kazanılmış anda: çağıran ekran 3 yıldız / galibiyette açar
/// (`rays: true`). Her sonuçta dönen güneş ışını kutlamayı ucuzlatıyordu.
///
/// Işınlar maketteki `.sh-rays`: `repeating-conic-gradient(ray 0–5°,
/// şeffaf 5–15°)` üstüne `radial-gradient(closest-side, şeffaf %16, bg
/// %74)` örtü. Flutter karşılığı `SweepGradient(tileMode: repeated)` + bg
/// renginde `RadialGradient`; maske, bulanıklık ve `saveLayer` yok (spec
/// `shadows[3]`). 600'lük daireye kırpılır: köşelerdeki bg karesi
/// sahnenin alttan ışımasını örtmesin.
///
/// Dağ sırtı soru sahnesinin ufkuyla AYNI siluettir
/// ([SahneRidgePainter.ridgeLine]; 2026-09-29 birleştirmesine kadar sonuç
/// ekranı kendi 11 noktalı kopyasını çiziyordu). 64 yükseklik, sayfa
/// kenarına taşar, tabanı kahramanın 12 altına iner (ödül kartına ışın
/// sızmaz). Önce zemin rengiyle doldurulur — ışınlar dağların ARKASINDA
/// kalır, ufuk çizgisinde kesilir — üstüne Perde tonu %40.
class SahneResultBackdropPainter extends CustomPainter {
  const SahneResultBackdropPainter({
    this.rays = false,
    required this.raysCenterY,
    required this.bg,
    required this.ridge,
    this.tinted = false,
  });

  final bool rays;
  final double raysCenterY;
  final Color bg;
  final Color ridge;

  /// Renkli sahnede ([SahneStageScaffold.scene]) ışınlar düz zemine değil
  /// gradyana düşer: kenarlarda `bg` rengiyle örtmek yerine ışının KENDİ
  /// opaklığı merkezden dışa söner; dağ sırtı opak bir bant değil %16 siyah
  /// gölgedir (maketteki gibi).
  final bool tinted;

  static const double _raysRadius = 300;
  static const double _rayDegrees = 5;
  static const double _rayPeriodDegrees = 15;

  /// Sırtın yüksekliği.
  static const double ridgeHeight = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (rays && tinted) {
      final center = Offset(size.width / 2, raysCenterY);
      final rect = Rect.fromCircle(center: center, radius: _raysRadius);
      canvas
        ..saveLayer(rect, Paint())
        ..clipPath(Path()..addOval(rect));
      const period = _rayPeriodDegrees * math.pi / 180;
      const on = _rayDegrees / _rayPeriodDegrees;
      // Hafif ışınlar: düşük saydamlıkta sıcak altın.
      const ray = SahneVivid.sceneRay;
      canvas
        ..drawRect(
          rect,
          Paint()
            ..shader = const SweepGradient(
              endAngle: period,
              tileMode: TileMode.repeated,
              colors: [ray, ray, Colors.transparent, Colors.transparent],
              stops: [0, on, on, 1],
            ).createShader(rect),
        )
        ..drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = const RadialGradient(
              colors: [SahneVivid.onFill, Colors.transparent],
              stops: [0.16, 0.74],
            ).createShader(rect),
        )
        ..restore();
    } else if (rays) {
      final center = Offset(size.width / 2, raysCenterY);
      final rect = Rect.fromCircle(center: center, radius: _raysRadius);
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      const period = _rayPeriodDegrees * math.pi / 180;
      const on = _rayDegrees / _rayPeriodDegrees;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const SweepGradient(
            endAngle: period,
            tileMode: TileMode.repeated,
            colors: [
              SahneStageColors.ray,
              SahneStageColors.ray,
              Colors.transparent,
              Colors.transparent,
            ],
            stops: [0, on, on, 1],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [bg.withValues(alpha: 0), bg],
            stops: const [0.16, 0.74],
          ).createShader(rect),
      );
      canvas.restore();
    }

    const bleed = SahneSpace.page;
    final box = Rect.fromLTWH(
      -bleed,
      size.height - ridgeHeight,
      size.width + 2 * bleed,
      ridgeHeight,
    );
    final path = SahneRidgePainter.ridgePath(box, floor: SahneSpace.x3);
    if (tinted) {
      // %16 siyah gölge, dibe doğru söner: kahramanın altında sert bir
      // yatay kenar kalmasın.
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SahneVivid.sceneRidge, Colors.transparent],
          ).createShader(box),
      );
      return;
    }
    canvas.drawPath(path, Paint()..color = bg);
    canvas.drawPath(path, Paint()..color = ridge.withValues(alpha: 0.4));
  }

  @override
  bool shouldRepaint(SahneResultBackdropPainter old) =>
      old.rays != rays ||
      old.raysCenterY != raysCenterY ||
      old.bg != bg ||
      old.tinted != tinted ||
      old.ridge != ridge;
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
