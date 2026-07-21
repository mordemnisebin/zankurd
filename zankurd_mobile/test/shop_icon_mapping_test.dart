import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

// shop_items tablosundan dinamik yüklenen ürünlerin ikonu, statik yedek
// listedeki ikonlarla birebir eşleşmeli — aksi halde canlı katalog
// jenerik "çanta" ikonuna düşer (6/10 üründe olduğu gibi, bu bug'dı).
void main() {
  test('statik listedeki tüm ikon adları doğru IconData\'ya eşlenir', () {
    expect(
      shopIconForName('auto_awesome_motion_outlined'),
      AppIcons.wandMagicSparkles,
    );
    expect(
      shopIconForName('favorite_border_rounded'),
      AppIcons.heart,
    );
    expect(shopIconForName('casino_outlined'), AppIcons.dice);
    expect(shopIconForName('palette_outlined'), AppIcons.palette);
    expect(shopIconForName('star_rounded'), AppIcons.star);
    expect(shopIconForName('auto_awesome_rounded'), AppIcons.wandMagicSparkles);
    expect(shopIconForName('text_fields_rounded'), AppIcons.font);
    expect(shopIconForName('text_format_rounded'), AppIcons.font);
    expect(
      shopIconForName('auto_fix_high_rounded'),
      AppIcons.wandMagicSparkles,
    );
    expect(shopIconForName('diamond_rounded'), AppIcons.gem);
  });

  test('bilinmeyen/null ikon adı jenerik çanta ikonuna düşer', () {
    expect(shopIconForName(null), AppIcons.bagShopping);
    expect(shopIconForName('bilinmeyen_ikon'), AppIcons.bagShopping);
  });

  test('hex renk doğru ayrıştırılır', () {
    expect(shopColorForHex('FF3B81'), const Color(0xFFFF3B81));
    expect(shopColorForHex('#38BDF8'), const Color(0xFF38BDF8));
  });

  test('geçersiz/null renk varsayılana düşer', () {
    expect(shopColorForHex(null), isNotNull);
    expect(shopColorForHex('gecersiz'), isNotNull);
  });
}
