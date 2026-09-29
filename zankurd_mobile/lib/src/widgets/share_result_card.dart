import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/percent_format.dart';
import 'kilim_board.dart';
import 'roj_mascot.dart';
import 'sahne/sahne.dart';

/// Paylaşım için sabit boyutlu, markalı sonuç kartı. RepaintBoundary ile
/// PNG'ye render edilip share_plus üzerinden paylaşılır.
class ShareResultCard extends StatelessWidget {
  const ShareResultCard({
    required this.isKu,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.bestStreak,
    required this.category,
    this.results = const [],
    super.key,
  });

  final bool isKu;
  final int score;
  final int correctCount;
  final int totalQuestions;
  final int bestStreak;
  final String category;

  /// Turun soru soru sonucu. Boşsa şerit çizilmez (eski çağıranlar).
  final List<bool> results;

  @override
  Widget build(BuildContext context) {
    // Paylaşım kartı bir sahnedir: iki temada da gece çizilir.
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final t = SahneTokens.of(context);
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    // 2026-09-29 Şahnê: gece sahne kartı zemini (degrade + L pah yok —
    // paylaşılan görüntü dikdörtgendir), marka anı logo işareti plakası +
    // "ZanKurd", puan Ekran 64 Zêr (tablo rakamı), tur şeridi,
    // istatistikler Manşet + Açıklama, kategori Kulis çipi.
    //
    // 2026-09-29 doğallık (K4, K8): puanın altındaki kilim göz şeridi
    // kalktı — hemen altındaki tur şeridi (KilimBoard) zaten kilimdir; iki
    // kilim üst üste süs tekrarıydı. Puanın künyesi büyük harfli `K.puan`
    // ("PUAN") değil, cümle düzenindeki `K.scoreWord` ("Puan"): büyük harf
    // yalnız soru künyesinde.
    return SizedBox(
      width: 360,
      child: CustomPaint(
        painter: SahneStagePainter(
          race: false,
          glow: t.roleGlow(SahneRole.gold),
        ),
        child: Padding(
          padding: const EdgeInsets.all(SahneSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Marka
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandMarkPlate(size: 32),
                  const SizedBox(width: SahneSpace.x2),
                  Text(
                    'ZanKurd',
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ],
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                Tr.forKu(K.kurmancBilgiYarismasi, isKu),
                textAlign: TextAlign.center,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x6),

              // Skor
              Text(
                '$score',
                textAlign: TextAlign.center,
                style: SahneType.screen.copyWith(color: t.gold),
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                Tr.forKu(K.scoreWord, isKu),
                textAlign: TextAlign.center,
                style: SahneType.captionStrong.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x5),

              // Dokunan kilim.
              //
              // Kart bu satırdan önce yalnız SAYI paylaşıyordu: 340 puan,
              // %70, 5 seri. Sayı paylaşılabilir bir nesne değildir — ne
              // gören biri için bir şey ifade eder ne de paylaşanın turuna
              // ait bir şey taşır; her turun kartı aynı görünür.
              //
              // Şerit turun kendisidir ve her turda başkadır. Wordle'ın
              // ızgarasının yaptığı iş budur: paylaşılan şey skor değil,
              // oyunun ŞEKLİdir. Burada o şekil kilim olarak söylenir,
              // yani ZanKurd'a ait bir dille.
              if (results.isNotEmpty) ...[
                KilimBoard(
                  total: results.length,
                  currentIndex: results.length,
                  showCurrent: false,
                  height: 24,
                  results: results,
                ),
                const SizedBox(height: SahneSpace.x5),
              ],

              // İstatistik satırı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat(
                    t,
                    '$correctCount/$totalQuestions',
                    Tr.forKu(K.correct, isKu),
                  ),
                  _stat(
                    t,
                    PercentFormat.value(accuracy, isKu: isKu),
                    Tr.forKu(K.isabet, isKu),
                  ),
                  _stat(t, '$bestStreak', Tr.forKu(K.seri2, isKu)),
                ],
              ),
              const SizedBox(height: SahneSpace.x5),

              DecoratedBox(
                decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
                  child: Text(
                    // `category` çağırandan Kurmancî kimlik olarak gelir
                    // (bkz. `CategoryNames`); paylaşım kartı Türkçe modda ham
                    // kimliği basıyordu, kartı gören herkes görüyordu
                    // (2026-08-14 denetimi).
                    CategoryNames.localized(category, isKu),
                    textAlign: TextAlign.center,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                ),
              ),
              const SizedBox(height: SahneSpace.x4),

              Text(
                Tr.forKu(K.senDeOynaPlay, isKu),
                textAlign: TextAlign.center,
                style: SahneType.captionStrong.copyWith(color: t.goldTx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(SahneTokens t, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: SahneType.headline.copyWith(
            color: t.tx,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: SahneType.caption.copyWith(color: t.tx2)),
      ],
    );
  }
}
