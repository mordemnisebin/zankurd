import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ErrorDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
    String retryLabel = 'Tekrar Dene',
    String dismissLabel = 'Kapat',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
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
              label: Text(retryLabel),
            ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(dismissLabel),
          ),
        ],
      ),
    );
  }

  static void showOfflineMode(BuildContext context) {
    show(
      context,
      title: 'Çevrimdışı Mod',
      message:
          'İnternet bağlantısı yok. Soruları çevrimdışı olarak yüklüyorum.',
    );
  }
}
