import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.textMutedColor(context),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
