import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/kilim_motifs.dart';
import '../../widgets/kilim_progress_bar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Ana ekranın tek birincil eylemi: "bugün şunu yap".
///
/// 2026-07-24: menü ızgarası değil, tek cevap. 2026-08-26: yüzey düz
/// karttı ve Yarış kahramanının yanında sönük kalıyordu; gradyan + kilim
/// izi + beyaz CTA aynı ağırlığı öğrenme sekmesine taşır.
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
    const radius = 18.0;

    return Container(
      key: const ValueKey('home-daily-task'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandLite, AppTheme.brand],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 34,
                child: CustomPaint(
                  painter: KilimPainter(
                    motif: KilimMotif.step,
                    color: Colors.white,
                    opacity: 0.10,
                    count: 9,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
                              firstSession
                                  ? K.firstSessionBadge
                                  : K.bugununGorevi,
                              isKu,
                            ),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '$done/$total',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    Tr.forKu(K.gununDersi, isKu),
                    style: AppTypography.heading2.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Tr.forKu(
                      firstSession ? K.firstSessionSub : K.pSoruYaklasikP,
                      isKu,
                      {'p0': '$total', 'p1': '$_minutes'},
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  KilimProgressBar(
                    value: progress,
                    height: 8,
                    color: Colors.white,
                    trackColor: Colors.white.withValues(alpha: 0.22),
                    borderColor: Colors.white.withValues(alpha: 0.28),
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
            ),
          ],
        ),
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
    const onWhite = AppTheme.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-daily-task-start'),
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
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
                      valueColor: AlwaysStoppedAnimation<Color>(onWhite),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: onWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(AppIcons.arrowRight, size: 16, color: onWhite),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
