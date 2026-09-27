import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/daily_mission.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/skeleton_loader.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({
    required this.isKu,
    required this.missions,
    this.loading = false,
    this.compact = true,
    this.onClaimReward,
    super.key,
  });

  final bool isKu;
  final List<DailyMission> missions;
  final bool loading;
  final bool compact;
  final void Function(DailyMission mission)? onClaimReward;

  @override
  Widget build(BuildContext context) {
    final completedCount = missions.where((m) => m.completed).length;
    final totalProgress = missions.isEmpty
        ? 0.0
        : completedCount / missions.length;
    final pending = missions.where((m) => !m.completed || !m.claimed).toList();
    final visible = compact ? pending.take(2).toList() : missions;
    final hiddenDone = compact
        ? missions.where((m) => m.completed && m.claimed).length
        : 0;
    // Compact modda yalnız 2 açık görev çizilir. Başlıktaki sayaç ise tüm
    // görevleri sayar; üçüncü görev listede yokken başlık "0/3" diyor ve
    // eksik satır kayıp gibi görünüyordu (2026-07-25 canlı denetimi).
    // Kırpılan açık görevler artık sayılıp ayrıca belirtilir.
    final hiddenPending = compact ? pending.length - visible.length : 0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              key: const ValueKey('daily-missions-header-icon'),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconTileBg(context, AppTheme.culturalBrandBg),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Icon(
                AppIcons.circleCheck,
                color: AppColors.readableAccent(
                  context,
                  AppTheme.culturalBrandBg,
                ),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Tr.forKu(K.gunlukGorevler, isKu),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (!loading)
                    Text(
                      '$completedCount/${missions.length} ${Tr.forKu(K.tamamlandi, isKu)}',
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (!loading) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              key: const ValueKey('daily-missions-overall-progress'),
              value: totalProgress,
              minHeight: 4,
              backgroundColor: AppTheme.surfaceHiColor(context),
              color: AppTheme.culturalBrandBg,
            ),
          ),
        ],
        if (loading) ...[
          const SizedBox(height: 12),
          const SkeletonLoader(count: 2, height: 44, borderRadius: 8),
        ] else if (visible.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...visible.map(
            (m) => _MissionTile(
              mission: m,
              isKu: isKu,
              compact: compact,
              onClaim: onClaimReward,
            ),
          ),
          if (hiddenDone > 0 || hiddenPending > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (hiddenDone > 0)
                    Tr.forKu(K.pGorevTamam, isKu, {'p0': '$hiddenDone'}),
                  if (hiddenPending > 0)
                    isKu
                        // Kurmancî'de sayı tekilse ad da tekil olur:
                        // "1 erkên din" yanlış, "1 erkê din" doğru.
                        ? (hiddenPending == 1
                              ? '1 erkê din'
                              : '$hiddenPending erkên din')
                        : '$hiddenPending görev daha',
                ].join(' · '),
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ] else if (missions.isNotEmpty) ...[
          const SizedBox(height: 10),
          // Kutlama emojisi ikonla değişti: Rubik emoji taşımıyor, o
          // karakter sistem yazı tipiyle çiziliyor ve cümlenin ortasında
          // başka bir tip beliriyordu (2026-07-26).
          Row(
            children: [
              const Icon(
                AppIcons.circleCheck,
                size: 14,
                color: AppTheme.correct,
              ),
              const SizedBox(width: 6),
              Text(
                Tr.forKu(K.tumGorevlerTamam, isKu),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.correct,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        key: const ValueKey('home-missions-compact-section'),
        padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, 0),
        child: content,
      );
    }
    return AppPanel(padding: const EdgeInsets.all(18), child: content);
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.isKu,
    this.compact = false,
    this.onClaim,
  });

  final DailyMission mission;
  final bool isKu;
  final bool compact;
  final void Function(DailyMission mission)? onClaim;

  /// Görev tipini tek tip bayrak yerine anlamlı bir ikonla gösterir.
  static IconData _missionIcon(MissionType type) {
    return switch (type) {
      MissionType.answerCorrect => AppIcons.bullseye,
      MissionType.completeQuiz => AppIcons.trophy,
      MissionType.useWildcard => AppIcons.wandMagicSparkles,
      MissionType.keepStreak => AppIcons.fire,
      MissionType.playCategory => AppIcons.tableCells,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (mission.progress / mission.target).clamp(0.0, 1.0);
    final label = isKu ? mission.labelKu : mission.labelTr;
    final isDone = mission.completed;

    // Görev karosu; ilerleme ve ödül ayrı metin düğümleriydi. Tek düğümde
    // "görev · ilerleme · durum" olarak duyurulur (2026-07-25 denetimi).
    return Semantics(
      label: label,
      value: isDone
          ? (Tr.forKu(K.tamamlandi, isKu))
          : '${mission.progress}/${mission.target}',
      excludeSemantics: true,
      child: _buildTile(context, ratio, label, isDone),
    );
  }

  Widget _buildTile(
    BuildContext context,
    double ratio,
    String label,
    bool isDone,
  ) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 24 : 28,
              height: compact ? 24 : 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconTileBg(context, AppTheme.culturalBrandBg),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                isDone ? AppIcons.check : _missionIcon(mission.type),
                color: AppColors.readableAccent(
                  context,
                  AppTheme.culturalBrandBg,
                ),
                size: compact ? 12 : 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13.5 : null,
                  color: isDone
                      ? AppTheme.textMutedColor(context)
                      : AppTheme.textPrimaryColor(context),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  decorationColor: isDone
                      ? AppTheme.textMutedColor(context)
                      : null,
                ),
              ),
            ),
            if (!isDone)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '+${mission.xpReward} XP',
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.readableAccent(context, AppTheme.gold),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (!mission.claimed && onClaim != null)
              Material(
                color: AppTheme.gold,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  key: ValueKey('claim-mission-${mission.missionKey}'),
                  onTap: () => onClaim!(mission),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          AppIcons.coins,
                          size: 13,
                          color: Colors.black87,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.t(K.missionClaimAction),
                          style: AppTypography.caption.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.correct.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  context.t(K.missionClaimed),
                  maxLines: 1,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.correct,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(
                height: compact ? 5 : 6,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHiColor(
                    context,
                  ).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: compact ? 5 : 6,
                  decoration: BoxDecoration(
                    color: AppTheme.culturalBrandBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          Text(
            '${mission.progress.clamp(0, mission.target)} / ${mission.target}',
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (compact) {
      return Padding(
        key: ValueKey('home-mission-row-${mission.type.name}'),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: content,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.55),
        ),
      ),
      child: content,
    );
  }
}
