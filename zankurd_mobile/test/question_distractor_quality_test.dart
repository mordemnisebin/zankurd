import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'support/offline_bank_fixture.dart';

/// 2026-07-24 editoryal denetim.
///
/// Otomatik üretilmiş havuzda çeldiriciler başka soruların cevaplarından
/// rastgele çekilmişti. Sonuç: "Urartû navenda xwe li kîjan derê bû?"
/// sorusunun şıkları arasında "16. yüzyıl" ve "20. yüzyıl" duruyordu —
/// doğru cevap tür uyumsuzluğundan bakar bakmaz belli oluyordu.
///
/// 106 soru düzeltildi. Bu testler kusurun geri dönmesini engeller.
final _yearLike = RegExp(
  r'(\b\d{3,4}\b|yüzyıl|sedsal|y\.y\.|M\.Ö|b\.z\.)',
  caseSensitive: false,
);

bool _isYearLike(String value) => _yearLike.hasMatch(value);

/// Boş kalıp açıklamalar: soruyu açıklamak yerine kendini tekrar ederler.
final _hollowExplanation = RegExp(
  r"^(Ev ravekirin têgeha |Ev ravekirin bi )|"
  r"( di vê kategoriyê de têgeheke giring e\.$)|"
  r"( de bi vê ravekirinê tê bikaranîn\.$)",
);

/// Uygulamanın kendi veri şemasını soran "meta" sorular kullanıcıya
/// gösterilecek içerik değildir. 2026-07-24 denetiminde 16 tanesi
/// bulundu ve kaldırıldı (ör. "Di bankeke pirsan de qada 'etîket' ji bo
/// kîjan karê teknîkî ye?", "Wêneya bi etîketa 'govend' bi kîjan qadê re
/// têkildar e?"). Bu test yenilerinin sızmasını engeller.
final _appMeta = RegExp(
  r"(banke?ke? pirsan|banka pirsan|qada .etîket|Etîketa '.+' ya di wêneyê|"
  r"Wêneya bi etîketa)",
  caseSensitive: false,
);

void _metaGuardTests(List<QuizQuestion> Function() getBank) {
  test('soru bankası kendi şemasını sormaz', () {
    final offenders = getBank()
        .where((q) => _appMeta.hasMatch(q.prompt))
        .map((q) => '${q.id}: ${q.prompt}')
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Uygulama/veri şeması hakkında soru eklendi: '
          '${offenders.take(3).join(" | ")}',
    );
  });
}

