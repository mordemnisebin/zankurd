import 'package:flutter/material.dart';

class KilimPatternPainter extends CustomPainter {
  const KilimPatternPainter({
    required this.drawPattern,
    this.color = Colors.white,
    this.opacity = 0.05,
  });

  final bool drawPattern;
  final Color color;
  final double opacity;

  // Pirs hizası (2026-07-20): kilim/elmas kültürel motifi kaldırıldı.
  // Painter no-op'a indirildi — çağrı yerleri (drawPattern/color/opacity)
  // geriye-uyum için korundu ama artık hiçbir şey çizilmez.
  @override
  void paint(Canvas canvas, Size size) {
    // Kültürel motif kaldırıldı: arka plan dokusu çizilmez.
  }

  @override
  bool shouldRepaint(covariant KilimPatternPainter oldDelegate) => false;
}
