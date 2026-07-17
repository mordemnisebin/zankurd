import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rozet görsel widget'ı — profil ekranında ve sonuç ekranında kullanılır.
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    required this.badgeId,
    required this.titleKu,
    required this.titleTr,
    required this.descriptionKu,
    required this.descriptionTr,
    required this.iconName,
    required this.isUnlocked,
    required this.isKu,
    super.key,
  });

  final String badgeId;
  final String titleKu;
  final String titleTr;
  final String descriptionKu;
  final String descriptionTr;
  final String iconName;
  final bool isUnlocked;
  final bool isKu;

  String get title => isKu ? titleKu : titleTr;
  String get description => isKu ? descriptionKu : descriptionTr;

  IconData get _icon {
    return switch (iconName) {
      'emoji_events' => Icons.emoji_events_outlined,
      'workspace_premium' => Icons.workspace_premium_outlined,
      'military_tech' => Icons.military_tech_outlined,
      'stars' => Icons.stars_outlined,
      'speed' => Icons.speed_outlined,
      _ => Icons.badge_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppTheme.surfaceHiColor(context)
            : AppTheme.surfaceColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? AppTheme.gold.withValues(alpha: 0.5)
              : AppTheme.borderColor(context).withValues(alpha: 0.6),
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rozet ikonu
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked ? AppTheme.goldGradient : null,
              color: isUnlocked ? null : AppTheme.borderColor(context),
            ),
            child: Icon(
              _icon,
              color: isUnlocked
                  ? Colors.white
                  : AppTheme.textMutedColor(context),
              size: 20,
            ),
          ),
          const SizedBox(height: 6),

          // Rozet başlığı
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUnlocked
                  ? AppTheme.textPrimaryColor(context)
                  : AppTheme.textMutedColor(context),
            ),
          ),
          const SizedBox(height: 4),

          // Rozet durumu
          if (isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.correct.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isKu ? '✓ Vekirî' : '✓ Kazanıldı',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.correct,
                ),
              ),
            )
          else
            Icon(
              Icons.lock_outline,
              size: 12,
              color: AppTheme.textMutedColor(context),
            ),
        ],
      ),
    );
  }
}
