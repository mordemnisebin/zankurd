import 'package:flutter/material.dart';

import 'branded_loader.dart';
import 'sahne/sahne.dart';

/// Engelleyici yükleme katmanı.
///
/// 2026-09-29 Şahnê: yüzey kartı (Perde, L pah, gündüzde 1 px kenar),
/// bulanık gölge yok; halka [BrandedLoader] (Zêr), mesaj Gövde 700.
class LoadingOverlay {
  static void show(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final t = SahneTokens.of(dialogContext);
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.s1,
                  shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(SahneSpace.x8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BrandedLoader(size: 64, strokeWidth: 4),
                      if (message != null) ...[
                        const SizedBox(height: SahneSpace.x4),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: SahneType.bodyStrong.copyWith(color: t.tx),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
