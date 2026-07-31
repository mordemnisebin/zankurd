import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../config/zankurd_sayings.dart';
import 'roj_mascot.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Günün sözü: (Kurmancî atasözü, Türkçe karşılığı).
typedef _Saying = ZanKurdSaying;

/// Zana'nın "Gotina Rojê" kartı — ana ekranın alt boşluğunu dolduran,
/// maskotlu ve gün bazlı dönen kültürel dokunuş. Aynı gün herkes aynı
/// sözü görür (gün-tohumlu seçim; ağ/durum bağımlılığı yok).
class ZanaDailyCard extends StatelessWidget {
  const ZanaDailyCard({
    required this.isKu,
    this.dayOverride,
    this.onStart,
    this.reviewReadyCount = 0,
    super.key = const ValueKey('zana-daily-card'),
  });

  final bool isKu;

  /// Test için sabit gün indeksi; null ise bugünden türetilir.
  final int? dayOverride;
  final VoidCallback? onStart;

  /// Tekrara hazır (SM-2) soru sayısı. >0 ise günlük hedef, öğrenme yerine
  /// aralıklı tekrarı önceliklendirir; CTA aynı [onStart] akışını tetikler
  /// (Fêr Bibe sekmesindeki "Bugünkü Tekrarlar" kartına yönlenir).
  final int reviewReadyCount;

  ///
  /// M-5: Atasözleri tek doğruluk kaynağı [ZanKurdSayings.pool]'dan gelir;
  /// içerik takımı tek dosyayı (config/zankurd_sayings.dart) güncelleyerek
  /// tüm yerlere yayabilir.
  _Saying get _todaysSaying {
    final day =
        dayOverride ??
        DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays;
    return ZanKurdSayings.pool[day % ZanKurdSayings.pool.length];
  }

  @override
  Widget build(BuildContext context) {
    final saying = _todaysSaying;
    final surface = AppTheme.surfaceHiColor(context);
    final isLight = AppTheme.isLight(context);
    // Günlük hedef modunda hazır tekrar varsa, öğrenme yerine aralıklı
    // tekrarı önceliklendir.
    final hasReview = onStart != null && reviewReadyCount > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        // Yükseklik "Zû bilîze" teaser kartıyla aynı minimuma sabitlenir.
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // Premium/sade: doygun altın gradyan yerine nötr yüzey + sol ince
          // marka yeşili accent çizgisi (accent, Stack içinde ayrı çubuk;
          // borderRadius + tek tip olmayan Border birlikte çizilemez).
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppTheme.borderColor(context)),
          boxShadow: isLight ? AppTheme.cardShadow(context) : null,
        ),
        child: Stack(
          children: [
            // Sol ince yeşil accent çizgisi.
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: ColoredBox(color: AppTheme.brand),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: [
                  const RojMascot(size: 48, mood: RojMood.happy),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              AppIcons.quoteLeft,
                              color: AppTheme.brand,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                hasReview
                                    ? (Tr.forKu(K.todaysReviews, isKu))
                                    : onStart != null
                                    ? (Tr.forKu(K.bugununHedefi, isKu))
                                    : (Tr.forKu(K.gununSozu, isKu)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.brand,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Tek italik stil: yalnızca günün sözü italik.
                        Text(
                          hasReview
                              ? (Tr.forKu(K.pSoruTekraraHazir, isKu, {
                                  'p0': '$reviewReadyCount',
                                }))
                              : onStart != null
                              ? (Tr.forKu(K.dogruCevaplaSeriniKoru, isKu))
                              : saying.$1,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontStyle: hasReview || onStart != null
                                ? FontStyle.normal
                                : FontStyle.italic,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Çeviri / açıklama: 12px gri.
                        Text(
                          hasReview
                              ? (Tr.forKu(K.zanaTekrarlariniHazirladi, isKu))
                              : onStart != null
                              ? (Tr.forKu(K.zanaBugunkuYolunuHazirladi, isKu))
                              : saying.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                        if (onStart != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: onStart,
                            icon: Icon(
                              hasReview
                                  ? AppIcons.arrowsRotate
                                  : AppIcons.arrowRight,
                            ),
                            label: Text(
                              hasReview
                                  ? (Tr.forKu(K.tekraraBasla, isKu))
                                  : (Tr.forKu(K.ogrenmeyeBasla, isKu)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