void main() {
  late List<QuizQuestion> offlineQuestionBank;

  setUpAll(() {
    offlineQuestionBank = loadOfflineBankFromJson();
  });

  _metaGuardTests(() => offlineQuestionBank);
  test('çeldiriciler doğru cevapla aynı türden olmalı (tarih/tarih-dışı)', () {
    final offenders = <String>[];
    for (final q in offlineQuestionBank) {
      if (q.type == QuestionType.trueFalse || q.answers.length < 4) continue;
      final correctIsYear = _isYearLike(q.correctAnswer);
      for (final answer in q.answers) {
        if (answer == q.correctAnswer) continue;
        if (_isYearLike(answer) != correctIsYear) {
          offenders.add('${q.id}: "$answer" ↔ "${q.correctAnswer}"');
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Tür uyumsuz çeldirici eklendi (${offenders.length} soru). '
          'İlk örnekler: ${offenders.take(5).join(" | ")}',
    );
  });

  test('açıklamalar boş kalıp değil, gerçek bilgi taşır', () {
    // 960 boş kalıp açıklama terim↔tanım bilgisiyle değiştirildi.
    // Bu sayı yalnızca AZALMALIDIR.
    const baseline = 0;
    final hollow = offlineQuestionBank
        .where((q) => _hollowExplanation.hasMatch(q.explanation.trim()))
        .map((q) => q.id)
        .toList();

    expect(
      hollow.length,
      lessThanOrEqualTo(baseline),
      reason:
          'Kendini tekrar eden açıklama eklendi: '
          '${hollow.take(5).join(", ")}',
    );
  });

  test('dolu bırakılan açıklama gerçekten bilgi taşıyacak uzunlukta', () {
    // Bu test önce *her* sorunun açıklaması olmasını şart koşuyordu. 2026-07-25
    // canlı denetiminde bunun ters teptiği görüldü: açıklaması olmayan sorulara
    // "…kategorisinde ele alınır" gibi dolgu cümleler yazılmıştı ve uygulama
    // bunlar için "Açıklama · Zana" panelini açıp hiçbir şey öğretmiyordu.
    //
    // Boş açıklamada panel hiç açılmaz (bkz. `_ExplanationBox`), yani
    // "öğretmeyen panel" yerine "panel yok" olur — sessiz ama dürüst. Kural
    // bu yüzden tersine çevrildi: boş bırakmak serbest, dolu bırakıp
    // hiçbir şey söylememek yasak.
    //
    // Dolgu kalıplarının geri sızmasını `explanation_quality_guard_test.dart`
    // ayrıca engeller.
    final hollowButPresent = offlineQuestionBank
        .where((q) {
          final text = q.explanation.trim();
          return text.isNotEmpty && text.length < 12;
        })
        .map((q) => q.id)
        .toList();

    expect(
      hollowButPresent,
      isEmpty,
      reason:
          'Açıklama var ama 12 karakterden kısa; panel açılır, bilgi vermez: '
          '${hollowButPresent.take(10).join(", ")}',
    );
  });

  test('doğru cevap sorunun gövdesinde yazmıyor', () {
    // 2026-07-26 denetimi. İki ayrı üretim hatası aynı sonucu veriyordu:
    //
    //   "Wêneya 'Newroz' di Çandê de dikeve kîjan kategoriyê?" → ✓ Çand
    //   "Ev wêne ji bo \"çiya\" e: berambera rast kîjan e?"     → ✓ çiya
    //
    // Birincisinde kategori adı gövdede geçiyor, ikincisinde doğru cevap
    // sorulan terimin kendisi. Her ikisinde de soru bilgi ölçmüyor; okuma
    // ölçüyor. 9 + 5 soru düzeltildi.
    //
    // Doğru/yanlış soruları hariç: onlarda gövde zaten iddianın kendisidir,
    // cevap "Rast"/"Şaş" olduğu için örtüşme anlamsızdır.
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^\wçğıöşüîêû]+'), ' ').trim();

    final offenders = offlineQuestionBank
        .where((q) => q.type != QuestionType.trueFalse)
        .where((q) {
          final answer = normalize(q.correctAnswer);
          // Çok kısa cevaplar ("av", "roj") gövdede rastlantıyla geçebilir.
          if (answer.length < 4) return false;
          // Bitişik sözcük dizisi aranır; "Cizîrî" gövdesi "Cizîr" cevabını
          // sızdırmış sayılmamalı, tanım içindeki dağınık sözcükler de.
          return ' ${normalize(q.prompt)} '.contains(' $answer ');
        })
        .map((q) => '${q.id}: "${q.correctAnswer}"')
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Doğru cevap soru gövdesinde geçiyor: ${offenders.take(5).join(" | ")}',
    );
  });

  test('Türkçe açıklama gerçekten Türkçe — çerçeve çevirisi yetmez', () {
    // 2026-07-26 denetimi: 646 sorunun `explanationTr` alanı doluydu ama
    // 567'sinde yalnız çerçeve çevrilmişti; tanım Kurmancî bırakılmıştı.
    //
    //   KU: «ergatîf» tê vê wateyê: avahiya rêzimanî ya ku kirdeya …
    //   TR: «ergatîf» şu anlama gelir: avahiya rêzimanî ya ku kirdeya …
    //
    // Türkçe arayüzdeki oyuncu için bu, açıklamanın hiç olmamasından
    // kötüdür: çevrilmiş görünür, okunmaz. Ölçüt tanımın kendisidir —
    // öğretilen terim `«»` içinde Kurmancî kalır, gövde çevrilmiş olmalıdır.
    // 80 benzersiz tanım çevrildi (`tool/translate_definitions.py`).
    final kuBody = RegExp(r'tê vê wateyê: (.+?)(?=$|\n)');
    final trBody = RegExp(r'şu anlama gelir: (.+?)(?=$|\n)');

    final untranslated = <String>[];
    for (final question in offlineQuestionBank) {
      final ku = question.explanationKu;
      final tr = question.explanationTr;
      if (ku == null || tr == null) continue;
      final kuMatch = kuBody.firstMatch(ku);
      final trMatch = trBody.firstMatch(tr);
      if (kuMatch == null || trMatch == null) continue;
      if (kuMatch.group(1)!.trim() == trMatch.group(1)!.trim()) {
        untranslated.add(question.id);
      }
    }

    expect(
      untranslated,
      isEmpty,
      reason:
          'Türkçe açıklamanın gövdesi Kurmancî ile birebir aynı '
          '(${untranslated.length} soru): ${untranslated.take(5).join(", ")}',
    );
  });

  test('cevap cümlenin olumsuzluğundan okunamıyor', () {
    // 2026-07-26 denetimi. 444 doğru/yanlış sorusunun 219'u tek bir üretim
    // kalıbındandı: "X, <kategori> alanında geçerli bir terim mi?"
    //
    //   'Cudi dağı' di çarçoveya erdnîgariyê de têgeheke derbasdar e.  → Rast
    //   'Zap suyu' bi tevahî li derveyî zanîna erdnîgariyê ye.         → Şaş
    //
    // Terim ne olursa olsun cevap aynı yerden geliyordu: cümle olumluysa
    // Rast, olumsuzsa Şaş — 219/219. Konuyu hiç bilmeyen biri de hepsini
    // doğru cevaplardı. Hiçbirinin açıklaması da yoktu, çünkü açıklanacak
    // bilgi yoktu. Tamamı bankadan çıkarıldı
    // (`tool/drop_polarity_questions.py`).
    const negativeMarkers = [
      'qet nayê bikaranîn',
      'bêwate',
      'tune ye',
      'li derveyî',
      'nayê zanîn',
      'têgeheke çêkirî',
      'yer almaz',
      'aîdî qadên derveyî',
      'nayê bikaranîn',
    ];
    const positiveMarkers = [
      'têgeheke derbasdar',
      'yek ji mijaran e',
      'rast û naskirî',
      'sernavek rast',
      'watedar e',
      'gerçek bir terimdir',
      'bilinen bir konudur',
      'beşek ji zanîna',
      'têgeheke rast',
      'têgihek derbasdar',
    ];

    final offenders = offlineQuestionBank
        .where((q) => q.type == QuestionType.trueFalse)
        .where((q) {
          final negative = negativeMarkers.any(q.prompt.contains);
          final positive = positiveMarkers.any(q.prompt.contains);
          if (negative == positive) return false;
          return (positive && q.correctAnswer == 'Rast') ||
              (negative && q.correctAnswer == 'Şaş');
        })
        .map((q) => q.id)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Cevabı gövdenin olumluluğundan okunabilen doğru/yanlış sorusu '
          'eklendi (${offenders.length}): ${offenders.take(5).join(", ")}',
    );
  });

  test('şıklardan biri sorunun kendi terimi değil', () {
    // 2026-07-26 canlı denetimi. "Derbarê 'hewa' de ravekirina rast kîjan e?"
    // sorusunun şıkları: vadi · deşt · hava · **hewa**. Sorulan terimin
    // kendisi şık olarak duruyordu; ne tanım veriyor ne de eleme sağlıyor,
    // yalnız kafa karıştırıyor. İkisinde doğru cevap da terimin kendisiydi,
    // yani soru totolojiye dönüşmüştü. 7 soru düzeltildi.
    //
    // Doğru/yanlış hariç: orada gövde zaten terimi ve tanımını birlikte
    // verir, şıklar "Rast"/"Şaş"tır.
    final quoted = RegExp(r"[«']([^«»']{2,60})['»]");

    final offenders = <String>[];
    for (final question in offlineQuestionBank) {
      if (question.type == QuestionType.trueFalse) continue;
      final terms = quoted
          .allMatches(question.prompt)
          .map((match) => match.group(1)!.trim().toLowerCase())
          .toSet();
      if (terms.isEmpty) continue;
      for (final answer in question.answers) {
        if (terms.contains(answer.trim().toLowerCase())) {
          offenders.add('${question.id}: "$answer"');
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Sorulan terim şık olarak da duruyor: ${offenders.take(5).join(" | ")}',
    );
  });
}
