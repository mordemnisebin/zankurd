import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Zana'nın ruh hâlleri: ekran bağlamına göre ifade değişir.
enum RojMood {
  /// Gülümseyen varsayılan hâl (onboarding, karşılama).
  happy,

  /// Kutlama: kapalı mutlu gözler + açık gülümseme (rozet, şampiyonluk).
  celebrate,

  /// Düşünceli: boş durumlar için sempatik "hmm" ifadesi.
  thinking,
}

/// Zana — uygulamanın maskotu. Dış varlık/asset kullanmaz: imza motifi olan
/// roj'dan (güneş) türetilmiş, kilim dilinde üçgen ışınlı geometrik bir
/// karakterdir; tamamen CustomPaint ile çizilir.
class RojMascot extends StatelessWidget {
  const RojMascot({
    this.size = 96,
    this.mood = RojMood.happy,
    super.key = const ValueKey('roj-mascot'),
  });

  final double size;
  final RojMood mood;

  /// Işınların dönüşümlü rengi: altın (kimlik/ödül) + indigo (yeni marka
  /// rengiyle bağ) — sakin, ritmik iki renkli şerit. Dört rengin dönüşümü
  /// küçük boyutta gürültü gibi okunduğu için sadeleştirildi.
  static const rayColors = [AppTheme.gold, AppTheme.brandGreen];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _RojMascotPainter(mood: mood),
    );
  }
}

class _RojMascotPainter extends CustomPainter {
  _RojMascotPainter({required this.mood});

  final RojMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final faceR = size.width * 0.30;

    // Kilim dilinde 12 üçgen ışın — altın/indigo dönüşümüyle sakin bir
    // şerit (bkz. RojMascot.rayColors).
    for (var i = 0; i < 12; i++) {
      final rayPaint = Paint()
        ..color = RojMascot.rayColors[i % RojMascot.rayColors.length];
      final angle = i * math.pi / 6;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final base = center + dir * (faceR + size.width * 0.02);
      final tip = center + dir * (faceR + size.width * 0.16);
      final path = Path()
        ..moveTo(
          base.dx + normal.dx * size.width * 0.045,
          base.dy + normal.dy * size.width * 0.045,
        )
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(
          base.dx - normal.dx * size.width * 0.045,
          base.dy - normal.dy * size.width * 0.045,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // Yüz: altın gradyanlı disk + ince beyaz kontur.
    final facePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [const Color(0xFFFFD97A), AppTheme.gold],
      ).createShader(Rect.fromCircle(center: center, radius: faceR));
    canvas.drawCircle(center, faceR, facePaint);
    canvas.drawCircle(
      center,
      faceR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..color = Colors.white.withValues(alpha: 0.8),
    );

    final ink = Paint()
      ..color = const Color(0xFF4A3208)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final eyeY = center.dy - faceR * 0.18;
    final eyeDx = faceR * 0.38;

    // Gözler.
    switch (mood) {
      case RojMood.celebrate:
        // Kapalı mutlu gözler: ^ ^
        for (final sign in [-1, 1]) {
          final ex = center.dx + sign * eyeDx;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(ex, eyeY), radius: faceR * 0.18),
            math.pi,
            math.pi,
            false,
            ink,
          );
        }
      case RojMood.happy:
      case RojMood.thinking:
        final dot = Paint()..color = const Color(0xFF4A3208);
        canvas.drawCircle(Offset(center.dx - eyeDx, eyeY), faceR * 0.09, dot);
        canvas.drawCircle(Offset(center.dx + eyeDx, eyeY), faceR * 0.09, dot);
    }

    // Ağız.
    final mouthY = center.dy + faceR * 0.28;
    switch (mood) {
      case RojMood.celebrate:
        // Açık gülümseme.
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY),
            width: faceR * 0.8,
            height: faceR * 0.6,
          ),
          0,
          math.pi,
          false,
          ink,
        );
      case RojMood.happy:
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(center.dx, mouthY - faceR * 0.08),
            width: faceR * 0.6,
            height: faceR * 0.45,
          ),
          math.pi * 0.15,
          math.pi * 0.7,
          false,
          ink,
        );
      case RojMood.thinking:
        // Hafif yana kaymış düz "hmm" ağzı.
        canvas.drawLine(
          Offset(center.dx - faceR * 0.22, mouthY),
          Offset(center.dx + faceR * 0.10, mouthY - faceR * 0.06),
          ink,
        );
    }

    // Yanaklar: iki küçük sıcak nokta.
    if (mood != RojMood.thinking) {
      final cheek = Paint()
        ..color = const Color(0xFFE07A3F).withValues(alpha: 0.55);
      canvas.drawCircle(
        Offset(center.dx - faceR * 0.58, center.dy + faceR * 0.12),
        faceR * 0.10,
        cheek,
      );
      canvas.drawCircle(
        Offset(center.dx + faceR * 0.58, center.dy + faceR * 0.12),
        faceR * 0.10,
        cheek,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RojMascotPainter oldDelegate) =>
      oldDelegate.mood != mood;
}
