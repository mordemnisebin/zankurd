import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// Yerel bankalarda yabancı dilde çeldirici sayısı YALNIZ AZALIR.
///
/// ## Kusur
///
/// `offLanguageDistractors` yıllardır vardı ve bankaları "temiz"
/// buluyordu. Değildi — sınıflandırıcı sözlük sorularının şıklarını
/// göremiyordu, üç ayrı sebeple:
///
///   1. **Hedef dil belirlenemeyince soru tamamen atlanıyordu.**
///      `Sandalye` ayırt edici harf taşımıyor ve sözlükte yoktu, yani
///      `detectLanguage` null dönüyor ve "kursî → Sandalye" sorusunun
///      `Rûniştin`/`Dibistan` çeldiricileri hiç incelenmiyordu. Oysa
///      sorunun kendisi hangi dili istediğini SÖYLÜYOR: "bi Tirkî çi ye?"
///   2. **Sözlük yalnız işlev sözcüklerinden oluşuyordu.** `Zarok`,
///      `Duh`, `Xweş` gibi içerik kelimeleri hiçbir listede yoktu ve
///      karakter sayımı da onlarda karar veremiyordu.
///   3. **Özel ad muafiyeti sözlük birimlerini de kapsıyordu.** Ölçüt
///      "en çok üç sözcük, hepsi büyük harfle başlıyor" — ve `Zarok`,
///      `Biçûk` tam da öyle görünüyor.
///
/// Üçü düzeltilince yerel bankalarda 40, sunucu bankasında 199 soru
/// ortaya çıktı. Kusur 2026-08-01'de canlı bir oda maçında görüldü:
///
///   Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
///     A) Dört  B) Rûniştin ←Kurmancî  C) Sandalye ✓  D) Öğrenmek
///
/// ## Sözlük niçin ayrı tutuluyor
///
/// Hasat edilen İÇERİK kelimeleri, cümle dilini ölçen işlev sözcüğü
/// listelerine karıştırılmamalı. İlk denemede karıştırıldı ve "Mem û Zîn,
/// kavuşamayan âşıkların hikâyesidir" gibi düpedüz Türkçe açıklamalar
/// Kurmancî ilan edildi; aynı karışım, çok kelimeli tanım şıklarında da
/// yanlış pozitif üretiyordu ("arkadaş/yoldaş", "Dîwana xwe ya klasîk").
///
/// Listeler ayrılınca ikisi birden düzeldi: tek kelimelik sözlük
/// birimleri kesin eşleşmeyle sınıflanıyor, cümleler eski ölçütte
/// kalıyor.
void main() {
  /// Bugünkü sayı: **sıfır.** Bu sabit yalnız azaltılabilir; sıfırda
  /// olduğu için pratikte bir daha artamaz.
  ///
  /// 40 kusur `tool/fix_server_style_offlanguage.py` ile onarıldı, kalan
  /// 8 "kusur" ise ölçüt düzeltilince yanlış pozitif çıktı (yukarıdaki
  /// not). Sayının artması, yeni bir sorunun aynı hatayla eklendiği
  /// anlamına gelir.
  const ceiling = 0;

  late List<QuizQuestion> bank;

  setUpAll(() {
    bank = [
      for (final asset in questionBankAssets)
        if (File(asset).existsSync())
          ...(jsonDecode(File(asset).readAsStringSync()) as List)
              .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)),
    ];
  });

  test('yabancı dilde çeldirici sayısı tavanı aşmıyor', () {
    const policy = QuestionLanguagePolicy();
    final offenders = <String>[];
    for (final question in bank) {
      final bad = policy.offLanguageDistractors(question);
      if (bad.isNotEmpty) {
        offenders.add(
          '${question.id} | ${question.prompt}\n'
          '    ${question.answers.join(" · ")}\n'
          '    doğru: ${question.correctAnswer}  yabancı: ${bad.join(", ")}',
        );
      }
    }
    expect(
      bank.length,
      greaterThan(1000),
      reason: 'Bekçi kör kalmasın: banka yüklenemediyse sayı boşa sıfırdır.',
    );
    expect(
      offenders.length,
      lessThanOrEqualTo(ceiling),
      reason:
          'Yabancı dilde çeldirici sayısı ${offenders.length}, tavan '
          '$ceiling. Yeni bir soru aynı kusurla eklenmiş olabilir:\n'
          '${offenders.join("\n")}',
    );
    if (offenders.length < ceiling) {
      // ignore: avoid_print
      print(
        'Tavan düşürülebilir: $ceiling → ${offenders.length}',
      );
    }
  });

  test('sınıflandırıcı sorunun istediği dili okuyor', () {
    // 1. kusur: hedef dil doğru cevaptan tahmin edilemeyince soru
    // atlanıyordu. Artık soru gövdesi hangi dili istediğini söylüyorsa o
    // kullanılır — tahmin değil, beyan.
    expect(
      QuestionLanguagePolicy.requestedAnswerLanguage(
        'Di Kurmancî de peyva "kursî" bi Tirkî çi ye?',
      ),
      'tr',
    );
    expect(
      QuestionLanguagePolicy.requestedAnswerLanguage(
        'Kîjan ji van peyva Kurmancî ye ku wateya wê "sandalye" ye?',
      ),
      'ku',
    );
    expect(
      QuestionLanguagePolicy.requestedAnswerLanguage(
        'Newroz kîjan rojê tê pîroz kirin?',
      ),
      isNull,
      reason: 'Soru dil belirtmiyorsa uydurulmamalı.',
    );
  });

  test('canlıda görülen kusur artık yakalanıyor', () {
    // Bekçinin gerçekten iş görmesi, bu somut örnekle ölçülür.
    const policy = QuestionLanguagePolicy();
    const broken = QuizQuestion(
      id: 'canli-ornek',
      category: 'Ziman',
      prompt: 'Di Kurmancî de peyva "kursî" bi Tirkî çi ye?',
      answers: ['Dibistan', 'Öğrenmek', 'Öğretmen', 'Sandalye'],
      correctAnswer: 'Sandalye',
      explanation: '',
    );
    expect(
      policy.offLanguageDistractors(broken),
      contains('Dibistan'),
      reason:
          'Bu tam olarak 2026-08-01 canlı maçında çıkan soru; hiçbir '
          'denetimden geçmemişti.',
    );
  });

  test('kısa Kurmancî çeldiriciler de yakalanıyor', () {
    const policy = QuestionLanguagePolicy();
    const broken = QuizQuestion(
      id: 'canli-kisa-ornek',
      category: 'Ziman',
      prompt: 'Di Kurmancî de peyva "heyv" bi Tirkî çi ye?',
      answers: ['Ay', 'Rê', 'At', 'Te'],
      correctAnswer: 'Ay',
      explanation: '',
    );
    expect(policy.offLanguageDistractors(broken), contains('Rê'));
  });

  test('doğru-yanlış soruları kapsam dışı', () {
    // `Rast`/`Şaş` sabit etiketlerdir; "çeldiricinin dili" orada
    // anlamsız ve her doğru-yanlış sorusu hatalı bildiriliyordu.
    const policy = QuestionLanguagePolicy();
    const trueFalse = QuizQuestion(
      id: 'dy',
      category: 'Ziman',
      prompt: 'Peyva Kurmancî «malper» ji bo «web sitesi» tê bikaranîn.',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: '',
    );
    expect(policy.offLanguageDistractors(trueFalse), isEmpty);
  });
}
