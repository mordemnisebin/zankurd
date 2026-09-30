import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widgets/sahne/sahne.dart';

/// Ana ekranın tek birincil eylemi: "bugün şunu yap".
///
/// 2026-09-29 Şahnê: günlük görev bir **sahne kartıdır** (gece degradesi,
/// Zimrût köşe radyali; gündüz temasında da gece). Maketteki "Günün dersi"
/// kartının yapısı: üst etiket + manşet + açıklama solda, ders elması
/// ("2/5") sağda, altında tam genişlik TEK birincil düğme (Agir, koyu
/// metin). Eski hâl koyu yeşil elle yazılmış bir degrade, şafak dağı
/// ressamı, maskot ve beyaz yazılı turuncu düğmeydi; hepsi kalktı.
/// İlerleme kilim çubuğu yerine ders elmasıyla okunur.
///
/// 2026-09-29 doğallık (K8): üst etiket büyük harf + harf aralığıyla
/// ("BUGÜNÜN GÖREVİ") bağırıyordu; artık kalın açıklama, cümle düzeni
/// ("Bugünün görevi"). Büyük harf yalnız soru sahnesinin künyesinde kalır.
/// Kilim şeridi de yok (K4: `SahneStageCard` varsayılanı kapalı).
///
/// Kart `SahneStageCard.lesson` ile aynı yerleşimi kurar ama düğmeyi kendisi
/// çizer: ekran okuyucu düğümü (`home-daily-task-start`) ve yükleniyor
/// hâli ana ekranın sözleşmesidir, bileşenin kendi düğmesi bunları taşımaz.
class TodayTaskCard extends StatelessWidget {
  const TodayTaskCard({
    required this.isKu,
    required this.loading,
    required this.onStart,
    this.done = 0,
    this.total = 10,
    this.firstSession = false,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final VoidCallback onStart;

  /// Bugün verilen DOĞRU cevap sayısı — SORU sayısı değil.
  ///
  /// Kaynağı `HomeScreen._todayAnswered = store.correctAnswersToday`;
  /// [total] da soru adedi değil, günlük "answerCorrect" görevinin
  /// hedefidir. Bu ayrım önemli: günlük hedef dalındaki "kalan" metni
  /// kalan SORU değil kalan DOĞRU CEVAP sayar (2026-09-27 canlı gezinti —
  /// bkz. [K.dailyGoalRemainingCorrect]).
  final int done;
  final int total;
  final bool firstSession;

  /// Soru başına ~25 saniyelik gerçekçi ortalama üzerinden tahmini süre.
  static int _minutesFor(int questions) =>
      ((questions * 25) / 60).ceil().clamp(1, 60);

  @override
  Widget build(BuildContext context) {
    final started = done > 0;
    // İlk ders bitince kart hâlâ "Günün dersi" diyordu; oyuncu az önce bir
    // ders bitirmişken aynı adı yeniden görünce "bitirdim, neden yine ders?"
    // diye duruyordu (2026-09-27 canlı gezinti). Gün içinde ilerleme
    // BAŞLADIKTAN sonra ve hedef tamamlanmadan ÖNCE başlık günlük hedefe
    // döner. Günün ilk açılışı (0 doğru) "Günün dersi" kalır: henüz hiçbir
    // şey yapılmamışken "10 doğru cevap daha" demek "daha"yı boşa düşürür.
    // İlk oturum ("Küçük başlangıç") ve tamamlanmış hedef durumuna kasıtlı
    // dokunulmaz.
    final goalInProgress = !firstSession && started && done < total;
    final remaining = total - done;

    final title = goalInProgress
        ? Tr.forKu(K.dailyGoalTitle, isKu)
        : Tr.forKu(K.gununDersi, isKu);
    final meta = goalInProgress
        ? Tr.forKu(K.dailyGoalRemainingCorrect, isKu, {
            'n': '$remaining',
            'm': '${_minutesFor(remaining)}',
          })
        : Tr.forKu(firstSession ? K.firstSessionSub : K.pSoruYaklasikP, isKu, {
            'p0': '$total',
            'p1': '${_minutesFor(total)}',
          });
    final eyebrow = Tr.forKu(
      firstSession ? K.firstSessionBadge : K.bugununGorevi,
      isKu,
    );
    // Hedef dolduysa "Devam et" yalan olur: devam edilecek bir şey kalmadı
    // (2026-09-30 canlı: 10/10 elması yanında "Devam et"). Kart yine yeni
    // bir tur açar; bu yüzden düğme "Tekrar oyna" der.
    final reached = total > 0 && done >= total;
    final label = reached
        ? Tr.forKu(K.playAgain, isKu)
        : started
        ? Tr.forKu(K.devamEt, isKu)
        : Tr.forKu(K.start, isKu);

    return KeyedSubtree(
      key: const ValueKey('home-daily-task'),
      child: SahneStageCard(
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            final texts = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                KeyedSubtree(
                  key: firstSession
                      ? const ValueKey('home-first-session-badge')
                      : null,
                  child: Text(
                    eyebrow,
                    style: SahneType.captionStrong.copyWith(color: t.learnTx),
                  ),
                ),
                const SizedBox(height: SahneSpace.x1),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(meta, style: SahneType.caption.copyWith(color: t.tx2)),
              ],
            );
            final diamond = SahneLessonDiamond(
              done: done.clamp(0, total < 0 ? 0 : total),
              total: total,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Metne en az altı manşet harfi kalmıyorsa (büyük yazı, dar
                // ekran) ders elması metnin altına iner; başlık harf harf
                // bölünmez (`SahneStageCard.lesson` ile aynı kural).
                LayoutBuilder(
                  builder: (context, c) {
                    final room = c.maxWidth - 80 - SahneSpace.x4;
                    final wide =
                        room >= MediaQuery.textScalerOf(context).scale(22) * 6;
                    if (wide) {
                      return Row(
                        children: [
                          Expanded(child: texts),
                          const SizedBox(width: SahneSpace.x4),
                          diamond,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        texts,
                        const SizedBox(height: SahneSpace.x3),
                        diamond,
                      ],
                    );
                  },
                ),
                const SizedBox(height: SahneSpace.x4),
                _StartButton(label: label, loading: loading, onTap: onStart),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kartın tek birincil düğmesi: Agir dolgu, koyu `onAct` metin, tam
/// genişlik. Yüklenirken pasif (Perde + üçüncül metin), sözü değişmez.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = !loading;
    return Semantics(
      key: const ValueKey('home-daily-task-start'),
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: SahneButton.primary(
        label: label,
        onPressed: enabled ? onTap : null,
        expand: true,
      ),
    );
  }
}
