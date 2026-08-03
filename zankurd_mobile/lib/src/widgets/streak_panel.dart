import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arena_kit.dart';

/// Bir günün streak açısından durumu.
///
/// Renk tek kanal değildir: her durumun kendi şekli/ikonu da vardır, çünkü
/// "kaçırdım" ile "henüz gelmedi" arasındaki fark yalnız tonla anlatılırsa
/// renk körü oyuncu için kaybolur.
enum StreakDayState { completed, today, missed, upcoming, frozen }

/// Streak-freeze'in o andaki durumu.
///
/// Sekiz ayrı durum var ve altısı "düğme sönük" olarak çiziliyordu; oyuncu
/// coin'i yetmediği için mi, gerek olmadığı için mi, yoksa sunucu
/// ulaşılamadığı için mi kullanamadığını ayırt edemiyordu.
enum StreakFreezeState {
  available,
  notNeeded,
  insufficientCoins,
  applying,
  applied,
  uncertain,
  offline,
  unavailable,
}

/// Streak yüzeyi: seri, haftalık ritim, sonraki milestone ve freeze durumu.
///
/// Önceki hâli tek bir alev ikonu ve bir sayıydı. Sayı "7" diyordu ama
/// oyuncu hangi günleri oynadığını, bugün oynayıp oynamadığını, serinin
/// kırılmak üzere olup olmadığını ve dondurma hakkının ne durumda olduğunu
/// göremiyordu — yani seriyi KORUMAK için gereken hiçbir bilgi ekranda
/// yoktu.
class StreakPanel extends StatelessWidget {
  const StreakPanel({
    required this.current,
    required this.days,
    required this.freezeState,
    this.nextMilestone,
    this.freezeCost,
    this.onFreeze,
    this.isKu = false,
    super.key,
  });

  /// Mevcut seri (gün).
  final int current;

  /// Son yedi günün durumu, en eskiden bugüne.
  final List<StreakDayState> days;

  final StreakFreezeState freezeState;

  /// Bir sonraki kilometre taşı; yoksa gösterilmez.
  final int? nextMilestone;

  /// Dondurmanın coin maliyeti; yalnız gerçekten ücretliyse verilir.
  final int? freezeCost;

  final VoidCallback? onFreeze;
  final bool isKu;

  static const _dayLabelsTr = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
  static const _dayLabelsKu = ['Dş', 'Sş', 'Çş', 'Pş', 'În', 'Şm', 'Yş'];

  (String, ArenaStatus) _freezeChip() => switch (freezeState) {
    StreakFreezeState.available => (
      isKu ? 'Amade' : 'Kullanılabilir',
      ArenaStatus.live,
    ),
    StreakFreezeState.notNeeded => (
      isKu ? 'Ne hewce ye' : 'Gerekmiyor',
      ArenaStatus.completed,
    ),
    StreakFreezeState.insufficientCoins => (
      isKu ? 'Pere têrê nake' : 'Coin yetersiz',
      ArenaStatus.locked,
    ),
    StreakFreezeState.applying => (
      isKu ? 'Tê sepandin…' : 'Uygulanıyor…',
      ArenaStatus.loading,
    ),
    StreakFreezeState.applied => (
      isKu ? 'Hate parastin' : 'Korundu',
      ArenaStatus.joined,
    ),
    // Belirsiz işlem: sunucudan cevap gelmedi. "Uygulandı" DEMEZ — çift
    // çekim korkusuyla tekrar denemek de doğru değil.
    StreakFreezeState.uncertain => (
      isKu ? 'Encam ne diyar e' : 'Sonuç belirsiz',
      ArenaStatus.upcoming,
    ),
    StreakFreezeState.offline => (
      isKu ? 'Negirêdayî' : 'Çevrimdışı',
      ArenaStatus.offline,
    ),
    StreakFreezeState.unavailable => (
      isKu ? 'Nayê bikaranîn' : 'Kullanılamıyor',
      ArenaStatus.locked,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final labels = isKu ? _dayLabelsKu : _dayLabelsTr;
    final (chipLabel, chipStatus) = _freezeChip();
    final fire = RewardKind.streak.color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RewardToken(
                kind: RewardKind.streak,
                value: '$current',
                label: isKu ? 'roj' : 'gün',
              ),
              const Spacer(),
              ArenaStatusChip(status: chipStatus, label: chipLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Haftalık ritim: her gün renk + şekil/ikon taşır.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < days.length && i < labels.length; i++)
                _DayMark(state: days[i], label: labels[i], accent: fire),
            ],
          ),
          if (nextMilestone != null && nextMilestone! > current) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: (current / nextMilestone!).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppTheme.borderColor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(fire),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Hedef sayıyla da yazılır; çubuk tek başına ölçü vermez.
                Text(
                  '$current/${nextMilestone!}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textSubColor(context),
                  ),
                ),
              ],
            ),
          ],
          if (freezeState == StreakFreezeState.available &&
              onFreeze != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFreeze,
                icon: const Icon(Icons.ac_unit_rounded, size: 18),
                label: Text(
                  freezeCost == null
                      ? (isKu ? 'Rêzê biparêze' : 'Seriyi koru')
                      : (isKu
                            ? 'Rêzê biparêze · $freezeCost'
                            : 'Seriyi koru · $freezeCost'),
                ),
              ),
            ),
          ],
          if (freezeState == StreakFreezeState.applying) ...[
            const SizedBox(height: AppSpacing.sm),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayMark extends StatelessWidget {
  const _DayMark({
    required this.state,
    required this.label,
    required this.accent,
  });

  final StreakDayState state;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (state) {
      StreakDayState.completed => (accent, Colors.white, Icons.check_rounded),
      StreakDayState.today => (
        accent.withValues(alpha: 0.18),
        AppColors.readableAccent(context, accent),
        Icons.today_rounded,
      ),
      StreakDayState.missed => (
        AppTheme.borderColor(context),
        AppTheme.textMutedColor(context),
        Icons.close_rounded,
      ),
      StreakDayState.upcoming => (
        Colors.transparent,
        AppTheme.textMutedColor(context),
        Icons.remove_rounded,
      ),
      // Dondurulmuş gün: seri korunmuş ama oynanmamış. Tamamlanmışla aynı
      // görünmemeli, kaçırılmışla da.
      StreakDayState.frozen => (
        const Color(0xFF04697C),
        Colors.white,
        Icons.ac_unit_rounded,
      ),
    };

    return Semantics(
      label: '$label: ${state.name}',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: state == StreakDayState.upcoming
                    ? Border.all(color: AppTheme.borderColor(context))
                    : null,
              ),
              child: Icon(icon, size: 15, color: fg),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
