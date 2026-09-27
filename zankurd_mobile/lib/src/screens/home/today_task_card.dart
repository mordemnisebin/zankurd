import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kilim_progress_bar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Ana ekranın tek birincil eylemi: "bugün şunu yap".
///
/// 2026-09-18 Design 2.0: günlük görev ana ekranın tek baskın sahnesidir.
/// Derin yeşil hero öğrenme kimliğini taşır; turuncu yalnız ana CTA'da kalır.
/// Böylece ekran kart yığınına dönmeden "bugün ne yapmalıyım?"ı yanıtlar.
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

  /// Bugün verilen DOĞRU cevap sayısı — SORU sayısı değil.
  ///
  /// Kaynağı `HomeScreen._todayAnswered = store.correctAnswersToday`;
  /// [total] da soru adedi değil, günlük "answerCorrect" görevinin
  /// hedefidir. Bu ayrım önemli: günlük hedef dalındaki "kalan" metni
  /// kalan SORU değil kalan DOĞRU CEVAP sayar (2026-09-27 canlı gezinti —
  /// bkz. [K.dailyGoalRemainingCorrect]).
  final int done;
  final int total;
  final bool firstSession;

  /// Soru başına ~25 saniyelik gerçekçi ortalama üzerinden tahmini süre.
  static int _minutesFor(int questions) =>
      ((questions * 25) / 60).ceil().clamp(1, 60);

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final started = done > 0;
    // İlk ders bitince kart hâlâ "Günün dersi" diyordu; oyuncu az önce bir
    // ders bitirmişken aynı adı yeniden görünce "bitirdim, neden yine ders?"
    // diye duruyordu (2026-09-27 canlı gezinti). Gün içinde ilerleme
    // BAŞLADIKTAN sonra ve hedef tamamlanmadan ÖNCE başlık günlük hedefe
    // döner. Günün ilk açılışı (0 doğru) "Günün dersi" kalır: henüz hiçbir
    // şey yapılmamışken "10 doğru cevap daha" demek "daha"yı boşa düşürür.
    // İlk oturum ("Küçük başlangıç") ve tamamlanmış hedef durumuna kasıtlı
    // dokunulmaz.
    final goalInProgress = !firstSession && started && done < total;
    final remaining = total - done;
    const radius = AppRadius.card;

    return Container(
      key: const ValueKey('home-daily-task'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.culturalBrandBg, Color(0xFF063526)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      AppIcons.bullseye,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
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
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$done/$total',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                goalInProgress
                    ? Tr.forKu(K.dailyGoalTitle, isKu)
                    : Tr.forKu(K.gununDersi, isKu),
                style: AppTypography.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                goalInProgress
                    ? Tr.forKu(K.dailyGoalRemainingCorrect, isKu, {
                        'n': '$remaining',
                        'm': '${_minutesFor(remaining)}',
                      })
                    : Tr.forKu(
                        firstSession ? K.firstSessionSub : K.pSoruYaklasikP,
                        isKu,
                        {'p0': '$total', 'p1': '${_minutesFor(total)}'},
                      ),
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              KilimProgressBar(
                value: progress,
                height: 6,
                color: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.18),
                borderColor: Colors.white.withValues(alpha: 0.14),
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
    final enabled = !loading;
    return Semantics(
      key: const ValueKey('home-daily-task-start'),
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: enabled ? AppTheme.brand : AppColors.disabledSurface(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: 48,
            child: Center(
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
      ),
    );
  }
}
