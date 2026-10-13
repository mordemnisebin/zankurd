import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/answer_record.dart';
import '../theme/app_icons.dart';
import 'app_panel.dart';
import 'sahne/sahne.dart';

/// Bir kategorinin tur içindeki ham sayımı: kaç soru cevaplandı, kaçı
/// doğruydu. `LearningOutcome.strongestCategory`/`reviewCategory`nin aksine
/// hiçbir eşik uygulamaz — "en güçlü/en zayıf" seçilemeyen (çoğunlukla
/// tek-soruluk) kategoriler için de dürüst bir satır üretebilmek içindir.
typedef CategoryTally = ({String category, int answered, int correct});

class LearningOutcome {
  const LearningOutcome({
    required this.strongestCategory,
    required this.strongestCorrect,
    required this.strongestAnswered,
    required this.reviewCategory,
    required this.reviewWrong,
    required this.reviewAnswered,
    required this.reviewRecords,
    required this.answered,
    required this.correct,
    required this.unanswered,
    required this.categoryBreakdown,
  });

  factory LearningOutcome.fromRecords(List<AnswerRecord> records) {
    final stats = <String, _TopicStats>{};
    // Kategori sırası İLK GÖRÜLDÜĞÜ sırayla korunur (turun akışını yansıtır);
    // `Map` anahtar sırası da zaten eklenme sırasıdır ama bunu açıkça ayrı
    // tutmak `stats`in iç veri yapısı değişse bile sırayı garanti eder.
    final categoryOrder = <String>[];
    final wrongRecords = <AnswerRecord>[];
    var answered = 0;
    var correct = 0;
    var unanswered = 0;

    for (final record in records) {
      if (record.isUnanswered) {
        unanswered++;
        continue;
      }
      answered++;
      if (record.isCorrect) correct++;
      if (!record.isCorrect) wrongRecords.add(record);
      final category = record.category.trim();
      if (category.isEmpty) continue;
      if (!stats.containsKey(category)) categoryOrder.add(category);
      final current = stats[category] ?? const _TopicStats();
      stats[category] = current.add(record.isCorrect);
    }

    // 2026-10-02: "Nerelerde zorlandın?" kutusu ZAYIF konuyu göstermeli.
    //
    // ## Kusur
    //
    // Her iki seçim de `answered >= 2` eşiğine bağlıydı. Karışık turlarda
    // (günün dersi: kategori başına çoğu zaman TEK soru) tek yanlış hiçbir
    // eşiği geçemiyor, bu yüzden kutu yalnız en çok sorulan güçlü konuyu
    // yazıyordu: simülatörde 9/10'luk turda Siyaset 0/1 (tek yanlış), Coğrafya
    // 3/3 iken "Nerelerde zorlandın?" başlığının altında yeşil tikle
    // "Coğrafya: 3 sorudan 3 doğru" çıktı — başlık zorlanmayı sorarken cevap
    // başarıyı söylüyordu.
    //
    // ## Niçin sessiz kalırdı
    //
    // Eşik "tek soruyu güç/eksiklik SAYMA" kararını korumak için konmuştu
    // (2026-09-27) ve bir testle bağlanmıştı; ama o karar iki ayrı şeyi
    // birleştirdi: tek soruluk GÜÇ iddiası (haklı olarak ihtiyatlı) ile tek
    // yanlışın GÖSTERİLMESİ (sayım iddiası değil, tekrar önerisi). Hiçbir
    // test başlığın söylediği ile satırın söylediğini birlikte okumadı.
    //
    // ## Kural
    //
    // Zayıf konu = en az bir yanlışı olan kategoriler arasında en düşük
    // doğruluk; eşitlikte en çok yanlış; sonra turda ilk görülen. Güçlü
    // konu eşiği (2+ cevap, 2+ doğru, %75+) AYNI kaldı ve zayıf konudan
    // farklı bir kategori olmalı. Yanlışı olmayan turda başlık "zorlandın"
    // demez (bkz. [LearningOutcomeCard]).
    MapEntry<String, _TopicStats>? review;
    for (final entry in stats.entries) {
      final value = entry.value;
      if (value.wrong == 0) continue;
      if (review == null) {
        review = entry;
        continue;
      }
      final current = review.value;
      // Doğruluk çapraz çarpımla karşılaştırılır (bölme yok): düşük olan
      // zayıf.
      final accuracy = value.correct * current.answered;
      final currentAccuracy = current.correct * value.answered;
      if (accuracy < currentAccuracy ||
          (accuracy == currentAccuracy && value.wrong > current.wrong)) {
        review = entry;
      }
    }

    MapEntry<String, _TopicStats>? strongest;
    for (final entry in stats.entries) {
      if (entry.key == review?.key) continue;
      final value = entry.value;
      if (value.answered >= 2 &&
          value.correct >= 2 &&
          value.correct / value.answered >= 0.75 &&
          (strongest == null ||
              value.correct / value.answered >
                  strongest.value.correct / strongest.value.answered ||
              (value.correct / value.answered ==
                      strongest.value.correct / strongest.value.answered &&
                  value.answered > strongest.value.answered))) {
        strongest = entry;
      }
    }

    final selectedWrong = review == null
        ? wrongRecords
        : wrongRecords
              .where((record) => record.category.trim() == review!.key)
              .toList(growable: false);

    return LearningOutcome(
      strongestCategory: strongest?.key,
      strongestCorrect: strongest?.value.correct ?? 0,
      strongestAnswered: strongest?.value.answered ?? 0,
      reviewCategory: review?.key,
      reviewWrong: review?.value.wrong ?? 0,
      reviewAnswered: review?.value.answered ?? 0,
      reviewRecords: selectedWrong,
      answered: answered,
      correct: correct,
      unanswered: unanswered,
      categoryBreakdown: [
        for (final category in categoryOrder)
          (
            category: category,
            answered: stats[category]!.answered,
            correct: stats[category]!.correct,
          ),
      ],
    );
  }

