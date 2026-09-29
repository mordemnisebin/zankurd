import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// ZanKurd marka logosu.
///
/// 2026-07-21: logo saydam arka planlı (tool/make_logo_transparent.py) —
/// [onCard] true verilse bile beyaz kutu çizilmiyor, hangi zeminin
/// üzerine konursa konsun doğrudan içine gömülü görünür.
///
/// [width] < [_wordmarkThreshold] olduğunda tam logo yerine yalnızca
/// simge (assets/zankurd_icon.webp — Z + güneş + dağ + kitap, "ZANKURD"
/// yazısı olmadan) gösterilir: küçük boyutlarda ("Xweş hatî ZanKurdê!"
/// başlığının üstündeki 76-88px kullanım gibi) tam logo + wordmark
/// birlikte okunaksız bir karmaşaya dönüşüyordu (kullanıcı geri
/// bildirimi — "kötü duruyor"). Yanındaki başlık metni zaten marka
/// adını yazılı olarak veriyor, simge tekrar yazmaya gerek bırakmıyor.
/// [onCard]/[cardRadius]/[cardPadding] API geriye-uyum için korunuyor.
/// 2026-09-29 Şahnê: [onBrandSurface] logo plakası çizer (bkz. build).
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
    // 2026-09-29 Şahnê: doygun zemin üstünde beyaz daire + gölge yerine
    // logo plakası — gecede Kulis, gündüzde Perde + 1 px kenar (marka
    // satırı ve paylaşım kartıyla aynı dil). Bulanık gölge yok.
    final t = SahneTokens.of(context);
    final day = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: day ? t.s1 : t.s2,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      child: Padding(padding: EdgeInsets.all(width * 0.14), child: image),
    );
  }
}
