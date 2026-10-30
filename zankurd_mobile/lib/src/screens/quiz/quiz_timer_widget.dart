import 'package:zankurd_mobile/src/utils/number_format.dart';

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
    this.expired = false,
    this.pendingLabel,
    this.opponentTime = false,
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
  /// çelişiyordu. Açılışta sayı yerine tamamlanma işareti; tek geri
  /// sayım alt şeritteki.
  final bool stopped;

  /// Yetkili cevapsız/süre doldu durumu; resume animasyonu henüz tam
  /// süredeyken de sıfır saniye gösterilmesini sağlar.
  final bool expired;

  /// Sunucu hazır yanıtı beklenirken sahte tam süreyi seslendirme.
  final String? pendingLabel;

  /// Kendi yanıtı gönderilmiş; akan süre diğer oyunculara ait.
  final bool opponentTime;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value.clamp(0.0, 1.0);
        // Resume görüntüsü animasyon denetleyicisinden önce gelebilir.
        // Yetkili TIMEOUT başlangıçtaki 1.0 değerini süre diye göstermez.
        final seconds = expired ? 0 : (progress * maxSeconds).ceil();
        return SahneStageTimer(
          secondsLeft: seconds,
          maxSeconds: maxSeconds,
          // Cevaptan sonra gerilim eşiği kapanır (bkz. sınıf belgesi).
          hotSeconds: isPaused || opponentTime ? -1 : 5,
          secondary: opponentTime,
          onBand: onBand,
          pending: stopped && pendingLabel != null,
          // Süresi biten soru tamamlanma tikiyle başarı gibi okunmasın.
          // Sıfır aynı sabit sayı yuvasında kalır; üst satır oynamaz.
          revealed: false,
          semanticLabel: stopped
              ? pendingLabel ??
                    context.t(
                      seconds == 0 ? K.sureDoldu : K.t12QuestionRevealed,
                    )
              : pendingLabel ??
                    context.t(
                      opponentTime
                          ? K.timerOpponentSecondsLeft
                          : K.timerSecondsLeft,
                      {'n': groupThousands(seconds)},
                    ),
        );
      },
    );
  }
}