  final String? strongestCategory;
  final int strongestCorrect;
  final int strongestAnswered;
  final String? reviewCategory;
  final int reviewWrong;
  final int reviewAnswered;
  final List<AnswerRecord> reviewRecords;
  final int answered;
  final int correct;
  final int unanswered;

  /// Kutunun söyleyecek bir yorumu var mı (zayıf ya da güçlü konu)?
  /// Sayımlar zaten başka yerde gösteriliyorsa (`showCounts: false`) yorumsuz
  /// kutu gizlenir.
  bool get hasSpotlight => reviewCategory != null || strongestCategory != null;

  /// Turda görülen HER kategori, sırayla (turda ilk cevaplanan kategori
  /// önce), eşiksiz ham sayımla. `strongestCategory`/`reviewCategory`
  /// yalnız 2+ cevaplı ve belirgin oranlı TEK bir kategoriyi öne çıkarır;
  /// bu liste ise "günün dersi" gibi karışık kategorili, kategori başına
  /// çoğu zaman tek soru düşen turlarda geri kalan kategorilerin de
  /// gösterilebilmesi içindir (bkz. `LearningOutcomeCard` render notu).
  final List<CategoryTally> categoryBreakdown;
}

class _TopicStats {
  const _TopicStats({this.correct = 0, this.wrong = 0});

  final int correct;
  final int wrong;
  int get answered => correct + wrong;

  _TopicStats add(bool isCorrect) => _TopicStats(
    correct: correct + (isCorrect ? 1 : 0),
    wrong: wrong + (isCorrect ? 0 : 1),
  );
}

class LearningOutcomeCard extends StatelessWidget {
  const LearningOutcomeCard({
    required this.outcome,
    required this.onReview,
    this.showCounts = true,
    super.key,
  });

  final LearningOutcome outcome;
  final VoidCallback? onReview;

  /// `false`: toplam sayım satırı ve kategori başına ham sayımlar gizlenir.
  ///
  /// Sonuç ekranı aynı sayımları zaten gösteriyor (istatistik karoları ve
  /// kategori listesi); kart orada yalnız yorumu ("en güçlü", "tekrar et")
  /// ve gözden geçirme eylemini taşır. Aynı sayının üç kez okunması
  /// (2026-09-29 sonuç grubu) gürültüydü.
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final strongest = outcome.strongestCategory;
    final review = outcome.reviewCategory;
    final strongestName = strongest == null
        ? null
        : CategoryNames.localized(strongest, isKu);
    final reviewName = review == null
        ? null
        : CategoryNames.localized(review, isKu);
    // Kusur 2: kart yalnız TEK bir "en güçlü" ve TEK bir "tekrar" satırı
    // basıyordu; "günün dersi" gibi karışık kategorili turlarda (kategori
    // başına çoğu zaman bir soru düşer) diğer kategoriler sessizce
    // kayboluyordu — canlı turda Müzik 1/1, Coğrafya 1/1, Kültür 0/1 hiç
    // görünmüyor, yalnız "Dil: 2 sorunun 2'si doğru" kalıyordu (2026-09-27
    // simülatör turu). Kesme KASITSIZDI: `answered >= 2` eşiği yalnız
    // "tek soruyu güç/eksiklik SAYMA" kararını korumak için var (bkz.
    // `learning_outcome_card_test.dart`daki "tek sorudan konu gücü ya da
    // konu eksiği çıkarmaz" testi) — kategoriyi TAMAMEN GİZLEME kararı
    // değil. Düzeltme: spotlight'a giremeyen (ya eşiğin altında ya da
    // ikinci en iyi/kötü) kategoriler, iddiasız/eşiksiz bir sayımla yine de
    // listelenir. Tek kategorili turda liste hep boştur (üstteki toplam
    // satırıyla birebir aynı şeyi tekrar eder), bu yüzden yalnız GERÇEKTEN
    // karışık turlarda (2+ kategori) gösterilir.
    final leftoverCategories =
        showCounts && outcome.categoryBreakdown.length > 1
        ? outcome.categoryBreakdown
              .where(
                (tally) =>
                    tally.category != strongest && tally.category != review,
              )
              .toList(growable: false)
        : const <CategoryTally>[];

