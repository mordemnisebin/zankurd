import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';
import '../../widgets/sahne/sahne.dart';

/// Sorunun geri sayımı — oyun sahnesinin ortasındaki Şahnê sayacı
/// ([SahneTimerDiamond]).
///
/// 60 px elmas; iz tepe köşeden saat yönünde tükenir, arkada altın hale.
/// Son 5 saniyede iz, sayı ve hale Boyax'a döner ve elmas 600 ms'lik
/// nabızla atar (nabzı bileşen kendisi yönetir; "hareketi azalt" açıkken
/// atmaz).
///
/// Bu sarmalayıcının işi, quiz'in sayaç denetleyicisini (1.0 → 0.0 akan
/// [animation]) sayaca çevirmek:
///
/// * Cevap verilince ([isPaused]) gerilim biter: sayı donar, renk altına
///   döner, nabız durur. Donmuş bir "3" kırmızı atmaya devam ederse
///   cevaplanmış soruda artık olmayan bir baskı gösterirdi.
/// * "Hareketi azalt" açıkken iz sürekli akmaz, saniye saniye ilerler
///   (`ReducedMotionProvider.isReducedIn`): kalan süre bilgisi aynı kalır,
///   yalnız kesintisiz hareket kalkar.
class QuizTimerWidget extends StatelessWidget {
  const QuizTimerWidget({
    required this.animation,
    required this.maxSeconds,
    required this.isPaused,
    super.key,
  });

  final Animation<double> animation;
  final int maxSeconds;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ReducedMotionProvider.isReducedIn(context);
    final unit = context.t(K.secondsShortUnit);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value.clamp(0.0, 1.0);
        final seconds = (progress * maxSeconds).ceil();
        final fraction = reduceMotion && maxSeconds > 0
            ? seconds / maxSeconds
            : progress;
        return SahneTimerDiamond(
          secondsLeft: seconds,
          fraction: fraction,
          // Cevaptan sonra gerilim eşiği kapanır (bkz. sınıf belgesi).
          hotSeconds: isPaused ? -1 : 5,
          semanticLabel: '$seconds $unit',
        );
      },
    );
  }
}
