import 'package:flutter/material.dart';

/// ZanKurd marka logosu.
///
/// Pirs hizası: Pirs'in gerçek app icon'undan (decompiled APK,
/// ic_launcher.png) çıkarılan turuncu gradyan + kalın beyaz wordmark
/// deseni — eski yeşil-kırmızı dağ/güneş raster görseli (zankurd.webp)
/// yerine kod-tabanlı, o gradyanın kendisi zaten "kart" işlevi gördüğü
/// için [onCard]/[cardRadius]/[cardPadding] artık kullanılmıyor; API
/// geriye-uyum için korunuyor.
class AppLogo extends StatelessWidget {
  const AppLogo({
    this.width = 160,
    this.onCard = false,
    this.cardRadius = 24,
    this.cardPadding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    super.key,
  });

  final double width;
  final bool onCard;
  final double cardRadius;
  final EdgeInsets cardPadding;

  // Pirs'in gerçek launcher ikonundan örneklenen gradyan durakları.
  static const _gradientStart = Color(0xFFFEA832);
  static const _gradientEnd = Color(0xFFFF7300);

  @override
  Widget build(BuildContext context) {
    final radius = width * 0.22;
    return Container(
      width: width,
      height: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradientStart, _gradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: _gradientEnd.withValues(alpha: 0.35),
            blurRadius: width * 0.15,
            offset: Offset(0, width * 0.05),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.1),
          child: Text(
            'ZanKurd',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: width * 0.19,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
