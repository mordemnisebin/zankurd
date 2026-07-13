import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

// shop_items tablosundan dinamik yüklenen ürünlerin ikonu, statik yedek
// listedeki ikonlarla birebir eşleşmeli — aksi halde canlı katalog
// jenerik "çanta" ikonuna düşer (6/10 üründe olduğu gibi, bu bug'dı).
void main() {
  test('statik listedeki tüm ikon adları doğru IconData\'ya eşlenir', () {
    expect(
      shopIconForName('auto_awesome_motion_outlined'),
      Icons.auto_awesome_motion_outlined,
    );
    expect(
      shopIconForName('favorite_border_rounded'),
      Icons.favorite_border_rounded,
    );
    expect(shopIconForName('casino_outlined'), Icons.casino_outlined);
    expect(shopIconForName('palette_outlined'), Icons.palette_outlined);
    expect(shopIconForName('star_rounded'), Icons.star_rounded);
    expect(shopIconForName('auto_awesome_rounded'), Icons.auto_awesome_rounded);
    expect(shopIconForName('text_fields_rounded'), Icons.text_fields_rounded);
    expect(shopIconForName('text_format_rounded'), Icons.text_format_rounded);
    expect(
      shopIconForName('auto_fix_high_rounded'),
      Icons.auto_fix_high_rounded,
    );
    expect(shopIconForName('diamond_rounded'), Icons.diamond_rounded);
  });

  test('bilinmeyen/null ikon adı jenerik çanta ikonuna düşer', () {
    expect(shopIconForName(null), Icons.shopping_bag_outlined);
    expect(shopIconForName('bilinmeyen_ikon'), Icons.shopping_bag_outlined);
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
