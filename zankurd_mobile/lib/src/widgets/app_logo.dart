import 'package:flutter/material.dart';

/// ZanKurd marka logosu (L4 soru balonu).
///
/// 2026-07-21: logo saydam arka planlı — [onCard] true verilse bile beyaz
/// kutu çizilmiyor, hangi zeminin üzerine konursa konsun doğrudan içine
/// gömülü görünür.
///
/// 2026-09-30: logo değişti. Eski logo (kırmızı Z, güneş, dağ, kitap)
/// yapay zekâ üretimi bir resim gibi duruyordu ve küçükte okunmuyordu; yeni
/// işaret turuncu bir konuşma balonu, içinde pahlı Z oyuğu. `assets/`
/// altındaki iki dosya `tool/generate_app_icons.py` ile üretilir.
///
/// [width] < [_wordmarkThreshold] olduğunda tam kilit yerine yalnızca işaret
/// (assets/zankurd_icon.webp) gösterilir; uygulamada logonun yanında
/// başlık metni zaten "ZanKurd" yazar ve yazı Flutter `Text`iyle (net,
/// ölçeklenir, dile uyar) çizilir. Yatay kilit (assets/zankurd.webp:
/// işaret + yazı) yalnız [_wordmarkThreshold] ve üstü genişlikler için;
/// yazısı açık renktir (gece zemini).
///
/// Plaka yok: eski logonun dağları koyu zeminde kaybolduğu için turuncu
/// hero üstüne "logo plakası" konuyordu (2026-07-25, 2026-09-29). Yeni
/// işaret tek renkli ve doygun; gece ve gündüz zeminde kendi başına
/// ayrışır. Plaka logonun etrafında kutu içinde kutu yaratıyordu ve balonun
/// kuyruğunu keserdi, bu yüzden kalktı. [onCard]/[cardRadius]/[cardPadding]
/// API geriye-uyum için korunuyor.
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
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Image.asset(
      asset,
      width: width,
      cacheWidth: (width * devicePixelRatio).round(),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
