import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/question_timer_resume.dart';

/// Arka plandan dönüşün, DURDURMADIĞI bir sayacı başlatmadığının bekçisi.
///
/// ## Kusur
///
/// `didChangeAppLifecycleState`, `resumed` durumunda sayacı şu koşulla
/// sürdürüyordu: sayaç duruyor VE değeri sıfırdan büyük. Koşul "duruyorsa
/// demek ki duraklatılmıştır" varsayımına dayanıyordu; o varsayım yanlıştı.
///
/// `AnimationController` 1.0 ile kurulur, yani soru daha AÇILMAMIŞKEN de
/// duruyor ve değeri sıfırdan büyüktür. Soru açılışı bekleyebilir: görselli
/// sorularda akış görsel yüklenene kadar kapıda durur, ilk turda oyuncu iki
/// adımlı rehber örtüsünü okur. O pencerede uygulamayı arka plana atıp dönen
/// oyuncunun sayacı işlemeye başlıyordu — soru ekranda yokken.
///
/// Sessizdi çünkü mutlu yol kusursuzdu ve bütün testler soruyu açılmış hâlde
/// kuruyordu.
void main() {
  test('biz durdurmadıysak dönüş sayacı BAŞLATMAZ', () {
    // Tam gerileme durumu: soru hiç açılmadı, sayaç 1.0'da duruyor.
    expect(
      shouldResumeQuestionTimer(
        pausedByLifecycle: false,
        isAnimating: false,
        timerValue: 1.0,
      ),
      isFalse,
      reason:
          'Hiç başlamamış bir sayaç da "duruyor ve değeri > 0" ölçütünü '
          'geçer; ölçüt bu yüzden yetmez.',
    );
  });

  test('biz durdurduysak dönüş sayacı sürdürür', () {
    expect(
      shouldResumeQuestionTimer(
        pausedByLifecycle: true,
        isAnimating: false,
        timerValue: 0.6,
      ),
      isTrue,
      reason:
          'Meşru duraklat/sürdür kırılmamalı: arka plana gidip dönen bir '
          'turda süre kaldığı yerden akmalı.',
    );
  });

  test('arada başka bir yol başlattıysa ikinci kez başlatılmaz', () {
    expect(
      shouldResumeQuestionTimer(
        pausedByLifecycle: true,
        isAnimating: true,
        timerValue: 0.6,
      ),
      isFalse,
    );
  });

  test('süresi dolmuş sayaç sürdürülmez', () {
    // Sıfır, sorunun bittiği anlamına gelir; sonu ayrı bir yolda karara
    // bağlanır ve burada yeniden başlatmak o kararı ezerdi.
    expect(
      shouldResumeQuestionTimer(
        pausedByLifecycle: true,
        isAnimating: false,
        timerValue: 0.0,
      ),
      isFalse,
    );
  });
}
