import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class ErrorDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
    String? dismissLabel,
  }) {
    final finalRetryLabel = retryLabel ?? context.t(K.retry);
    final finalDismissLabel = dismissLabel ?? context.t(K.close);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.borderColor(context)),
        ),
        title: Row(
          children: [
            const Icon(
              AppIcons.triangleExclamation,
              color: AppTheme.wrong,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (onRetry != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              icon: const Icon(AppIcons.arrowsRotate),
              label: Text(finalRetryLabel),
            ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(finalDismissLabel),
          ),
        ],
      ),
    );
  }

  static void showOfflineMode(BuildContext context) {
    show(
      context,
      title: context.t(K.offlineModeTitle),
      message: context.t(K.offlineModeBody),
    );
  }
}
