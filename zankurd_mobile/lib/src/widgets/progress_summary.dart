import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arena_kit.dart';

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
    final levelTone = RewardKind.level.color;
    final xpTone = RewardKind.xp.color;

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

    return Padding(
      key: const ValueKey('home-progress-strip'),
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, 0),
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
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: levelTone.withValues(
                    alpha: AppTheme.isLight(context) ? 0.13 : 0.24,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$level',
                  maxLines: 1,
                  style: AppTypography.subtitle.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.readableAccent(context, levelTone),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  levelLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSubColor(context),
                  ),
                ),
              ),
              if (inlineNumbers) ...[
                const SizedBox(width: AppSpacing.sm),
                numberToken,
              ],
            ],
          ),
          SizedBox(height: inlineNumbers ? AppSpacing.sm : AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: inlineNumbers ? 6 : 8,
              backgroundColor: AppTheme.borderColor(context),
              valueColor: AlwaysStoppedAnimation<Color>(xpTone),
            ),
          ),
          // Hedef bilinmiyorsa yalnız kazanılan XP gösterilir — "12/0"
          // gibi anlamsız bir oran yazılmaz.
          if (!inlineNumbers) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(alignment: Alignment.centerLeft, child: numberToken),
          ],
        ],
      ),
    );
  }
}
