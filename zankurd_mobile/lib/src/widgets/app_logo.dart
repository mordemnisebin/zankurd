import 'package:flutter/material.dart';

/// ZanKurd marka logosu (assets/zankurd.webp).
///
/// 2026-07-21: logo artık saydam arka planlı (tool/make_logo_transparent.py)
/// — [onCard] true verilse bile beyaz kutu ARTIK ÇİZİLMİYOR. Eskiden logo
/// opak beyaz zeminliydi ve turuncu gradyan üzerine ayrı, kopuk bir kare
/// gibi duruyordu ("ayrı bir kare, diğer alanlar ayrı bir bölge gibi" —
/// kullanıcı geri bildirimi); saydamlık sayesinde logo artık hangi
/// zeminin üzerine konursa konsun doğrudan içine gömülü görünür.
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

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/zankurd.webp',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}
