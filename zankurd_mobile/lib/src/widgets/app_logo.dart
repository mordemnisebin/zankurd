import 'package:flutter/material.dart';

/// ZanKurd marka logosu (assets/zankurd.png).
///
/// Logonun arka planı beyaz olduğundan, koyu zeminlerde okunabilmesi için
/// [onCard] true verildiğinde beyaz yuvarlatılmış bir kart içine yerleştirilir.
class AppLogo extends StatelessWidget {
  const AppLogo({this.width = 160, this.onCard = false, super.key});

  final double width;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/zankurd.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
    if (!onCard) return image;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: image,
    );
  }
}
