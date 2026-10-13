import 'package:flutter/widgets.dart';

/// Üçüncü taraf marka glifleri (Google, Apple): Font Awesome Free 7 Brands.
///
/// Yazı tipi `assets/fonts/Font-Awesome-7-Brands-Regular-400.otf` olarak
/// uygulamanın KENDİ varlığıdır; `font_awesome_flutter` paketi kaldırıldı.
/// Paket Solid + Regular + Brands (~718 KB) taşıyordu, uygulama yalnız
/// Brands'ten bu iki glifi kullanıyordu. Kod noktaları paketin
/// `FontAwesomeIcons.google` / `.apple` değerleridir; yazı tipinin `cmap`
/// tablosunda bulundukları `test/brand_font_bundle_test.dart` ile denetlenir.
/// Lisans: `assets/fonts/LICENSE-FontAwesome.txt` (ikonlar CC BY 4.0,
/// yazı tipi SIL OFL 1.1).
class BrandIcons {
  const BrandIcons._();

  /// Font Awesome Brands `google`.
  static const IconData google = IconData(
    0xf1a0,
    fontFamily: 'FontAwesomeBrands',
  );

  /// Font Awesome Brands `apple`.
  static const IconData apple = IconData(
    0xf179,
    fontFamily: 'FontAwesomeBrands',
  );
}

/// Marka glifini çizer. `Icon` değil: Font Awesome glifleri kare değildir ve
/// `Icon` onları kırpar/kaydırır; bu, `FaIcon`un yaptığı gibi glifi
/// `height: 1.0` ile dikey ortalayıp taşırmadan (`TextOverflow.visible`)
/// çizer.
class BrandIcon extends StatelessWidget {
  const BrandIcon(this.icon, {super.key, this.size, this.color});

  final IconData icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final iconColor = color ?? theme.color;
    return ExcludeSemantics(
      child: RichText(
        overflow: TextOverflow.visible,
        textDirection: Directionality.of(context),
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            inherit: false,
            color: iconColor,
            fontSize: size ?? theme.size ?? 24,
            fontFamily: icon.fontFamily,
            height: 1.0,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
    );
  }
}
