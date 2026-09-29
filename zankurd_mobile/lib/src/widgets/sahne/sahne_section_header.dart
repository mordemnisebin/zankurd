import 'package:flutter/material.dart';

import '../../theme/sahne.dart';
import 'sahne_buttons.dart';
import 'sahne_foundation.dart';

/// Bölüm başlığı — TEK stil (maketteki `.sh-sec`).
///
/// Manşet 22/28 solda; isteğe bağlı sağda metin düğmesi (ör. "Tümü" +
/// chevron, Agir metni, 44 dokunma). Üstü 24, altı 12. Sol çubuk, renkli
/// büyük harf, ikon YOK — başka bölüm başlığı biçimi yazılmaz. Ekran
/// okuyucuya başlık olarak duyurulur.
///
/// Metin düğmesinin dokunma alanı 48'dir ama başlık satırı görsel olarak
/// 28'dir: maketteki `margin: -8px 0` gibi, düğme varken dış boşluk her
/// iki yanda azalır, böylece başlıkla içerik arası yine 24 / 12 görünür.
class SahneSectionHeader extends StatelessWidget {
  const SahneSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.actionSemanticLabel,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Ör. "Konuların tümü" — "Tümü" tek başına belirsizse.
  final String? actionSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final hasAction = actionLabel != null;
    const trim = (sahneTapTarget - 28) / 2;
    return Padding(
      padding: EdgeInsets.only(
        top: SahneSpace.sectionTop - (hasAction ? trim : 0),
        bottom: SahneSpace.sectionBottom - (hasAction ? trim : 0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final heading = Semantics(
            header: true,
            // Uzun tek söz (Kurmancî, %200) dar sütunda harf harf
            // bölünmez.
            child: SahneUnbrokenText(
              title,
              style: SahneType.headline.copyWith(color: t.tx),
            ),
          );
          // Büyük yazı ölçeğinde bağlantı başlığın altına iner; başlık
          // dar sütunda harf harf bölünmez.
          if (hasAction && MediaQuery.textScalerOf(context).scale(16) >= 24) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: trim),
                  child: heading,
                ),
                SahneButton.text(
                  label: actionLabel!,
                  onPressed: onAction,
                  semanticLabel: actionSemanticLabel,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              if (hasAction) ...[
                const SizedBox(width: SahneSpace.x2),
                // Uzun bir bağlantı başlığı ezmesin: en çok genişliğin %45'i.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.45,
                  ),
                  child: SahneButton.text(
                    label: actionLabel!,
                    onPressed: onAction,
                    semanticLabel: actionSemanticLabel,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
