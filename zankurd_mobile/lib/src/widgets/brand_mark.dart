import 'package:flutter/material.dart';

/// ZanKurd logo işareti: L4 "soru balonu" — konuşma balonu, içinde pahlı Z
/// oyuğu.
///
/// 2026-09-30: eski logo (kırmızı Z, güneş, dağ, kitap) yapay zekâ üretimi
/// bir resim gibi duruyordu ve 24 px'te okunmuyordu. Yeni işaret tek renkli
/// iki çokgendir; bu yüzden resim dosyası yerine yol olarak çizilir: her
/// ölçekte keskin, asset'e bağımlı değil, renk belirteçten gelir. Oyuk
/// gerçekten deliktir (`evenOdd`): Z, altındaki zeminin rengini gösterir.
///
/// Geometri `tool/generate_app_icons.py` ve tasarım klasöründeki
/// `kimlik/logo/uret.py` ile aynı sayılardır (1024 kare, sıkı kesim
/// 112,142 → 912,882). Değişirse üçü birlikte değişir; `brand_mark_test`
/// sayıları dosyadaki geometriyle karşılaştırır.
///
/// [height] işaretin yüksekliğidir (kuyruk dahil); genişlik oranı korur.
/// Dekoratiftir: ekran okuyucuya hiçbir şey söylemez (adı yanındaki yazı
/// verir).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.color, this.height = 24});

  /// Balonun rengi (Agir, `SahneTokens.act`).
  final Color color;
  final double height;

  /// En / boy oranı: 800 / 740.
  static const double aspect = 800 / 740;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: height * aspect,
        height: height,
        child: CustomPaint(painter: BrandMarkPainter(color)),
      ),
    );
  }
}

/// [BrandMark]ın çizicisi. Ayrı sınıftır ki testler yolu okuyabilsin.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter(this.color);

  final Color color;

  /// 1024 karede balon: 8 köşe, sol altta kuyruk.
  static const List<Offset> bubble = [
    Offset(242, 142),
    Offset(782, 142),
    Offset(912, 272),
    Offset(912, 612),
    Offset(782, 742),
    Offset(252, 742),
    Offset(112, 882),
    Offset(112, 272),
  ];

  /// 1024 karede Z oyuğu (iki uç köşesi pahlı).
  static const List<Offset> hole = [
    Offset(374, 319),
    Offset(401, 292),
    Offset(623, 292),
    Offset(650, 319),
    Offset(650, 371),
    Offset(481, 513),
    Offset(650, 513),
    Offset(650, 565),
    Offset(623, 592),
    Offset(401, 592),
    Offset(374, 565),
    Offset(374, 513),
    Offset(543, 371),
    Offset(374, 371),
  ];

  static const Rect box = Rect.fromLTRB(112, 142, 912, 882);

  /// Yolu [size] kutusuna sığdırır (oran korunur, ortalanır).
  static Path pathFor(Size size) {
    final scale = size.width / box.width < size.height / box.height
        ? size.width / box.width
        : size.height / box.height;
    final dx = (size.width - box.width * scale) / 2;
    final dy = (size.height - box.height * scale) / 2;
    Offset map(Offset p) =>
        Offset(dx + (p.dx - box.left) * scale, dy + (p.dy - box.top) * scale);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPolygon(bubble.map(map).toList(), true)
      ..addPolygon(hole.map(map).toList(), true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      pathFor(size),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) => old.color != color;
}
