import 'package:flutter/material.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? (isDark
                ? const Color(0xFF2A2A3E)
                : const Color(0xFFF0F3FA))
            : (isDark
                ? const Color(0xFF1A1A2E).withValues(alpha: 0.5)
                : const Color(0xFFE8EDF7).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFFFFD700).withValues(alpha: 0.5)
              : (isDark
                  ? const Color(0xFF2A3B5C).withValues(alpha: 0.3)
                  : const Color(0xFFD9E1EF).withValues(alpha: 0.3)),
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rozet ikonu
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFFC700)],
                    )
                  : null,
              color: isUnlocked
                  ? null
                  : (isDark
                      ? const Color(0xFF2A3B5C).withValues(alpha: 0.4)
                      : const Color(0xFFD9E1EF).withValues(alpha: 0.6)),
            ),
            child: Icon(
              _icon,
              color: isUnlocked
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFF909090)
                      : const Color(0xFF656565)),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),

          // Rozet başlığı
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isUnlocked
                  ? (isDark
                      ? const Color(0xFFE8E8E8)
                      : const Color(0xFF1A1A2E))
                  : (isDark
                      ? const Color(0xFF909090)
                      : const Color(0xFF656565)),
            ),
          ),
          const SizedBox(height: 4),

          // Rozet durumu
          if (isUnlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00D68F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isKu ? '✓ Vekirî' : '✓ Kazanıldı',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00D68F),
                ),
              ),
            )
          else
            Icon(
              Icons.lock_outline,
              size: 14,
              color: isDark
                  ? const Color(0xFF909090)
                  : const Color(0xFF656565),
            ),
        ],
      ),
    );
  }
}
