import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.titleTr,
    required this.titleKu,
    required this.messageTr,
    required this.messageKu,
    this.icon = Icons.inbox_outlined,
    this.actionLabelTr,
    this.actionLabelKu,
    this.onAction,
    this.isKu = false,
    super.key,
  });

  final String titleTr;
  final String titleKu;
  final String messageTr;
  final String messageKu;
  final IconData icon;
  final String? actionLabelTr;
  final String? actionLabelKu;
  final VoidCallback? onAction;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final title = isKu ? titleKu : titleTr;
    final message = isKu ? messageKu : messageTr;
    final actionLabel = isKu ? actionLabelKu : actionLabelTr;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.cardDecoration(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGradientStart.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: AppTheme.primaryGradientStart),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textSubOf(context),
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
