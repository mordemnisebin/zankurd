import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kutlama anlarında sonuç başlığının arkasında açılan kilim dokusu.
///
/// 2026-07-25 görsel denetimi: uygulamanın tek kutlama kanalı konfetiydi.
/// Konfeti her uygulamada aynıdır ve ZanKurd'a ait bir şey söylemez;
/// oysa marka dili zaten kilim motifine dayanıyor (bkz. [KilimProgressBar]).
/// Bu katman aynı baklava dizisini bir kutlama jesti olarak kullanır:
/// desen merkezden dışa doğru "dokunuyormuş" gibi açılır.
///
/// Katman tamamen dekoratiftir — [ExcludeSemantics] ile ekran okuyucudan
/// gizlenir ve dokunuşları geçirir; sonucun kendisi metinle okunur.
///
/// Hareket azaltma tercihi açıksa desen animasyonsuz, sabit ve daha soluk
/// çizilir: kutlama kimliği korunur ama hareket üretilmez.
class KilimReveal extends StatefulWidget {
  const KilimReveal({
    required this.child,
    this.active = true,
    this.reducedMotion = false,
    this.color = Colors.white,
    super.key,
  });

  /// Üstünde desenin açıldığı içerik (genellikle sonuç başlığı).
  final Widget child;

  /// Kutlanacak bir şey var mı? False ise desen hiç çizilmez.
  final bool active;

  /// Erişilebilirlik tercihi: hareket azaltılsın mı?
  final bool reducedMotion;

  /// Desen rengi — renkli hero üzerinde beyaz, açık zeminde marka tonu.
  final Color color;

  @override
  State<KilimReveal> createState() => _KilimRevealState();
}

class _KilimRevealState extends State<KilimReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active && !widget.reducedMotion) {
      _controller.forward();
    } else {
      // Animasyon oynatılmadığında desen tam açık durur; "yarım kalmış"
      // bir dokuma görünmez.
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(KilimReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && !widget.reducedMotion) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        // Desen çocuğun ÜSTÜNE çizilir. Altına konduğunda, sonuç başlığı
        // kendi opak gradyanını taşıdığı için motif tamamen örtülüyordu
        // (2026-07-25 önizlemesinde yakalandı). %18 opaklık + IgnorePointer
        // ile üstte durması hem görünür hem zararsızdır: metni yıkamaz,
        // dokunuşu engellemez.
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  key: const ValueKey('kilim-reveal-motif'),
                  painter: _KilimRevealPainter(
                    progress: Curves.easeOutCubic.transform(_controller.value),
                    color: widget.color,
                    // Hareketsiz kipte desen daha soluk: sabit bir doku
                    // olarak kalır, dikkat çekmeye çalışmaz.
                    maxOpacity: widget.reducedMotion ? 0.04 : 0.055,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Merkezden dışa doğru açılan baklava dizisi.
///
/// Sıralar merkeze olan uzaklığına göre gecikmeli belirir; böylece desen
/// tek parça "yanıp sönmek" yerine dokunuyormuş gibi yayılır.
class _KilimRevealPainter extends CustomPainter {
  const _KilimRevealPainter({
    required this.progress,
    required this.color,
    required this.maxOpacity,
  });

  final double progress;
  final Color color;
  final double maxOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || progress <= 0) return;

    // Birim büyüklüğü sakinlik için kritik: 26pt'de desen damalı bir duvar
    // kağıdına dönüşüp başlığı bastırıyordu (2026-07-25 önizlemesi).
    // Daha büyük ve daha seyrek baklava, kutlamayı bir doku olarak bırakır.
    // Birim, boyanan alanın genişliğine göre ölçeklenir: küçük bir başlık
    // şeridiyle büyük bir tanıtım kartı aynı *yoğunlukta* okunur. Sabit
    // birimde büyük yüzeyler damalı bir zemine dönüşüyordu.
    final unit = (size.width / 7).clamp(38.0, 68.0);
    final centerX = size.width / 2;
    final maxDistance = size.width / 2 + size.height / 2;

    for (var y = -unit; y < size.height + unit; y += unit) {
      // Satırlar dönüşümlü olarak yarım birim kaydırılır — gerçek dokuma
      // dizilimi böyle kilitlenir.
      final rowIndex = (y / unit).round();
      final offsetX = rowIndex.isEven ? 0.0 : unit / 2;

      for (var x = -unit; x < size.width + unit; x += unit) {
        final cx = x + offsetX;
        final distance = (cx - centerX).abs() + (y - size.height / 2).abs();
        // Bu baklava, dalga ona ulaştığında belirir.
        final localProgress =
            ((progress * maxDistance * 1.6) - distance) / (unit * 3);
        if (localProgress <= 0) continue;

        final opacity = (localProgress.clamp(0.0, 1.0)) * maxOpacity;
        final paint = Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;

        final half = unit / 2 * localProgress.clamp(0.0, 1.0);
        final diamond = Path()
          ..moveTo(cx, y - half)
          ..lineTo(cx + half, y)
          ..lineTo(cx, y + half)
          ..lineTo(cx - half, y)
          ..close();
        canvas.drawPath(diamond, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KilimRevealPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.maxOpacity != maxOpacity;
}

/// Kutlama katmanının varsayılan rengi — marka yeşili zeminler için beyaz,
/// açık yüzeyler için marka tonu.
Color kilimRevealColorFor(BuildContext context, {required bool onBrand}) {
  return onBrand ? Colors.white : AppTheme.brand;
}
