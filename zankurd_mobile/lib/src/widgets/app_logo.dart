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
    this.onBrandSurface = false,
    super.key,
  });

  final double width;
  final bool onCard;
  final double cardRadius;
  final EdgeInsets cardPadding;

  /// Logo, markanın turuncusu gibi doygun bir zeminin üzerinde mi duruyor?
  ///
  /// Logo turuncu/altın tonlardan oluşur; turuncu hero üzerine konduğunda
  /// zeminle aynı renge düşüp neredeyse kayboluyordu (2026-07-25 canlı
  /// denetimi, isim ekranı). True verildiğinde logonun arkasına yumuşak
  /// açık bir daire konur — marka rengi korunur, kontrast geri gelir.
  final bool onBrandSurface;

  static const double _wordmarkThreshold = 150;

  @override
  Widget build(BuildContext context) {
    final asset = width < _wordmarkThreshold
        ? 'assets/zankurd_icon.webp'
        : 'assets/zankurd.webp';
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final image = Image.asset(
      asset,
      width: width,
      cacheWidth: (width * devicePixelRatio).round(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
    if (!onBrandSurface) return image;
    final pad = width * 0.14;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: image,
    );
  }
}
