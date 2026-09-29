import 'package:flutter/material.dart';

import 'arena_kit.dart';
import 'sahne/sahne.dart';

/// Level ve XP özetini tek yüzeyde toplar.
///
/// Ana sayfada XP ve level HİÇ görünmüyordu; yalnız başlıkta bir alev ve
/// bir altın rozet vardı. Oyuncu ilerlediğini ancak sonuç ekranında, o da
/// tek seferlik olarak görüyordu.
///
/// Coin BİLEREK burada değil: ana sayfanın başlığında zaten kalıcı bir
/// coin rozeti ve mağaza girişi var. İkisini birden çizmek aynı bilgiyi
/// iki kez göstermek olurdu ve özetin coin satırı tek jeton + bir ikonla
/// seyrek kalıyordu (2026-08-04 görsel denetimi). Özet artık yalnız
/// ilerlemeyi anlatır; ekonomi başlıkta durur.
///
/// Kompozisyon bilinçli olarak sakin — hero'yu ve turuncu ana eylemi
/// gölgelememeli.
class ProgressSummary extends StatelessWidget {
  const ProgressSummary({
    required this.level,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.levelLabel,
    super.key,
  });

  final int level;
  final int xpInLevel;

  /// Bu seviyede sonraki seviyeye gereken toplam XP.
  final int xpNeeded;

  /// "Seviye"/"Ast" — sayının yanındaki yerelleştirilmiş etiket.
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    // `xpNeeded` sıfır veya negatifse bölme yapılmaz: model bir sonraki
    // eşiği bilmiyorsa yüzde uydurmak yanlış kesinlik olur.
    final hasTarget = xpNeeded > 0;
    final ratio = hasTarget ? (xpInLevel / xpNeeded).clamp(0.0, 1.0) : 0.0;
    final t = SahneTokens.of(context);

    // XP sayısının etiketin yanına sığması bir genişlik ve metin ölçeği
    // kararıdır, sabit bir yerleşim değil. 2026-09-25: sıfır ilerlemede
    // "amblem + etiket", "tam genişlikte boş çubuk" ve "yalnız sayı" üç
    // ayrı parça hâlinde duruyor, bütünlük bozuk okunuyordu. Sayı etiketin
    // yanına alındığında iki satıra inen şerit tek bir birim gibi okunuyor.
    //
    // Ancak 320px'de %200 yazıda o satır taşıyordu (2026-08-04'te bu yüzden
    // sayı kendi satırına taşınmıştı). O düzeni geri getirmiyoruz: ölçek
    // büyük veya ekran dar olduğunda sayı eski yerine, kendi satırına
    // döner. `progress_summary_test` her iki yolu da kilitler.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final inlineNumbers = textScale < 1.4;

    final numberToken = RewardToken(
      kind: RewardKind.xp,
      value: hasTarget ? '$xpInLevel/$xpNeeded' : '$xpInLevel',
      compact: true,
    );

    // 2026-09-29 Şahnê: seviye 44'lük M karo (Zêr tonu + Zêr metni, tablo
    // rakamı), etiket kalın açıklama, XP şimşek glifli stat çipi, çubuk
    // Zêr ilerleme çubuğu (S pah). Renk rol taşır: ilerleme ödüldür.
    return Padding(
      key: const ValueKey('home-progress-strip'),
      padding: const EdgeInsets.only(top: SahneSpace.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amblem · etiket · XP jetonu tek satırda; ÇUBUK altta tam
          // genişlikte. Üçünü de tek satıra dizmek 320px'de %200 yazıda
          // satırı 260 piksel taşırıyordu — büyük XP sayıları kısaltılamaz,
          // çünkü kısaltılan sayı yanlış bilgi olur (2026-08-04).
          Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.goldTint,
                  shape: SahneShape.m,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$level',
                        maxLines: 1,
                        style: SahneType.bodyStrong.copyWith(
                          color: t.goldTx,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Text(
                  levelLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(color: t.tx2),
                ),
              ),
              if (inlineNumbers) ...[
                const SizedBox(width: SahneSpace.x3),
                numberToken,
              ],
            ],
          ),
          SizedBox(height: inlineNumbers ? SahneSpace.x3 : SahneSpace.x2),
          SahneProgressBar(value: ratio, tone: SahneProgressTone.gold),
          // Hedef bilinmiyorsa yalnız kazanılan XP gösterilir — "12/0"
          // gibi anlamsız bir oran yazılmaz.
          if (!inlineNumbers) ...[
            const SizedBox(height: SahneSpace.x2),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: numberToken,
            ),
          ],
        ],
      ),
    );
  }
}
