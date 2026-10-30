import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../widgets/sahne/sahne.dart';

/// Sorunun geri sayımı — üst satırın sağındaki küçük saniye göstergesi
/// ([SahneStageTimer]): saat ikonu + kalan saniye.
///
/// 2026-10-19 sadeleşme: eskiden 60 px'lik elmas sayaçtı ([SahneTimerDiamond],
/// arkasında hale ve nabız). Soru okunurken gözü metinden çekiyordu; test
/// edenler ekranı "kalabalık, gözü yoruyor" buldu. Kalan süre bilgisi aynı,
/// ağırlığı küçük; son 5 saniyede sayı ve ikon Boyax'a döner.
///
/// Bu sarmalayıcının işi, quiz'in sayaç denetleyicisini (1.0 → 0.0 akan
/// [animation]) saniyeye çevirmek:
///
/// * Cevap verilince ([isPaused]) gerilim biter: sayı donar, renk normale
///   döner. Donmuş bir "3" kırmızı kalırsa cevaplanmış soruda artık olmayan
///   bir baskı gösterirdi.
/// * Sayı zaten saniye saniye değiştiği için "hareketi azalt" ayrıca bir şey
///   değiştirmez; yalnız saniye tamsayısı yeniden çizilir.
class QuizTimerWidget extends StatelessWidget {
  const QuizTimerWidget({
    required this.animation,
    required this.maxSeconds,
    required this.isPaused,
    this.light,
    this.onBand = false,
    this.stopped = false,
    this.pendingLabel,
    super.key,
  });

  final Animation<double> animation;
  final int maxSeconds;
  final bool isPaused;

  /// Geriye uyum: sayacın halesi kalktığı için artık bir şey boyamaz.
  final Color? light;

  /// Konu bandının üstünde ([SahneStageTimer.onBand]).
  final bool onBand;

  /// Kurul 3 D2 (3/3): cevap açılışında soru süresi bitmiştir; üstteki
  /// sayaç "11" gibi akmaya devam ediyor görünüp alttaki "sonraki 4 sn" ile
  /// çelişiyordu. Açılışta sayı yerine "–" (kapsül genişliği aynı); tek geri
  /// sayım alt şeritteki.
  final bool stopped;

  /// Sunucu hazır yanıtı beklenirken sahte tam süreyi seslendirme.
  final String? pendingLabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value.clamp(0.0, 1.0);
        final seconds = (progress * maxSeconds).ceil();
        return SahneStageTimer(
          secondsLeft: seconds,
          maxSeconds: maxSeconds,
          // Cevaptan sonra gerilim eşiği kapanır (bkz. sınıf belgesi).
          hotSeconds: isPaused ? -1 : 5,
          onBand: onBand,
          pending: stopped,
          semanticLabel:
              pendingLabel ?? context.t(K.timerSecondsLeft, {'n': '$seconds'}),
        );
      },
    );
  }
}
