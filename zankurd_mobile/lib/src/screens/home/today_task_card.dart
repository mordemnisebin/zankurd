import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widgets/sahne/sahne.dart';

/// Ana ekranın tek birincil eylemi: "bugün şunu yap".
///
/// 2026-10-19 sadeleşme: kart artık **sakin bir yüzey kartıdır** (gündüz
/// beyaz + 1 px #E3E7F0 kenar, gece Perde; degrade ve köşe radyali yok).
/// Test edenler ana ekranı "kalabalık, gözü yoruyor" buldu; en büyük iki
/// doygun dolgu (bu kart ve düello kartı) ekranın ilk bakışta bağırmasının
/// sebebiydi. İlerleme 80 px'lik ders elması yerine ince 4 px çubuk ve
/// küçük "0/5" metnidir. Turuncu YALNIZ "Başla" düğmesidir.
///
/// 2026-09-29 Şahnê (tarihçe): kart gece degradeli bir sahne kartıydı.
/// Maketteki "Günün dersi" yapısı korunur: üst etiket + manşet + açıklama,
/// altında tam genişlik TEK birincil düğme (Agir, koyu metin).
///
/// 2026-09-29 doğallık (K8): üst etiket büyük harf + harf aralığıyla
/// ("BUGÜNÜN GÖREVİ") bağırıyordu; artık kalın açıklama, cümle düzeni
/// ("Bugünün görevi"). Büyük harf yalnız soru sahnesinin künyesinde kalır.
/// Kilim şeridi de yok (K4: `SahneStageCard` varsayılanı kapalı).
///
/// 2026-10-20 kimlik ("Çiya", kullanıcının açık tercihi): kartın tepesinde
/// ALÇAK bir manzara şeridi ([SahneVistaStrip], 88 pt): logodaki dağ sırtı
/// şafakta (gece yıldızlı gökte zirvede tek turuncu ışık). Şerit kartın
/// ayrı bir satırıdır; metin ve düğme üstüne binmez. Kurulun tek itirazı
/// konuların aşağı itilmesiydi; şerit bu yüzden alçak ve 390×844'te ilk
/// konu satırı ilk ekranda kalır (bekçi: `manzara_seridi_test.dart`).
///
/// Kart düğmeyi kendisi çizer: ekran okuyucu düğümü (`home-daily-task-start`) ve yükleniyor
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

    final titleKey = goalInProgress ? K.dailyGoalTitle : K.gununDersi;
    final title = Tr.forKu(titleKey, isKu);
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
      child: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return SahneSurfaceCard(
            // Zimrût tonlu kart (2026-10-20): öğrenme modunun rengi.
            color: t.learnTint,
            edgeColor: t.learnEdge,
            // Manzara kenardan kenara; içerik kendi 16'lık boşluğunu taşır.
            padding: EdgeInsets.zero,
            emboss: true,
            child: Builder(
              builder: (context) {
                final safeTotal = total < 0 ? 0 : total;
                final safeDone = done.clamp(0, safeTotal);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SahneVistaStrip(mascot: true),
                    Padding(
                      padding: const EdgeInsets.all(SahneSpace.x4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KeyedSubtree(
                            key: firstSession
                                ? const ValueKey('home-first-session-badge')
                                : null,
                            child: Text(
                              eyebrow,
                              style: SahneType.captionStrong.copyWith(
                                color: t.learnTx,
                              ),
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
                          Text(
                            meta,
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                          // W11 (2026-10-28 tur 5): ilerleme çubuğu İLK doğru
                          // cevaba kadar gizli; "0/5" boş çubuk ilerlemeyi değil
                          // eksikliği gösteriyordu.
                          if (safeDone > 0) ...[
                            const SizedBox(height: SahneSpace.x3),
                            // İlerleme: ince 4 px çubuk + küçük "0/5". Eskiden 80 px'lik
                            // ders elmasıydı (bkz. sınıf belgesi).
                            SahneProgressBar(
                              key: const ValueKey('home-daily-task-progress'),
                              value: safeTotal == 0 ? 0 : safeDone / safeTotal,
                              // Kalın (8 px) Zimrût çubuk, tonlu iz (2026-10-20).
                              height: 8,
                              trackColor: t.learnTrack,
                              edgeColor: t.learnEdge,
                              trailing: '$safeDone/$safeTotal',
                              semanticLabel: title,
                            ),
                          ],
                          const SizedBox(height: SahneSpace.x4),
                          _StartButton(
                            label: label,
                            loading: loading,
                            onTap: onStart,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
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
