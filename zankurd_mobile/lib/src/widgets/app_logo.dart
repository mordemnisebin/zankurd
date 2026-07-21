import 'package:flutter/material.dart';

/// ZanKurd marka logosu.
///
/// 2026-07-21: logo saydam arka planlı (tool/make_logo_transparent.py) —
/// [onCard] true verilse bile beyaz kutu çizilmiyor, hangi zeminin
/// üzerine konursa konsun doğrudan içine gömülü görünür.
///
/// [width] < [_wordmarkThreshold] olduğunda tam logo yerine yalnızca
/// simge (assets/zankurd_icon.webp — Z + güneş + dağ + kitap, "ZANKURD"
/// yazısı olmadan) gösterilir: küçük boyutlarda ("Xweş hatî ZanKurd!"
/// başlığının üstündeki 76-88px kullanım gibi) tam logo + wordmark
/// birlikte okunaksız bir karmaşaya dönüşüyordu (kullanıcı geri
/// bildirimi — "kötü duruyor"). Yanındaki başlık metni zaten marka
/// adını yazılı olarak veriyor, simge tekrar yazmaya gerek bırakmıyor.
/// [onCard]/[cardRadius]/[cardPadding] API geriye-uyum için korunuyor.
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

  static const double _wordmarkThreshold = 150;

  @override
  Widget build(BuildContext context) {
    final asset = width < _wordmarkThreshold
        ? 'assets/zankurd_icon.webp'
        : 'assets/zankurd.webp';
    return Image.asset(
      asset,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
