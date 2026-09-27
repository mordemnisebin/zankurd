import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    required this.isOffline,
    this.onRetry,
    this.label,
    super.key,
  });

  final bool isOffline;
  final VoidCallback? onRetry;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // 2026-09-25: şerit `AppTheme.wrong` (doygun kırmızı) doluydu ve tam
    // genişlikte ekranın tepesine yapışıyordu. Zayıf ağda kullanıcı bu
    // bandı her ekranda, her saniye görüyor; sonuç "acil" diline dönüşüyor
    // ve premium kimliği bozuyordu. Çevrimdışı olmak bir HATA değil, bir
    // DURUM: bilgi ver, panik yaratma.
    //
    // Yeni dil: sakin yüzey + okunabilir metin + ikon rengiyle ayrım.
    // Eylem rengi (mercan) yalnız "Yeniden dene" düğmesinde kalır, yani
    // AGENTS'teki "mercan yalnız önemli eylemlerde" kuralı da tutuyor.
    final isDark = !AppTheme.isLight(context);
    final background = isDark
        ? AppTheme.wrong.withValues(alpha: 0.16)
        : AppTheme.wrong.withValues(alpha: 0.10);
    final borderColor = AppTheme.wrong.withValues(alpha: isDark ? 0.45 : 0.30);
    final textColor = AppTheme.textPrimaryColor(context);
    // 300 ms boy değişimi süsüdür. Tercih açıkken şerit anında durur;
    // yoksa kabuktaki her çevrimdışı uyarısı ayarı yok saymış olur —
    // birincil CTA (`GeometricGradientButton`) aynı kapıdan geçiyor.
    final animDuration = ReducedMotionProvider.isReducedIn(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return AnimatedSize(
      duration: animDuration,
      curve: Curves.easeInOut,
      child: isOffline
          ? Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(AppIcons.circleXmark, color: borderColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label ?? context.t(K.offlineChecking),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onRetry != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onRetry,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.brand.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.t(K.retry),
                                style: const TextStyle(
                                  color: AppTheme.brand,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
