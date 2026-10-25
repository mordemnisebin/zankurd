import 'package:flutter/material.dart';

import '../data/sync_manager.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Başarısız senkron ödülü varken ana ekranda tek satırlık uyarı. Yoksa
/// hiçbir şey çizmez. Metin ve renkler Profil'deki çiple aynıdır.
class SyncFailedNotice extends StatelessWidget {
  const SyncFailedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: SyncManager.failedCountNotifier,
      builder: (context, failed, _) {
        if (failed == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: SahneSpace.x2),
          child: Material(
            color: t.errTint,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => SyncManager.maybeInstance?.retryFailedItems(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SahneSpace.x3,
                  vertical: SahneSpace.x2,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.triangleExclamation,
                      size: 16,
                      color: t.errTx,
                    ),
                    const SizedBox(width: SahneSpace.x2),
                    Expanded(
                      child: Text(
                        context.t(K.pSenkronizeEdilemedi, {'p0': '$failed'}),
                        style: SahneType.captionStrong.copyWith(color: t.errTx),
                      ),
                    ),
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
