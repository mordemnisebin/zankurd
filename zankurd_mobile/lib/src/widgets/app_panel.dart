import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    super.key,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
