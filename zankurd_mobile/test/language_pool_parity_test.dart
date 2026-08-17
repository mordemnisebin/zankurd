import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Hiçbir soru TİPİ tek dilde oynanabilir kalmamalı.
///
/// ## Niçin var
///
/// `bilingual_bank_integrity_test` alan bütünlüğünü ölçüyor: Türkçe alanlar
/// ya hep birlikte var ya hiç yok, `answersTr` uzunluğu tutuyor, doğru cevap
/// Türkçe şıklar içinde. Hepsi soru BAŞINA kurallar.
///
/// Ölçülmeyen şey bir üst katmandı: **dil başına havuz genişliği**. Türkçe
/// alanları olmayan bir soru Türkçe oynanışta yok hükmündedir; bir tipin
/// tamamı Kurmancî-only olursa Türkçe oynayan oyuncu o soru tipini HİÇ
/// görmez. Bu sessiz bir özellik kaybıdır: hata yok, boş ekran yok, yalnız
/// eksik bir deneyim. Soru başına kurallar bunu göremez çünkü her soru tek
/// başına kusursuzdur (2026-08-17 taraması).
///
/// ## Ölçülen durum
///
/// Tarama anında banka 2120 oynanabilir soru taşıyordu ve beş tipin
/// tamamında Türkçe karşılık **%100**'dü:
/// çoktan seçmeli 1396, doğru/yanlış 568, görsel 128, boşluk doldurma 20,
/// kelime sıralama 8. Yani şu an bir kusur YOK; bekçi bunu kilitliyor.
///
/// Kural bilerek "parite" olarak yazıldı, "en az N soru" olarak değil: eşik
/// seçmek keyfî olurdu ve içerik dalgaları eşiği sürekli tartışmaya açardı.
/// Parite ise içerik yazarının kararına karışmadan tek şeyi şart koşar —
/// hangi dilde yazıldıysa öteki dilde de oynanabilsin.
void main() {
  test('her soru tipi iki dilde de aynı genişlikte oynanabiliyor', () {
    final repository = MockZanKurdRepository();
    final playable = repository.playableQuestions;

    expect(
      playable.length,
      greaterThan(500),
      reason:
          'Banka beklenmedik ölçüde küçük geldi; tarama dar bir küme '
          'üzerinde kendiliğinden geçerdi.',
    );

    final gaps = <String>[];
    for (final type in QuestionType.values) {
      final ofType = playable.where((q) => q.type == type).toList();
      if (ofType.isEmpty) continue;

      final turkishPlayable = ofType
          .where((q) => (q.promptTr ?? '').trim().isNotEmpty)
          .length;

      if (turkishPlayable != ofType.length) {
        gaps.add(
          '${type.name}: ${ofType.length} sorunun yalnız $turkishPlayable '
          'tanesi Türkçe oynanabiliyor',
        );
      }
    }

    expect(
      gaps,
      isEmpty,
      reason:
          'Bu soru tipleri Türkçe oynanışta eksik kalıyor; oyuncu tipi hiç '
          'görmeyebilir:\n${gaps.join('\n')}',
    );
  });

  /// İki serbest metin tipi bankanın en ince kısmı: kelime sıralama 8,
  /// boşluk doldurma 20 soru. Bu bir kusur değil, bir içerik kararı — ama
  /// kazara silinmeye karşı bir taban gerekiyor, çünkü tipin tamamı
  /// düştüğünde hiçbir test bunu söylemez: quiz ekranı o tipi hiç
  /// kurmadığında da yeşil kalır.
  test('serbest metin tipleri bankadan kazara düşmez', () {
    final playable = MockZanKurdRepository().playableQuestions;

    int countOf(QuestionType type) =>
        playable.where((q) => q.type == type).length;

    expect(
      countOf(QuestionType.fillInBlank),
      greaterThanOrEqualTo(20),
      reason: 'Boşluk doldurma havuzu ölçülen tabanın altına düştü.',
    );
    expect(
      countOf(QuestionType.wordOrdering),
      greaterThanOrEqualTo(8),
      reason: 'Kelime sıralama havuzu ölçülen tabanın altına düştü.',
    );
  });
}
