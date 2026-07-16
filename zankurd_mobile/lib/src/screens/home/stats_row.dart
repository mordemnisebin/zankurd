import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({required this.isKu, super.key});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatTile(
          icon: Icons.quiz_outlined,
          value: '2250+',
          label: isKu ? 'Pirs' : 'Soru',
          color: AppTheme.violet,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.layers_outlined,
          value: '30',
          label: isKu ? 'Ast' : 'Seviye',
          color: AppTheme.accent,
        ),
        const SizedBox(width: 10),
        _StatTile(
          icon: Icons.image_outlined,
          value: '72',
          label: isKu ? 'Wêne' : 'Görsel',
          color: AppTheme.gold,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
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