    // 2026-09-29 Şahnê: öğrenme notu dili — öğrenme tonu kart (`learnTint`,
    // L pah) + Zimrût ampul; sayım Gövde 700, satırlar Gövde ikincil metin;
    // güçlü konu Rast ✓, tekrar konusu Zêr hedef. Gözden geçirme ikincil
    // düğme (Kulis): sonuç ekranının birincil eylemi "Devam et"tir.
    final t = SahneTokens.of(context);

    // Başlık satırın söylediğiyle UYUŞMALI (2026-10-02): "Nerelerde
    // zorlandın?" yalnız gerçekten bir zayıf konu varsa. Yanlışsız turda
    // güçlü konu satırı kendi başlığıyla ("En güçlü olduğun konu:") gelir;
    // yalnız eşiksiz sayımlar varsa nötr "Konulara göre" kullanılır. Söyleyecek
    // yorumu olmayan ve sayımları başka yerde gösterilen kutu hiç çizilmez.
    if (!showCounts && !outcome.hasSpotlight) return const SizedBox.shrink();
    final title = reviewName != null
        ? K.outcomeTitle
        : strongestName != null
        ? K.enGucluOldugunKategori
        : K.resultLearnedTitle;
    return AppPanel(
      key: const ValueKey('learning-outcome-card'),
      color: t.learn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.lightbulb, size: 20, color: t.learnTx),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
                child: Text(
                  context.t(title),
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          if (showCounts) ...[
            const SizedBox(height: SahneSpace.x3),
            Text(
              context.t(K.outcomeCounts, {
                'answered': '${outcome.answered}',
                'correct': '${outcome.correct}',
                'wrong': '${outcome.answered - outcome.correct}',
              }),
              style: SahneType.bodyStrong.copyWith(color: t.tx),
            ),
          ],
          if (showCounts && outcome.unanswered > 0) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(
              context.t(K.outcomeUnanswered, {
                'count': '${outcome.unanswered}',
              }),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
          ],
          const SizedBox(height: SahneSpace.x2),
          if (strongestName != null)
            _OutcomeLine(
              icon: AppIcons.circleCheck,
              color: t.okTx,
              text: context.t(K.outcomeStrong, {
                'name': strongestName,
                'answered': '${outcome.strongestAnswered}',
                'correct': '${outcome.strongestCorrect}',
              }),
            ),
          if (strongestName != null && reviewName != null)
            const SizedBox(height: SahneSpace.x2),
          if (reviewName != null)
            _OutcomeLine(
              icon: AppIcons.bullseye,
              color: t.goldTx,
              text: context.t(K.outcomeReview, {
                'name': reviewName,
                'answered': '${outcome.reviewAnswered}',
                'wrong': '${outcome.reviewWrong}',
              }),
            ),
          if (leftoverCategories.isNotEmpty) ...[
            if (strongestName != null || reviewName != null)
              const SizedBox(height: SahneSpace.x2),
            for (final tally in leftoverCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: SahneSpace.x1),
                child: Text(
                  context.t(K.outcomeCategoryTally, {
                    'name': CategoryNames.localized(tally.category, isKu),
                    'answered': '${tally.answered}',
                    'correct': '${tally.correct}',
                  }),
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
              ),
          ],
          if (strongestName == null &&
              reviewName == null &&
              leftoverCategories.isEmpty)
            Text(
              context.t(K.outcomeEmpty),
              style: SahneType.body.copyWith(color: t.tx2),
            ),
          if (outcome.reviewRecords.isNotEmpty) ...[
            const SizedBox(height: SahneSpace.x4),
            SahneButton.secondary(
              key: const ValueKey('learning-outcome-review'),
              onPressed: onReview,
              icon: AppIcons.bookOpen,
              expand: true,
              label: reviewName == null
                  ? context.t(K.outcomeReviewGeneric)
                  : context.t(K.outcomeReviewNamed, {'name': reviewName}),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // İkon ilk satırın 24'lük yüksekliğinde ortalanır.
      SizedBox(
        height: 24,
        child: Center(child: Icon(icon, size: 20, color: color)),
      ),
      const SizedBox(width: SahneSpace.x2),
      Expanded(
        child: Text(
          text,
          style: SahneType.body.copyWith(color: SahneTokens.of(context).tx2),
        ),
      ),
    ],
  );
}
