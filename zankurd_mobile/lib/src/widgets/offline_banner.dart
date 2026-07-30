import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.isOffline, this.onRetry, super.key});

  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = AppColors.onSolid(AppTheme.wrong);
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isOffline
          ? Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.wrong,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.circleXmark,
                        color: foregroundColor,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.t(K.offlineChecking),
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onRetry != null)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onRetry,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.t(K.retry),
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
