import 'package:flutter/material.dart';

import '../../models/daily_mission.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/skeleton_loader.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({
    required this.isKu,
    required this.missions,
    this.loading = false,
    super.key,
  });

  final bool isKu;
  final List<DailyMission> missions;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final completedCount = missions.where((m) => m.completed).length;
    final totalProgress = missions.isEmpty
        ? 0.0
        : completedCount / missions.length;

    return AppPanel(
      glass: true,
      padding: const EdgeInsets.all(18),
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
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKu ? 'Erkên Rojane' : 'Günlük Görevler',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (!loading)
                      Text(
                        '$completedCount/${missions.length} ${isKu ? 'temam' : 'tamamlandı'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (!loading)
                _MiniProgressRing(progress: totalProgress),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const SkeletonLoader(count: 3, height: 48, borderRadius: 8)
          else
            ...missions.map((m) => _MissionTile(mission: m, isKu: isKu)),
        ],
      ),
    );
  }
}

class _MiniProgressRing extends StatelessWidget {
  const _MiniProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final color = progress >= 1.0 ? AppTheme.correct : AppTheme.gold;
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            backgroundColor: AppTheme.borderColor(context).withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.isKu});

  final DailyMission mission;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final ratio = (mission.progress / mission.target).clamp(0.0, 1.0);
    final label = isKu ? mission.labelKu : mission.labelTr;
    final isDone = mission.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.gold.withValues(alpha: 0.08)
            : AppTheme.surfaceColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? AppTheme.gold.withValues(alpha: 0.2)
              : AppTheme.borderColor(context).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppTheme.gold.withValues(alpha: 0.15)
                      : AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.flag_rounded,
                  color: isDone ? AppTheme.gold : AppTheme.accent,
                  size: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? AppTheme.gold
                        : AppTheme.textPrimaryColor(context),
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AppTheme.gold,
                  ),
                ),
              ),
              if (!isDone)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '+${mission.coinReward}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHiColor(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: isDone
                          ? AppTheme.goldGradient
                          : AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: (isDone ? AppTheme.gold : AppTheme.accent)
                              .withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${mission.progress.clamp(0, mission.target)} / ${mission.target}',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
