import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Bildirim iznini NİÇİN istediğini söyleyen kart; sistem istemi ancak
/// oyuncu "Bildirimleri aç"a basınca gelir.
///
/// İzin eskiden yalnız Ayarlar'da "Günlük hatırlatıcı" açılınca isteniyordu;
/// arkadaş isteği ve sırayla düello bildirimleri izni olmayan oyuncuya hiç
/// ulaşmıyordu. iOS sistem istemini bir kez gösterir: bağlamsız istenirse
/// reddedilir ve bir daha sorulamaz. Kart bu yüzden değeri görüldüğü anda
/// (tur sonucu) ve tek birincil düğmeyi ekranın asıl eylemine bırakarak
/// ikincil düğmeyle sorar.
class NotificationPromptCard extends StatelessWidget {
  const NotificationPromptCard({
    super.key,
    required this.onEnable,
    required this.onLater,
  });

  final VoidCallback onEnable;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(AppIcons.bell, size: 20, color: t.raceTx),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Text(
                  context.t(K.notifPromptTitle),
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.notifPromptBody),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x4),
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SahneButton.secondary(
                buttonKey: const ValueKey('notif-prompt-enable'),
                label: context.t(K.notifPromptEnable),
                icon: AppIcons.bell,
                onPressed: onEnable,
              ),
              SahneButton.text(
                buttonKey: const ValueKey('notif-prompt-later'),
                label: context.t(K.notifPromptLater),
                arrow: false,
                onPressed: onLater,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
