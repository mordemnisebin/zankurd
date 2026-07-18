import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';

class ErrorDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    String? retryLabel,
    String? dismissLabel,
  }) {
    final ku = context.isKu;
    final finalRetryLabel =
        retryLabel ?? (ku ? 'Dîsa biceribîne' : 'Tekrar Dene');
    final finalDismissLabel = dismissLabel ?? (ku ? 'Bigire' : 'Kapat');

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
            const Icon(Icons.error_outline, color: AppTheme.wrong, size: 28),
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
              icon: const Icon(Icons.refresh),
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
      title: context.s('Moda Ne li Serhêl', 'Çevrimdışı Mod'),
      message: context.s(
        'Girêdana înternetê tune. Pirs wekî ne li serhêl tên barkirin.',
        'İnternet bağlantısı yok. Soruları çevrimdışı olarak yüklüyorum.',
      ),
    );
  }
}
