import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sahne/sahne.dart';
import 'zan_mascot.dart';

/// Mağaza vitrini (vay katmanı 2B, B9 — 2026-10-29).
///
/// ## Niçin
///
/// GPT-6 Astra (Trivia Crack / Duolingo mağaza kıyası, 6/10): "Fiyatlar net;
/// ürünlerin değeri ve görünüşü yeterince sergilenmiyor". Rakip mağazalar
/// bir VİTRİNLE açılır: sandık, ışık, karakter. Eskiden ekran düz bir
/// "Günün çarkı" satırıyla başlıyordu.
///
/// ## Düzen
///
/// 132 px manzara (gündüz; koyu temada gece) — solda yıldız kümeli altın
/// sandık (çizim, 64 px), sağda karşılama maskotu "ön tepenin arkasından",
/// altta kilim şeridi. Altına çağıranın verdiği [footer] (günlük çark
/// satırı) aynı kartın parçası olarak oturur. Dekor ekran okuyucuya
/// görünmez.
class ShopShowcase extends StatelessWidget {
  const ShopShowcase({required this.footer, super.key});

  final Widget footer;

  static const double sceneHeight = 132;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final night = t.bg.computeLuminance() < 0.2;
    final phase = night ? SahneVistaPhase.night : SahneVistaPhase.day;
    return SahneSurfaceCard(
      key: const ValueKey('shop-showcase'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(SahneShape.lValue - 1),
              ),
              child: SizedBox(
                height: sceneHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: SahneVistaPainter.of(
                        phase,
                        part: SahneVistaPart.back,
                      ),
                    ),
                    const PositionedDirectional(
                      end: 10,
                      bottom: 6,
                      child: ZanMascot(
                        key: ValueKey('shop-showcase-mascot'),
                        pose: ZanPose.welcome,
                        size: 120,
                      ),
                    ),
                    CustomPaint(
                      painter: SahneVistaPainter.of(
                        phase,
                        part: SahneVistaPart.front,
                      ),
                    ),
                    const PositionedDirectional(
                      start: 20,
                      bottom: 12,
                      child: SizedBox(
                        key: ValueKey('shop-showcase-chest'),
                        width: 112,
                        height: 92,
                        child: CustomPaint(painter: ShopChestPainter()),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SahneKilimBorder(
                        color: SahneKilimBorderPainter.darkOn,
                        height: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          footer,
        ],
      ),
    );
  }
}

/// Açık kapaklı hazine sandığı + üstünde parlayan jeton ve yıldız kümesi.
/// Yalnız yol/elips/dikdörtgen; bulanıklık ve `saveLayer` yok.
class ShopChestPainter extends CustomPainter {
  const ShopChestPainter();

  static const _wood = Color(0xFF9A5323);
  static const _woodDark = Color(0xFF6B3412);
  static const _band = Color(0xFFF2C14E);
  static const _bandDark = Color(0xFFC08A1E);
  static const _coin = Color(0xFFFFD764);
  static const _coinEdge = Color(0xFFB9821A);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Gölge.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.97),
        width: w * 0.8,
        height: h * 0.08,
      ),
      Paint()..color = const Color(0x33000000),
    );
    // Gövde.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.52, w * 0.68, h * 0.42),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(body, Paint()..color = _wood);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.86, w * 0.68, h * 0.08),
      Paint()..color = _woodDark,
    );
    // Açık kapak (arkada, eğik).
    final lid = Path()
      ..moveTo(w * 0.16, h * 0.52)
      ..lineTo(w * 0.22, h * 0.30)
      ..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.78, h * 0.30)
      ..lineTo(w * 0.84, h * 0.52)
      ..close();
    canvas.drawPath(lid, Paint()..color = _woodDark);
    // Taşan jetonlar.
    for (final (dx, dy, r) in const [
      (0.32, 0.50, 0.075),
      (0.45, 0.46, 0.085),
      (0.58, 0.49, 0.08),
      (0.68, 0.53, 0.07),
      (0.40, 0.55, 0.07),
      (0.53, 0.56, 0.075),
    ]) {
      final c = Offset(w * dx, h * dy);
      canvas.drawCircle(c, w * r, Paint()..color = _coinEdge);
      canvas.drawCircle(c, w * r * 0.78, Paint()..color = _coin);
    }
    // Altın kuşaklar.
    final band = Paint()..color = _band;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.60, w * 0.68, h * 0.06),
      band,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.27, h * 0.52, w * 0.06, h * 0.42),
      band,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.67, h * 0.52, w * 0.06, h * 0.42),
      band,
    );
    // Kilit.
    final lock = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.66),
        width: w * 0.12,
        height: h * 0.14,
      ),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(lock, Paint()..color = _bandDark);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.645),
      w * 0.018,
      Paint()..color = _woodDark,
    );
    // Yıldız kümesi.
    _star(canvas, Offset(w * 0.20, h * 0.16), w * 0.07);
    _star(canvas, Offset(w * 0.86, h * 0.10), w * 0.05);
    _star(canvas, Offset(w * 0.60, h * 0.06), w * 0.04);
  }

  void _star(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.38;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFF1B8));
  }

  @override
  bool shouldRepaint(ShopChestPainter oldDelegate) => false;
}

/// Ürün önizlemesinin arkasındaki ışık diski + eliptik gölge (B9): 88 px.
class ShopPreviewStage extends StatelessWidget {
  const ShopPreviewStage({
    required this.child,
    required this.glow,
    this.size = 88,
    super.key,
  });

  final Widget child;
  final Color glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 0,
            child: ExcludeSemantics(
              child: Container(
                width: size * 0.7,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(size, 10)),
                  color: const Color(0x26000000),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: ExcludeSemantics(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: glow.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.42),
                      glow.withValues(alpha: 0.14),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            width: size,
            height: size,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}
