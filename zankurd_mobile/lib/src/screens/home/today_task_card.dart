import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Ana ekranın tek birincil eylemi: "bugün şunu yap".
///
/// 2026-07-24 yenilemesi: ana sayfa artık bir menü ızgarası değil, tek bir
/// soruyu yanıtlayan bir ekran — "şimdi ne yapmalıyım?". Bu kart o cevabı
/// verir ve ekrandaki tek gradyanlı CTA'yı taşır; geri kalan her şey sessiz
/// yüzeydir.
class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard({
    required this.isKu,
    required this.loading,
    required this.onStart,
    this.done = 0,
    this.total = 10,
    this.firstSession = false,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onStart;

  /// Bugün çözülen soru sayısı (görev ilerlemesi).
  final int done;
  final int total;
  final bool firstSession;

  /// Soru başına ~25 saniyelik gerçekçi ortalama üzerinden tahmini süre.
  int get _minutes => ((total * 25) / 60).ceil().clamp(1, 60);

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final started = done > 0;
    const accent = AppTheme.brand;

    return Container(
      key: const ValueKey('home-daily-task'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: firstSession
                      ? const ValueKey('home-first-session-badge')
                      : null,
                  child: Text(
                    Tr.forKu(
                      firstSession ? K.firstSessionBadge : K.bugununGorevi,
                      isKu,
                    ),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.readableAccent(context, accent),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              Text(
                '$done/$total',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Tr.forKu(K.gununDersi, isKu),
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            // Süre soru sayısından türetilir; sabit "4 dakika" metni günlük
            // görev hedefi değiştiğinde yalan söylüyordu.
            Tr.forKu(
              firstSession ? K.firstSessionSub : K.pSoruYaklasikP,
              isKu,
              {'p0': '$total', 'p1': '$_minutes'},
            ),
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.borderColor(context),
              valueColor: const AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StartButton(
            label: started
                ? (Tr.forKu(K.devamEt, isKu))
                : (Tr.forKu(K.start, isKu)),
            loading: loading,
            onTap: onStart,
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-daily-task-start'),
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.brandLite, AppTheme.brand],
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        AppIcons.arrowRight,
                        size: 16,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
