import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Boşluk doldurma cevabının Türkçe klavyeyle YAZILABİLİR olduğunun bekçisi.
///
/// ## Kusur
///
/// `free_text_answer_matcher.dart` bilerek `î`yi `i`ye katlamaz: katlasa
/// `şêr` ile `ser` aynı yanıt sayılırdı ve soru anlamını yitirirdi. Bunun
/// yerine sözleşme şudur — "klavye kolaylığı gereken güvenli varyantlar
/// soru bazında `acceptedAnswers` içinde açıkça tanımlanır."
///
/// Sözleşme yazılmıştı, ikinci yarısı hiç uygulanmadı: 2026-08-12'de yirmi
/// sorunun yirmisinde de `acceptedAnswers` boştu ve on üçünün doğru cevabı
/// `î/ê/û` taşıyordu (`mirovekî`, `nêzîk`, `sûd`, …). Türkçe klavyede bu üç
/// harf **yoktur** — ne Q ne F düzeninde. Yani oyuncu doğru sözcüğü bilse
/// bile onu cihazına yazamıyor, `miroveki` yazıyor ve yanlış sayılıyordu.
///
/// Sessizdi çünkü hiçbir test cevabı KLAVYEDEN geçirmiyordu: model testleri
/// `acceptsAnswer('mirovekî')` diye kanonik yazımı deniyor, o da geçiyordu.
///
/// Katlama burada da yapılmaz. Yalnız inceltmeli üç sesli (`î ê û`) ASCII
/// karşılığına indirilir; `ş` ve `ç` Türkçe klavyede zaten vardır ve
/// dokunulmaz — `şêr` → `şer`, hâlâ `ser` değildir.
void main() {
  /// Türkçe klavyede bulunmayan harfler. `ş`, `ç`, `ı`, `ğ`, `ö`, `ü`
  /// bilerek dışarıda: onlar yazılabiliyor.
  const unreachable = {'î': 'i', 'ê': 'e', 'û': 'u'};

  String toTurkishKeyboard(String value) {
    var out = value;
    unreachable.forEach((from, to) => out = out.replaceAll(from, to));
    return out;
  }

  late List<QuizQuestion> blanks;

  setUpAll(() {
    blanks = QuestionBankLoader.instance.allQuestions
        .where((q) => q.type == QuestionType.fillInBlank)
        .toList();
  });

  test('boşluk doldurma bankası duruyor', () {
    expect(
      blanks.length,
      20,
      reason:
          'Boşluk doldurma soru sayısı değişti; bu bekçi yeni kayıtları da '
          'kapsamalı.',
    );
  });

  /// Soru, katlanan ünlünün KENDİSİNİ adıyla anıyor mu?
  ///
  /// «"û" ünlüsünü içeren sözcüğü doğru yaz» diyen bir soruda `sud`u kabul
  /// etmek, sorunun yasakladığı yazımı doğru saymaktır: oyuncu soruyu tam
  /// olarak yanlış yaparak geçer. Klavye kolaylığı burada kolaylık değil,
  /// sorunun iptalidir.
  bool asksForTheVowelItself(QuizQuestion q) {
    final text = '${q.prompt} ${q.promptTr ?? ''}';
    return unreachable.keys
        .where(q.correctAnswer.contains)
        .any((vowel) => text.contains('«$vowel»') || text.contains('"$vowel"'));
  }

  test('yazımı SORAN sorularda kolaylık varyantı yok', () {
    // Bu iki soru («sûd», «lêv») 2026-08-12'de tam bu yüzden varyantını
    // kaybetti: ikisi de "şu ünlüyü içeren sözcüğü doğru yaz" diyor.
    final offenders = <String>[];
    for (final q in blanks) {
      if (!asksForTheVowelItself(q)) continue;
      if (q.acceptedAnswers.isNotEmpty) {
        offenders.add(
          '${q.id}: soru «${q.correctAnswer}» yazımını sınıyor ama '
          '${q.acceptedAnswers} kabul ediliyor',
        );
      }
      final typed = toTurkishKeyboard(q.correctAnswer);
      if (typed != q.correctAnswer && q.acceptsAnswer(typed)) {
        offenders.add(
          '${q.id}: «$typed» kabul ediliyor — soru bunu yasaklıyor',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu sorularda kolaylık varyantı sorunun yerine geçiyor; oyuncu '
          'soruyu yanlış yaparak geçer:\n${offenders.join("\n")}',
    );
  });

  test('inceltmeli cevabın klavyeyle yazılabilir hâli kabul ediliyor', () {
    final offenders = <String>[];
    for (final q in blanks) {
      // Yazımı SORAN sorular dışarıda: onlarda varyant sorunun iptalidir.
      if (asksForTheVowelItself(q)) continue;
      final typed = toTurkishKeyboard(q.correctAnswer);
      if (typed == q.correctAnswer) continue;
      if (!q.acceptsAnswer(typed)) {
        offenders.add(
          '${q.id}: «${q.correctAnswer}» yazılabilir hâli «$typed» '
          'reddediliyor',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu soruların doğru cevabı Türkçe klavyede yazılamıyor ve varyantı '
          'da tanımlı değil:\n${offenders.join("\n")}',
    );
  });

  test('varyant Türkçe turda da geçerli', () {
    // `hasTurkishTranslation`, `acceptedAnswers` dolup `acceptedAnswersTr`
    // boş kalırsa soruyu çevrilmemiş sayar ve TR oyuncu Kurmancî metin
    // görür. Yani varyantı tek dile yazmak, çeviriyi SESSİZCE düşürür.
    final offenders = <String>[];
    for (final q in blanks) {
      if (asksForTheVowelItself(q)) continue;
      final typed = toTurkishKeyboard(q.correctAnswer);
      if (typed == q.correctAnswer) continue;
      if (!q.localized(isKu: false).acceptsAnswer(typed)) {
        offenders.add('${q.id}: TR turda «$typed» reddediliyor');
      }
      if (!q.hasTurkishTranslation) {
        offenders.add('${q.id}: varyant eklenince çeviri kapsamı düştü');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('varyant kanonik yazımın yerini almıyor', () {
    // Varyant bir kolaylıktır, bir ikinci doğru yazım değil: ekranda ve
    // açıklamada her zaman kanonik biçim durur.
    for (final q in blanks) {
      expect(
        q.acceptsAnswer(q.correctAnswer),
        isTrue,
        reason: '${q.id}: kanonik yazım kabul edilmiyor',
      );
      for (final accepted in q.acceptedAnswers) {
        expect(
          accepted,
          isNot(equals(q.correctAnswer)),
          reason: '${q.id}: varyant kanonik yazımın kopyası',
        );
        expect(
          toTurkishKeyboard(q.correctAnswer),
          accepted,
          reason:
              '${q.id}: varyant, cevabın klavye karşılığı değil — elle '
              'yazılmış bir eşanlamlı buraya girmemeli, `acceptedAnswers` '
              'yalnız yazım kolaylığı içindir.',
        );
      }
    }
  });
}
