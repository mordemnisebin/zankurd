import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/reduced_motion_provider.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    required this.isOffline,
    this.onRetry,
    this.label,
    super.key,
  });

  final bool isOffline;
  final VoidCallback? onRetry;
  final String? label;

  @override
  Widget build(BuildContext context) {
    // 2026-09-25: şerit doygun kırmızı doluydu ve tam genişlikte ekranın
    // tepesine yapışıyordu. Çevrimdışı olmak bir HATA değil, bir DURUM:
    // bilgi ver, panik yaratma.
    //
    // 2026-09-29 Şahnê: ince bilgi şeridi — Kulis (`s2`) tonu + altta 1 px
    // ayırıcı (`line`), ikincil metin renginde bulut ikonu, birincil metin.
    // Durum yalnız renkle verilmez: ikon ve söz birlikte. "Yeniden dene"
    // bir metin bağlantısıdır (Agir metni, `actTx`); dolgu değil — ekranın
    // birincil eylemiyle yarışmaz.
    final t = SahneTokens.of(context);
    // 300 ms boy değişimi süsüdür. Tercih açıkken şerit anında durur;
    // yoksa kabuktaki her çevrimdışı uyarısı ayarı yok saymış olur.
    final reduceMotion = ReducedMotionProvider.isReducedIn(context);
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return AnimatedSize(
      duration: animDuration,
      curve: Curves.easeInOut,
      child: isOffline
          ? Material(
              color: t.s2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SahneSpace.page,
                      vertical: SahneSpace.x1,
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.cloud, color: t.tx2, size: 20),
                        const SizedBox(width: SahneSpace.x3),
                        Expanded(
                          child: Text(
                            label ?? context.t(K.offlineChecking),
                            style: SahneType.captionStrong.copyWith(
                              color: t.tx,
                            ),
                          ),
                        ),
                        if (onRetry != null)
                          InkWell(
                            onTap: onRetry,
                            customBorder: SahneShape.m,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SahneSpace.x2,
                                ),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    context.t(K.retry),
                                    style: SahneType.captionStrong.copyWith(
                                      color: t.actTx,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
