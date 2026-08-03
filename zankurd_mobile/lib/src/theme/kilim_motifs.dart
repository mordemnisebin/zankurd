import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Rengîn Editorial Arena'nın kültürel motif dili.
///
/// Kilim bir halı görseli olarak kullanılmaz. Dokumanın DİL BİLGİSİ alınır:
/// tekrar eden üçgen ritmi, basamak, elmas ve kesişen bant. Dördü de düz,
/// dokusuz ve tek renkli çizilir — motif dekor değil, kimlik işaretidir.
///
/// Kullanım sınırı bilinçlidir: hero altı ayraç, kategori amblemi zemini,
/// kutlama ve premium yüzeyleri. Her kartın etrafına motif çizilmez; bir
/// ekranda birden fazla baskın motif kullanılmaz. Aksi hâlde kültürel
/// kimlik dekor yığınına döner ve tam da kaçınılmak istenen "kalabalık ama
/// karaktersiz" görüntü ortaya çıkar.
enum KilimMotif {
  /// Tekrar eden üçgen dizisi — bölüm ayracı.
  triangleRhythm,

  /// Basamak/zigzag — ilerleme ve yükseliş çağrışımı.
  step,

  /// Elmas/romb — amblem ve rozet zemini.
  diamond,

  /// Kesişen bant — kutlama ve premium.
  band,
}

/// Motifleri tek bir boyayıcıda toplar.
///
/// Ayrı ayrı `CustomPainter` sınıfları yerine tek sınıf kullanılır: motifler
/// aynı geometrik aileden gelir ve ortak `opacity`/`color` sözleşmesini
/// paylaşır. Böylece bir ekranda hangi motifin kullanıldığı tek bir enum
/// değeriyle okunur.
class KilimPainter extends CustomPainter {
  const KilimPainter({
    required this.motif,
    required this.color,
    this.opacity = 1.0,
    this.count = 12,
  });

  final KilimMotif motif;
  final Color color;
  final double opacity;

  /// Yatay tekrar sayısı. Motif ekran genişliğine göre ölçeklenir; sabit
  /// piksel adımı dar cihazda motifi kırpıyordu.
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    switch (motif) {
      case KilimMotif.triangleRhythm:
        _triangles(canvas, size, paint);
      case KilimMotif.step:
        _steps(canvas, size, paint);
      case KilimMotif.diamond:
        _diamonds(canvas, size, paint);
      case KilimMotif.band:
        _bands(canvas, size, paint);
    }
  }

  void _triangles(Canvas canvas, Size size, Paint paint) {
    final step = size.width / count;
    for (var i = 0; i < count; i++) {
      final x = i * step;
      canvas.drawPath(
        Path()
          ..moveTo(x, size.height)
          ..lineTo(x + step / 2, 0)
          ..lineTo(x + step, size.height)
          ..close(),
        paint,
      );
    }
  }

  void _steps(Canvas canvas, Size size, Paint paint) {
    final unit = size.width / count;
    final rise = size.height / 3;
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < count; i++) {
      final level = size.height - ((i % 3) + 1) * rise;
      path
        ..lineTo(i * unit, level)
        ..lineTo((i + 1) * unit, level);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _diamonds(Canvas canvas, Size size, Paint paint) {
    final r = math.min(size.width, size.height) / 2;
    final c = Offset(size.width / 2, size.height / 2);

    Path diamond(double d) => Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();

    // İçteki elmas dıştakinden ÇIKARILIR, üstüne çizilmez: iki dolu elmas
    // üst üste tek bir bulanık lekeye dönüşüyordu. `BlendMode.clear` de
    // çözüm değil — `saveLayer` olmadan tuvalin tamamını siler.
    canvas.drawPath(
      Path.combine(PathOperation.difference, diamond(r), diamond(r * 0.58)),
      paint,
    );
  }

  void _bands(Canvas canvas, Size size, Paint paint) {
    final w = size.width / count;
    for (var i = 0; i < count; i += 2) {
      canvas.drawPath(
        Path()
          ..moveTo(i * w, size.height)
          ..lineTo(i * w + w, 0)
          ..lineTo(i * w + w * 2, 0)
          ..lineTo(i * w + w, size.height)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant KilimPainter old) =>
      old.motif != motif ||
      old.color != color ||
      old.opacity != opacity ||
      old.count != count;
}

/// Hero altı bölüm ayracı.
///
/// Yükseklik 10'da sabit: daha kalını dekoratif bir şerit gibi durup içeriği
/// itiyor, daha incesi cihazda görünmüyordu.
class KilimDivider extends StatelessWidget {
  const KilimDivider({required this.colors, this.height = 10, super.key});

  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Row(
        children: [
          for (final color in colors)
            Expanded(
              child: CustomPaint(
                painter: KilimPainter(
                  motif: KilimMotif.triangleRhythm,
                  color: color,
                  count: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kategori amblemi: elmas motifi zemininde kategori ikonu.
///
/// Amblem kimliğin ikon+renk+geometri üçlüsünü tek yerde toplar. Yalnız
/// renk kullanmak renk körlüğü için yetersiz kalıyordu; elmas ve ikon
/// birlikte ikinci ve üçüncü kanalı verir.
class CategoryEmblem extends StatelessWidget {
  const CategoryEmblem({
    required this.icon,
    required this.color,
    this.size = 46,
    this.onColor = Colors.white,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Elmas, ikonun arkasında kimlik zemini olarak durur.
          CustomPaint(
            size: Size.square(size),
            painter: KilimPainter(
              motif: KilimMotif.diamond,
              color: color,
              opacity: 0.30,
            ),
          ),
          Icon(icon, size: size * 0.46, color: onColor),
        ],
      ),
    );
  }
}
