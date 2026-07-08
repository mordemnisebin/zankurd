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

  @override
  void paint(Canvas canvas, Size size) {
    if (!drawPattern) return;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    
    // Kilim geometrisi: Elmas ve zikzak örgü dokusu
    final double stepX = 24.0;
    final double stepY = 24.0;

    for (double x = -stepX; x < size.width + stepX; x += stepX) {
      for (double y = -stepY; y < size.height + stepY; y += stepY) {
        // Elmas baklava motifi
        path.moveTo(x + stepX / 2, y);
        path.lineTo(x + stepX, y + stepY / 2);
        path.lineTo(x + stepX / 2, y + stepY);
        path.lineTo(x, y + stepY / 2);
        path.close();
        
        // İç geometrik zikzak dolgusu (küçük motif detayları)
        path.moveTo(x + stepX * 0.25, y + stepY * 0.5);
        path.lineTo(x + stepX * 0.5, y + stepY * 0.25);
        path.lineTo(x + stepX * 0.75, y + stepY * 0.5);
        path.lineTo(x + stepX * 0.5, y + stepY * 0.75);
        path.close();
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant KilimPatternPainter oldDelegate) {
    return oldDelegate.drawPattern != drawPattern ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity;
  }
}
