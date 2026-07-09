import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../models/daily_mission.dart';
import '../theme/app_theme.dart';

class MissionToast {
  static void show(BuildContext context, DailyMission mission) {
    if (!context.mounted) return;
    final isKu = context.isKu;
    final label = isKu ? mission.labelKu : mission.labelTr;
    final heading = isKu ? 'Erkên pêkhat!' : 'Görev tamamlandı!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '$label — +${mission.coinReward} coin!',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 18,
            ),
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
