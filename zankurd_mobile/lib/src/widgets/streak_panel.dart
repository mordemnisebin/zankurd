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
    required this.freezeLabel,
    required this.dayLabels,
    this.freezeActionLabel,
    this.nextMilestone,
    this.freezeCost,
    this.onFreeze,
    this.dayUnitLabel = '',
    super.key,
  });

  /// Mevcut seri (gün).
  final int current;

  /// Son yedi günün durumu, en eskiden bugüne.
  final List<StreakDayState> days;

  final StreakFreezeState freezeState;

  /// Freeze durumunun yerelleştirilmiş etiketi.
  final String freezeLabel;

  /// Yedi günün yerelleştirilmiş kısaltmaları.
  final List<String> dayLabels;

  /// Koruma düğmesinin yerelleştirilmiş etiketi; yoksa düğme çizilmez.
  final String? freezeActionLabel;

  /// Bir sonraki kilometre taşı; yoksa gösterilmez.
  final int? nextMilestone;

  /// Dondurmanın coin maliyeti; yalnız gerçekten ücretliyse verilir.
  final int? freezeCost;

  final VoidCallback? onFreeze;

  /// "gün"/"roj" — jetonun birim etiketi.
  final String dayUnitLabel;

  /// Freeze durumunun okunur etiketi ve gün kısaltmaları ÇAĞIRANDAN gelir.
  ///
  /// Panel içine satır içi iki-dilli üçlü ifade yazmak metni bileşene
  /// gömer ve
  /// `l10n_migration_guard`in saydığı satır içi iki-dil kullanımını
  /// artırır. Bileşen sunumsal kalmalı: neyi çizeceğini bilir, hangi dilde
  /// yazacağını bilmez.
  static ArenaStatus _statusFor(StreakFreezeState state) => switch (state) {
    StreakFreezeState.available => ArenaStatus.live,
    StreakFreezeState.notNeeded => ArenaStatus.completed,
    StreakFreezeState.insufficientCoins => ArenaStatus.locked,
    StreakFreezeState.applying => ArenaStatus.loading,
    StreakFreezeState.applied => ArenaStatus.joined,
    // Belirsiz işlem: sunucudan cevap gelmedi. "Uygulandı" DEMEZ.
    StreakFreezeState.uncertain => ArenaStatus.upcoming,
    StreakFreezeState.offline => ArenaStatus.offline,
    StreakFreezeState.unavailable => ArenaStatus.locked,
  };

  @override
  Widget build(BuildContext context) {
    final labels = dayLabels;
    final chipStatus = _statusFor(freezeState);
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
                label: dayUnitLabel,
              ),
              const SizedBox(width: AppSpacing.xs),
              // Esnek olmalı: uzun Kurmancî durum etiketi %200 yazıda
              // satırı 356 piksel taşırıyordu. `Spacer` esnemeyen bir
              // çipin yanında hiçbir şeyi kurtaramaz.
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ArenaStatusChip(
                    status: chipStatus,
                    label: freezeLabel,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Haftalık ritim: her gün renk + şekil/ikon taşır.
          //
          // Yedi işaret 200% yazıda dar telefona sığmıyordu; satır yatay
          // kaydırılabilir. Günleri kırpmak ya da küçültmek ritmi
          // okunmaz hâle getirirdi — asıl bilgi tam da o dizidir.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < days.length && i < labels.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: i == days.length - 1 ? 0 : 10,
                    ),
                    child: _DayMark(
                      state: days[i],
                      label: labels[i],
                      accent: fire,
                    ),
                  ),
              ],
            ),
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
              onFreeze != null &&
              freezeActionLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFreeze,
                icon: const Icon(Icons.ac_unit_rounded, size: 18),
                label: Text(
                  freezeCost == null
                      ? freezeActionLabel!
                      : '${freezeActionLabel!} · $freezeCost',
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
                color: AppTheme.textMutedColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
