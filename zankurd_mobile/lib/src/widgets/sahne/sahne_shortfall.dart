import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../theme/sahne.dart';
import 'sahne_glyphs.dart';

/// Bir fiyata yetmeyen jeton: `fiyat - bakiye`, hiçbir zaman eksi değil.
///
/// Yetersizlik kararı ve eksik miktar tek yerden gelir; ekranlar
/// `bakiye < fiyat` karşılaştırmasını ve çıkarmayı kendileri yazmaz.
int coinShortfall({required int cost, required int balance}) {
  final missing = cost - balance;
  return missing > 0 ? missing : 0;
}

/// "Jeton yetmiyor" durumunun tek sözü: cüzdan ikonu + "N jeton eksik".
///
/// ## Niçin ortak bileşen
///
/// Jetonla geçilen kapılar (mağaza, oda katılım ücreti, odaya katılma) aynı
/// durumu üç ayrı biçimde söylüyordu: mağaza kartı hiçbir şey demeden
/// dokunmayı kabul edip onay penceresinde pasif bir "Satın al" gösteriyordu,
/// oda sayfası yalnız kırmızı bir "Jetonun yetmiyor" yazıp düğmeyi pasif
/// bırakıyordu, odaya katılma ise sunucunun "Insufficient coins" hatasını
/// "Tekrar dene" diyen genel bir mesaja çeviriyordu. Üçünde de oyuncu NE
/// KADAR eksik olduğunu ve ne yapacağını öğrenmiyordu. Burada durum miktarla
/// söylenir; ne yapılacağı (jeton kazan) yanındaki gerçek bir eylemdir.
///
/// Durum yalnız renkle verilmez: ikon ve söz her zaman vardır.
///
/// * [alert] `false` (varsayılan): ikincil metin (`tx2`). Mağaza ızgarasında
///   sıfır jetonlu yeni oyuncu dört kartta birden kırmızı görmesin; eksik
///   olmak bir hata değil, başlangıç durumudur.
/// * [alert] `true`: Şaş metni (`errTx`). Oyuncunun BAŞLATTIĞI bir eylemin
///   (satın al, oda aç) önünde durduğunda kullanılır.
class SahneShortfallNote extends StatelessWidget {
  const SahneShortfallNote({
    super.key,
    required this.missing,
    this.alert = false,
    this.warn = false,
    this.center = false,
    this.fee,
  });

  /// Verilirse not hangi ücrete ait olduğunu söyler: TR "50 jeton için 40
  /// jeton eksik", KU "Ji bo 50 zêran 40 zêr kêm in". Ücret hazır bir etiket
  /// olarak birleştirilmez; Kurmancîde sözcük sırası farklıdır (önce "Ji bo").
  final int? fee;

  /// Eksik jeton sayısı (> 0).
  final int missing;
  final bool alert;

  /// Uyarı (kehribar, `shortfallTx`): hata değil, "yetmiyor ama çözümü var"
  /// (tur 8: oda ücretinde kırmızı "40 jeton eksik" hata gibi okunuyordu).
  /// [alert]'ten öncelikli.
  final bool warn;

  /// Satırı ortala (diyalog içinde).
  final bool center;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final color = warn ? t.shortfallTx : (alert ? t.errTx : t.tx2);
    final label = fee == null
        ? context.t(K.coinsShort, {'coins': groupThousands(missing)})
        : context.t(K.coinsShortForFee, {
            'fee': groupThousands(fee!),
            'coins': groupThousands(missing),
          });
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            // Cüzdan ikonu bakiye satırının (mağaza penceresinde hemen üstünde)
            // ikonudur; aynı ikon iki satırda tekrarlanmasın diye eksik sözü
            // durum ikonunu taşır.
            child: Icon(
              (alert || warn)
                  ? AppIcons.triangleExclamation
                  : AppIcons.circleInfo,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          Flexible(
            child: Text(
              label,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: SahneType.captionStrong.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alınamayan bir ürünün fiyat çipi: pasif düğme DEĞİL, bir durum.
///
/// Jeton yetmeyen ürün kartında satın alma düğmesi yerine durur. Düğme
/// eskiden etkin görünüp dokunulunca onay penceresi açıyor, pencere de
/// pasif bir "Satın al" gösteriyordu: etkin görünen ama sonuç vermeyen bir
/// eylem. Çip düğme gibi görünmez (Perde zemin, kenar yok, üçüncül glif);
/// altında eksik miktar yazar. Dokunulabilir olan kartın kendisidir ve o,
/// jeton kazanma yolunu açar.
///
/// Fiyat gizlenmez: oyuncu hedefini görür. Ekran okuyucu fiyatı ve eksiği
/// tek cümlede okur ([semanticLabel]).
class SahnePriceChip extends StatelessWidget {
  const SahnePriceChip({
    super.key,
    required this.price,
    required this.missing,
    this.semanticLabel,
  });

  final int price;
  final int missing;
  final String? semanticLabel;

  /// Çipin üst ve alt boşluğu; ızgara hücre yüksekliği bunu da sayar.
  static const double verticalPad = SahneSpace.x2;

  /// Eksik sözü çipte yazılır mı? Bakiye sıfırken eksik fiyatın kendisidir
  /// ("720" altında "720 jeton eksik"): aynı sayıyı ikinci kez yazmak
  /// gürültüdür; çip yine pasif ve fiyatı görünür kalır, ekran okuyucu
  /// eksiği her durumda okur.
  static bool noteShownFor({required int price, required int missing}) =>
      missing < price;

  bool get showsNote => noteShownFor(price: price, missing: missing);

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final note = context.t(K.coinsShort, {'coins': groupThousands(missing)});
    return Semantics(
      container: true,
      label: semanticLabel ?? '${groupThousands(price)}, $note',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: t.s1, shape: SahneShape.m),
        child: ConstrainedBox(
          // a11y-tap-target: noninteractive — durum çipi; dokunulan şey
          // kartın kendisidir.
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: verticalPad,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SahneGlyph(
                      SahneGlyphKind.coin,
                      size: 20,
                      filled: false,
                    ),
                    const SizedBox(width: SahneSpace.x2),
                    Text(
                      groupThousands(price),
                      style: SahneType.button.copyWith(
                        color: t.tx2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (showsNote)
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
