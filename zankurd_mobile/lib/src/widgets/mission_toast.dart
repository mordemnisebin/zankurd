import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../l10n/lang.dart';
import '../models/daily_mission.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class MissionToast {
  static void show(BuildContext context, DailyMission mission) {
    if (!context.mounted) return;
    final isKu = context.isKu;
    final label = isKu ? mission.labelKu : mission.labelTr;
    final heading = Tr.forKu(K.gorevTamamlandi, isKu);
    final foregroundColor = AppColors.onSolid(AppTheme.gold);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(AppIcons.circleCheck, color: foregroundColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$label — +${mission.xpReward} XP',
                    style: TextStyle(
                      color: foregroundColor.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.bolt, color: foregroundColor, size: 18),
          ],
        ),
        backgroundColor: AppTheme.gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
