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

    return AppPanel(
      glass: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isKu ? 'Erkên Rojane' : 'Günlük Görevler',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!loading)
                Text(
                  '$completedCount/${missions.length}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const SkeletonLoader(count: 3, height: 48, borderRadius: 8)
          else
            ...missions.map((m) => _MissionTile(mission: m, isKu: isKu)),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: mission.completed
                        ? AppTheme.gold
                        : Theme.of(context).colorScheme.onSurface,
                    decoration: mission.completed
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: AppTheme.gold,
                  ),
                ),
              ),
              if (mission.completed)
                Icon(Icons.check_circle_rounded, color: AppTheme.gold, size: 16)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: AppTheme.gold,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '+${mission.coinReward}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: mission.completed ? AppTheme.gold : AppTheme.accent,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${mission.progress.clamp(0, mission.target)} / ${mission.target}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
