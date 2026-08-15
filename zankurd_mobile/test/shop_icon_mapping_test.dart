import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
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
    expect(shopIconForName('favorite_border_rounded'), AppIcons.heart);
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

  // Kısa ya da boş `theme_color` değerinin GÖRÜNMEZ renk üretmediğinin
  // bekçisi.
  //
  // ## Kusur
  //
  // `shopColorForHex` hex'i `int.parse('FF$clean', radix: 16)` ile
  // çözüyordu ve eksik bir değerde bu çağrı hata ATMAZ — sessizce yanlış bir
  // sayı üretir. Boş dize `0xFF` yani `Color(0x000000FF)` verir: alfası
  // sıfır, tamamen saydam. `FFF` de `0x000FFFFF` verir, yine saydam.
  // Dolayısıyla `catch` bloğu bu durumların hiçbirinde çalışmıyordu ve uzak
  // katalogdaki eksik bir renk, vitrinde görünmez bir karo tonuna dönüyordu.
  //
  // Sessizdi çünkü var olan test yalnız `isNotNull` diyordu ve saydam bir
  // renk de null değildir.

  test('eksik hex saydam renk üretmiyor, markaya düşüyor', () {
    for (final broken in const ['', '   ', 'FFF', '12345', 'ZZZZZZ', '#']) {
      final color = shopColorForHex(broken);
      expect(
        color.a,
        1.0,
        reason:
            '«$broken» için üretilen renk saydam; vitrinde karo tonu hiç '
            'görünmez.',
      );
      expect(
        color,
        AppTheme.accent,
        reason: 'Çözülemeyen bir değer marka rengine düşmeli.',
      );
    }
  });

  test('geçerli hex hâlâ birebir çözülüyor', () {
    // Korumanın öteki yarısı: uzunluk denetimi meşru değerleri elemesin.
    expect(shopColorForHex('FF3B81'), const Color(0xFFFF3B81));
    expect(shopColorForHex('#38BDF8'), const Color(0xFF38BDF8));
    expect(shopColorForHex('3da968'), const Color(0xFF3DA968));
  });
}
