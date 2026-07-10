import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_panel.dart';
import 'roj_mascot.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key = const ValueKey('app-empty-state'),
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      iconColor: AppTheme.primaryGradientStart,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      actionIcon: actionIcon,
      // Boş durumlarda Zana düşünceli hâliyle eşlik eder.
      showMascot: true,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key = const ValueKey('app-error-state'),
    this.icon = Icons.error_outline_rounded,
  });

  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      iconColor: AppTheme.wrong,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
    );
  }
}

class _AppStateScaffold extends StatelessWidget {
  const _AppStateScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.showMascot = false,
  });

  /// true ise ikon halkası yerine Zana maskotu (düşünceli) gösterilir;
  /// küçük ikon rozeti köşede kalır (mevcut testler ikonu bulmaya devam eder).
  final bool showMascot;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: AppPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: showMascot ? 104 : 84,
                      height: showMascot ? 104 : 84,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (showMascot) ...[
                            const RojMascot(size: 100, mood: RojMood.thinking),
                            Positioned(
                              right: -4,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceHiColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: iconColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Icon(icon, color: iconColor, size: 16),
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: iconColor.withValues(alpha: 0.24),
                                ),
                              ),
                              child: Icon(icon, color: iconColor, size: 32),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        height: 1.4,
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: onAction,
                        icon: Icon(actionIcon ?? Icons.refresh_rounded),
                        label: Text(actionLabel),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
