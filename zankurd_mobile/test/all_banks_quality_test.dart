import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// Kalite kurallarını **bütün** soru kaynaklarına uygular.
///
/// 2026-07-26 canlı denetimi: ekran turunda gelen bir soruda sorulan terim
/// şıklar arasında duruyordu —
///
///     "Di gotina «Jin, Jiyan, Azadî» de «jiyan» çi ye?" → ✓ Jiyan
///
/// Kusur zaten yasaklanmıştı; ama bekçiler yalnız
/// `assets/data/offline_questions.json` üzerinde koşuyordu. Soru ise
/// `lib/src/data/curated_question_bank.dart` içindeydi: kod tarafında
/// tutulan, JSON taramasının hiç görmediği üçüncü bir banka. Üç soru
/// böyle kaçmıştı.
///
/// Kural: yeni bir kaynak eklendiğinde buraya da eklenir. Kaynağı listeye
/// eklemeyi unutmak, kalite bekçisini o kaynak için sessizce kapatmaktır.
void main() {
  const policy = QuestionLanguagePolicy();

  List<QuizQuestion> fromJson(String path) {
    final file = File(path);
    if (!file.existsSync()) return const [];
    return (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList();
  }

  late Map<String, List<QuizQuestion>> banks;

  setUpAll(() {
    banks = {
      'offline': fromJson('assets/data/offline_questions.json'),
      'community': fromJson('assets/data/community_questions.json'),
      'editorial': fromJson('assets/data/editorial_questions.json'),
      'curated (Dart)': curatedQuestionBank,
    };
  });

  test('her kaynak yüklenebiliyor ve boş değil', () {
    banks.forEach((name, questions) {
      expect(questions, isNotEmpty, reason: '$name bankası boş yüklendi');
    });
  });

  test('hiçbir kaynakta sorulan terim şık olarak durmuyor', () {
    final quoted = RegExp(r'[«\x27"]([^«»\x27"]{2,60})[»\x27"]');
    final offenders = <String>[];

    banks.forEach((name, questions) {
      for (final question in questions) {
        if (question.type == QuestionType.trueFalse) continue;
        final terms = quoted
            .allMatches(question.prompt)
            .map((match) => match.group(1)!.trim().toLowerCase())
            .toSet();
        if (terms.isEmpty) continue;
        for (final answer in question.answers) {
          if (terms.contains(answer.trim().toLowerCase())) {
            offenders.add('$name/${question.id}: "$answer"');
            break;
          }
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'Sorulan terim şık olarak da duruyor: ${offenders.join(" | ")}',
    );
  });

  test('hiçbir kaynakta doğru cevap gövdede yazmıyor', () {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^\wçğıöşüîêû]+'), ' ').trim();

    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        if (question.type == QuestionType.trueFalse) continue;
        final answer = normalize(question.correctAnswer);
        if (answer.length < 4) continue;
        // Cevap, gövdede **bitişik bir sözcük dizisi** olarak aranır.
        //
        // Alt dizge araması "Melayê Cizîrî li kîjan bajarî jiya?" sorusunu
        // suçluyordu — cevap "Cizîr", gövdedeki sözcük "Cizîrî"; ikisi ayrı
        // sözcük. Dağınık sözcük araması ise tanım→terim sorularını
        // suçluyordu: "geliyê kûr û teng ê ku ava Zapê…" tanımı doğal olarak
        // "Geliyê Zapê" cevabının iki sözcüğünü de içerir, ama sırayla değil.
        // Gerçek sızıntı cevabın gövdede aynen yazmasıdır (2026-07-26).
        if (' ${normalize(question.prompt)} '.contains(' $answer ')) {
          offenders.add('$name/${question.id}: "${question.correctAnswer}"');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'Doğru cevap soru gövdesinde geçiyor: ${offenders.join(" | ")}',
    );
  });

  test('hiçbir kaynakta yabancı dilde çeldirici yok', () {
    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        final bad = policy.offLanguageDistractors(question);
        if (bad.isNotEmpty) offenders.add('$name/${question.id}: $bad');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Doğru cevaptan farklı dilde çeldirici: '
          '${offenders.take(6).join(" | ")}',
    );
  });

  test('hiçbir kaynakta doğru cevabı dil ele vermiyor', () {
    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        if (policy.answerIsGivenAwayByLanguage(question)) {
          offenders.add('$name/${question.id}');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Doğru cevap dil bakımından tek olan şık: '
          '${offenders.take(6).join(", ")}',
    );
  });

  test('her sorunun doğru cevabı şıkları arasında', () {
    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        if (!question.answers.contains(question.correctAnswer)) {
          offenders.add('$name/${question.id}');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'Cevapsız soru: ${offenders.join(", ")}',
    );
  });

  test('hiçbir soruda yinelenen şık yok', () {
    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        final unique = question.answers.map((a) => a.trim()).toSet();
        if (unique.length != question.answers.length) {
          offenders.add('$name/${question.id}');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'Aynı şık iki kez geçiyor: ${offenders.join(", ")}',
    );
  });

  test('Türkçe arayüzde açıklama Kurmancî kalmıyor', () {
    // 2026-07-26 ekran turu: ders akışında doğru cevaptan sonra açılan
    // "Açıklama · Zana" paneli, arayüz Türkçeyken Kurmancî metin
    // gösteriyordu. `getLocalizedExplanation(false)` Türkçe alan yoksa ham
    // metni olduğu gibi döndürür; 464 offline + 45 curated soruda o alan
    // hiç yoktu. Öğrenme alanının bütün değeri o paneldedir — okunamayan
    // açıklama, panelin hiç açılmamasından iyi değildir.
    //
    // Ölçüt `detectSentenceLanguage`: tırnak içindeki terimler cümlenin
    // dili değil konusudur, ölçmeden önce çıkarılır. Kalan birkaç bulgu
    // Kurmancî özel ad taşıyan Türkçe cümlelerdir; tavan onları kapsar.
    //
    // 2026-07-27: sayı 12'den 11'e indi. Biri gerçek kusurdu —
    // `offline_2201`in Türkçe açıklaması bozuk bir cümleydi ("herêma
    // Behdînannin ünlü dengbêjidir"): terim değişimi Türkçe iyelik ekiyle
    // çakışmıştı. Onarıldı ve soruya iki dilli açıklama verildi.
    const ceiling = 11;

    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        final turkish = question.getLocalizedExplanation(false);
        if (turkish.trim().isEmpty) continue;
        if (QuestionLanguagePolicy.detectSentenceLanguage(turkish) == 'ku') {
          offenders.add('$name/${question.id}');
        }
      }
    });

    expect(
      offenders.length,
      lessThanOrEqualTo(ceiling),
      reason:
          'Türkçe arayüzde Kurmancî açıklama arttı (${offenders.length} > '
          '$ceiling): ${offenders.take(6).join(", ")}',
    );
  });

  test('Kurmancî arayüzde açıklama Türkçe kalmıyor', () {
    // Bir önceki testin aynası. 2026-07-26: Türkçe açıklamalar
    // düzeltildikten sonra sonuç ekranında ters kusur göründü — Kurmancî
    // arayüzde 428 soruda Türkçe metin çıkıyordu. `explanationToKu` kural
    // motoru eşleşme bulamayınca metni `Şirove: <Türkçe>` diye sarıp
    // geçiyordu; sarmak çevirmek değildir.
    //
    // 301 metnin Kurmancî karşılığı yazıldı, 20'lik sözlük kalıbı için
    // kural eklendi. Taban sıfır: tek bir yeni Türkçe açıklama testi kırar.
    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        final kurmanci = question.getLocalizedExplanation(true);
        if (kurmanci.trim().isEmpty) continue;
        if (QuestionLanguagePolicy.detectSentenceLanguage(kurmanci) == 'tr') {
          offenders.add('$name/${question.id}');
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Kurmancî arayüzde Türkçe açıklama (${offenders.length}): '
          '${offenders.take(6).join(", ")}',
    );
  });
}
