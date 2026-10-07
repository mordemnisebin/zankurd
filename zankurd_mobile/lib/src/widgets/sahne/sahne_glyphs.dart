import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// Ödül glifinin türü.
enum SahneGlyphKind {
  /// Jeton: elmas damgalı altın daire.
  coin,

  /// Alev (seri).
  flame,

  /// Şimşek (XP).
  bolt,

  /// Yıldız (puan, sonuç yıldızı).
  star,

  /// Taç (1. sıra).
  crown,
}

/// Dolu ödül glifi — jeton, alev, şimşek, yıldız, taç.
///
/// Maketteki özel glif seti (`build.py` ICONS: flame, zap, star, crown,
/// coin): Lucide'da bunların dolu karşılığı yoktur ve emoji hiçbir yerde
/// kullanılmaz. Dolgu her temada Zêr; kontur gecede Zêr, gündüzde koyu
/// altın (`goldTx`), böylece açık zeminde glif dağılmaz. [filled] `false`
/// ise (kazanılmamış yıldız) glif Ray (`s3`) tonunda çizilir.
///
/// Dekoratiftir: yanındaki metin anlamı taşır, ekran okuyucu glifi okumaz.
class SahneGlyph extends StatelessWidget {
  const SahneGlyph(
    this.kind, {
    super.key,
    this.size = 20,
    this.filled = true,
    this.color,
    this.edgeColor,
  });

  final SahneGlyphKind kind;
  final double size;

  /// `false`: kazanılmamış (boş) glif, Ray tonunda.
  final bool filled;

  /// Dolgu rengini değiştirir (ör. ustalık rozetinde Zêr üstü koyu yıldız).
  final Color? color;

  /// Kontur rengini değiştirir.
  final Color? edgeColor;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final fill = color ?? (filled ? t.gold : t.s3);
    final edge = edgeColor ?? (filled ? t.goldTx : t.s3);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: SahneGlyphPainter(
            kind: kind,
            fill: fill,
            edge: edge,
            deep: t.goldDeep,
          ),
        ),
      ),
    );
  }
}

/// [SahneGlyph]'in ressamı; yollar Lucide'ın 24 ızgarasındadır.
class SahneGlyphPainter extends CustomPainter {
  const SahneGlyphPainter({
    required this.kind,
    required this.fill,
    required this.edge,
    required this.deep,
  });

  final SahneGlyphKind kind;
  final Color fill;
  final Color edge;

  /// Jetonun iç halkası ve damgası.
  final Color deep;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas.save();
    canvas.scale(s);
    final fillPaint = Paint()..color = fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = edge
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (kind) {
      case SahneGlyphKind.coin:
        const c = Offset(12, 12);
        canvas.drawCircle(c, 10, fillPaint);
        canvas.drawCircle(c, 10, edgePaint);
        canvas.drawCircle(
          c,
          6.6,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = deep
            ..strokeWidth = 1.6,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12, 8.4)
            ..lineTo(15.6, 12)
            ..lineTo(12, 15.6)
            ..lineTo(8.4, 12)
            ..close(),
          Paint()..color = deep,
        );
      case SahneGlyphKind.flame:
        final p = Path()
          ..moveTo(8.5, 14.5)
          ..arcToPoint(
            const Offset(11, 12),
            radius: const Radius.circular(2.5),
            clockwise: false,
          )
          ..cubicTo(11, 10.62, 10.5, 10, 10, 9)
          ..cubicTo(8.93, 6.86, 9.78, 4.95, 12, 3)
          ..cubicTo(12.5, 5.5, 14, 7.9, 16, 9.5)
          ..cubicTo(18, 11.1, 19, 13, 19, 15)
          ..arcToPoint(
            const Offset(5, 15),
            radius: const Radius.circular(7),
            largeArc: true,
          )
          ..cubicTo(5, 13.85, 5.43, 12.71, 6, 12)
          ..arcToPoint(
            const Offset(8.5, 14.5),
            radius: const Radius.circular(2.5),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(p, fillPaint);
        canvas.drawPath(p, edgePaint);
      case SahneGlyphKind.bolt:
        final p = Path()
          ..moveTo(13.2, 2)
          ..lineTo(3.6, 13.6)
          ..lineTo(10.8, 13.6)
          ..lineTo(9.9, 22)
          ..lineTo(19.5, 10.4)
          ..lineTo(12.3, 10.4)
          ..close();
        canvas.drawPath(p, fillPaint);
        canvas.drawPath(p, edgePaint);
      case SahneGlyphKind.star:
        final p = Path()
          ..moveTo(12, 2.4)
          ..lineTo(14.95, 8.38)
          ..lineTo(21.55, 9.34)
          ..lineTo(16.77, 13.99)
          ..lineTo(17.9, 20.56)
          ..lineTo(12, 17.46)
          ..lineTo(6.1, 20.56)
          ..lineTo(7.23, 13.99)
          ..lineTo(2.45, 9.34)
          ..lineTo(9.05, 8.38)
          ..close();
        canvas.drawPath(p, fillPaint);
        canvas.drawPath(p, edgePaint);
      case SahneGlyphKind.crown:
        final p = Path()
          ..moveTo(2.6, 7.2)
          ..lineTo(7.4, 11)
          ..lineTo(12, 4)
          ..lineTo(16.6, 11)
          ..lineTo(21.4, 7.2)
          ..lineTo(19.6, 18)
          ..lineTo(4.4, 18)
          ..close();
        canvas.drawPath(p, fillPaint);
        canvas.drawPath(p, edgePaint);
        canvas.drawLine(
          const Offset(4.5, 21),
          const Offset(19.5, 21),
          Paint()
            ..color = fill
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneGlyphPainter old) =>
      old.kind != kind ||
      old.fill != fill ||
      old.edge != edge ||
      old.deep != deep;
}
