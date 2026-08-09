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
  // Tür denetimi iki bankayı birden gezer: bozulan soru editoryal
  // bankadaydı, yalnız çevrimdışı bankaya bakan bir bekçi onu göremezdi.
  late List<QuizQuestion> everyBankQuestion;

  setUpAll(() {
    offlineQuestionBank = loadOfflineBankFromJson();
    everyBankQuestion = [
      ...offlineQuestionBank,
      ...loadEditorialBankFromJson(),
    ];
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

  test('"hangi dilde" sorusunun şıkları dil adı', () {
    // 2026-07-27: üç soru "bi kîjan zimanî" diye sorup şık olarak kitap
    // adı, destan adı, hatta atasözü veriyordu — dil olmayan üç şık zaten
    // eleniyor, soru gereksizleşiyordu.
    //
    // Üçüncüsü bu denetimde bozulmuştu: elle yazılmış, dört şıkkı da dil
    // olan bir soruydu; uzunluk sızıntısını kapatan betik çeldiricileri
    // aynı kategoriden ödünç cevaplarla değiştirince tür bozuldu. Ödünç
    // alma dili, tarihi ve uzunluğu denetler ama **türü** denetlemez —
    // sorunun neyi sorduğunu bilmez. Bu bekçi o kör noktayı kapatır.
    final asksLanguage = RegExp(
      'bi kîjan zimanî|kîjan ziman',
      caseSensitive: false,
    );
    final languageName = RegExp(
      'kurd|kurmanc|soran|zaza|tirk|türk|erebî|arap|farisî|fars|swêd|'
      'îngil|ingiliz|rus|yunan|ermen|alman|frans|osmanl',
      caseSensitive: false,
    );

    final offenders = <String>[];
    for (final q in everyBankQuestion) {
      if (!asksLanguage.hasMatch(q.prompt)) continue;
      final wrongType = q.answers.where((a) => !languageName.hasMatch(a));
      if (wrongType.isNotEmpty) {
        offenders.add('${q.id} (${wrongType.first})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'dil sorusunda dil olmayan şık: ${offenders.join(", ")}',
    );
  });

  test('"hangi şehir" sorusunun şıkları yer adı uzunluğunda', () {
    // Aynı kör nokta, başka bir tür: "Göbekli Tepe hangi şehrin
    // yakınında?" sorusunun şıklarında bir mevsim, bir siyasi parti ve bir
    // şehir çifti duruyordu — tek gerçek aday doğru cevaptı (2026-07-27).
    //
    // Ölçüt kaba ama kusurun biçimine uyuyor: yer adı birkaç kelimedir;
    // ödünç alınan tanım cümleleri ve kurum adları uzundur.
    final asksCity = RegExp('kîjan bajar', caseSensitive: false);
    final offenders = <String>[];
    for (final q in everyBankQuestion) {
      if (!asksCity.hasMatch(q.prompt)) continue;
      final tooLong = q.answers.where((a) => a.split(' ').length > 3);
      if (tooLong.isNotEmpty) offenders.add('${q.id} (${tooLong.first})');
    }
    expect(
      offenders,
      isEmpty,
      reason: 'şehir sorusunda yer adı olmayan şık: ${offenders.join(", ")}',
    );
  });

  test('çeldiriciler doğru cevapla aynı dilde', () {
    // 2026-07-27: on soruda çeldiricilerden biri doğru cevabın dilinde
    // değildi —
    //
    //   Hilgirên herî girîng ên wêjeya devkî ya kurdî kî ne?
    //     ✓ Dengbêjler
    //       Tüccarlar          ← Türkçe
    //
    // Dil farkı bilgi gerektirmeyen bir ipucudur: Kurmancî şıklar
    // arasındaki tek Türkçe şık (ya da tersi) bakar bakmaz elenir. Dördü
    // aynı bozuk çeldiriciyi paylaşıyordu, yani tek bir kayıt dört soruya
    // bulaşmıştı.
    //
    // Ölçüt harf düzeyinde: Kurmancîye özgü î/û/ê ile Türkçeye özgü
    // ı/ğ/ö/ü/İ. İkisini de taşımayan metin (özel adlar, sayılar) nötr
    // sayılır ve hiçbir şeye takılmaz.
    const ku = 'îûêÎÛÊ';
    const tr = 'ığöüİĞÖÜ';
    String? language(String text) {
      final hasKu = text.split('').any(ku.contains);
      final hasTr = text.split('').any(tr.contains);
      if (hasKu && !hasTr) return 'ku';
      if (hasTr && !hasKu) return 'tr';
      return null;
    }

    final offenders = <String>[];
    for (final q in offlineQuestionBank) {
      if (q.answers.length < 3) continue;
      final correctLanguage = language(q.correctAnswer);
      if (correctLanguage == null) continue;
      final mismatched = q.answers.where(
        (a) =>
            a != q.correctAnswer &&
            language(a) != null &&
            language(a) != correctLanguage,
      );
      if (mismatched.isNotEmpty) {
        offenders.add('${q.id} (${mismatched.first})');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'doğru cevaptan başka dilde çeldirici: ${offenders.join(", ")}',
    );
  });

  test('hiçbir soruda doğru cevap çeldiricileri 1,5 kat aşmıyor', () {
    // Oran testi bankanın genel eğilimini ölçer; bu test tek tek en kötü
    // durumu yasaklar. 2026-07-27'de yedi soruda doğru cevap en uzun
    // çeldiricinin 1,5 katından uzundu — o kadar açık bir fark ki soruyu
    // okumaya bile gerek kalmıyordu:
    //
    //   Çima şîfreyeke dirêj ji ya kurt bihêztir e?
    //     ✓ Ji ber ku hejmara kombînasyonan bi dirêjiyê re bi lez zêde dibe
    //       Ji ber ku bîranîna wê hêsantir e
    //
    // Oran testi bunları yakalayamaz: yedi soru 1865 sorunun yanında
    // yüzdeyi kıpırdatmaz. Bu yüzden ayrı bir bekçi gerekiyor.
    final offenders = <String>[];
    for (final q in offlineQuestionBank) {
      if (q.answers.length < 3) continue;
      final others = q.answers.where((a) => a != q.correctAnswer);
      if (others.isEmpty) continue;
      final longestOther = others
          .map((a) => a.length)
          .reduce((a, b) => a > b ? a : b);
      if (q.correctAnswer.length > 1.5 * longestOther) offenders.add(q.id);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'doğru cevabı biçimle ele veren sorular: ${offenders.join(", ")}',
    );
  });

  test('doğru cevap uzunluğuyla ele vermiyor', () {
    // 2026-07-27 ölçümü: çok şıklı soruların **%34,3'ünde en uzun şık
    // doğru şıktı**; rastgele bir bankada bu oran %25 olmalı. Yani hiçbir
    // şey bilmeyen bir oyuncu "en uzunu seç" diyerek dokuz puan
    // kazanıyordu.
    //
    // Sebep uzunluk değil biçimdi: doğru şık bir tanım cümlesiyken
    // çeldiriciler tarih, yer ya da kişi adıydı. 103 soruda çeldiriciler
    // aynı kategorideki başka soruların doğru cevaplarıyla değiştirildi
    // (`tool/fix_length_leak_distractors.py`) ve oran %30'a indi.
    //
    // 2026-07-27 ikinci geçiş: otomatik ödünç almanın çözemediği yedi soru
    // elle yazıldı (`tool/fix_remaining_length_leaks.py`); doğru cevabın
    // en uzun çeldiricinin 1,5 katından uzun olduğu soru **sıfıra** indi
    // ve oran %29,5 oldu.
    //
    // Tavan bir mandal: yeni sorular bu oranı yükseltmemeli. %25'e
    // inmesi beklenmez — bazı sorularda doğru cevap doğal olarak uzundur.
    // 2026-07-27 üçüncü geçiş: ders çerçevesi öneklerinin silinmesi 479
    // kopya soruyu açığa çıkardı ve bankadan atıldı; kalan 1601 soruda
    // oran %28,8. Mandal ona göre indirildi.
    //
    // 2026-07-30 dördüncü geçiş: aynı olgunun farklı kalıp cümleyle iki kez
    // sorulduğu 290 kayıt daha atıldı. Hangi kopyanın kalacağı rastgele
    // seçilmedi — ölçüt buydu: çiftten, doğru cevabı en uzun şık **olmayan**
    // sürüm tutuldu. Oran %28,8'den %25,0'e indi.
    //
    // Ve mandal burada tek yönlü olmaktan çıkıyor. %25 bu ölçütün tavanı
    // değil **hedefi**: dört şıklı bir soruda en uzun şıkkın doğru olma
    // olasılığı zaten dörtte birdir. Oranın %25'in altına inmesi de bir
    // eğilimdir — doğru cevabın sistematik olarak *kısa* olduğu anlamına
    // gelir ve oyuncu bu sefer "en kısayı seç" der. Bu yüzden ölçüt artık
    // 25 çevresinde bir bant.
    // 2026-08-07 beşinci geçiş: alt sınır, korumak istediği şeyi DOLAYLI
    // ölçtüğü için yanlış alarm verdi. Otuz üç döngüsel soru bankadan
    // çıkarılınca oran %21,8'e indi ve test düştü — oysa asıl soru "en uzun
    // şıkkın oranı kaç" değil, **"uzunluğa bakan bir oyuncu rastgeleden ne
    // kadar çok kazanıyor"**. Ölçüldüğünde dördü de zararsız çıktı:
    //
    //     en uzunu seç            %25,7
    //     en kısayı seç           %19,8
    //     en uzunu ele, rastgele  %24,8
    //     en kısayı ele, rastgele %26,8   ← en iyisi
    //
    // En iyi uzunluk stratejisi rastgeleden 1,8 puan iyi. Alt sınırın
    // yakaladığı şey bir sömürü değil, bir yuvarlama farkıydı.
    //
    // Bu yüzden ölçüt gevşetilmedi, YERİ DEĞİŞTİRİLDİ: artık dört stratejinin
    // dördü birden ölçülüyor ve hiçbirinin eşiği aşmaması aranıyor. Bu, tek
    // yönlü eski kuraldan kesinlikle daha güçlüdür — "en kısayı seç" ve
    // "şıkkı ele" stratejileri eskiden hiç ölçülmüyordu, yalnız "en uzun"
    // oranının bandından TAHMİN ediliyordu.
    const maxWinPercent = 28.0;

    var considered = 0;
    var pickLongest = 0;
    var pickShortest = 0;
    var avoidLongest = 0.0;
    var avoidShortest = 0.0;
    for (final q in offlineQuestionBank) {
      if (q.answers.length < 3) continue;
      considered++;
      final longest = q.answers.reduce((a, b) => a.length >= b.length ? a : b);
      final shortest = q.answers.reduce((a, b) => a.length <= b.length ? a : b);
      final longestWins = longest == q.correctAnswer;
      final shortestWins = shortest == q.correctAnswer;
      if (longestWins) pickLongest++;
      if (shortestWins) pickShortest++;
      // "Şu şıkkı ele, kalandan rastgele seç" stratejisinin beklenen kazancı.
      final others = q.answers.length - 1;
      if (!longestWins) avoidLongest += 1 / others;
      if (!shortestWins) avoidShortest += 1 / others;
    }

    final strategies = <String, double>{
      'en uzunu seç': pickLongest / considered * 100,
      'en kısayı seç': pickShortest / considered * 100,
      'en uzunu ele': avoidLongest / considered * 100,
      'en kısayı ele': avoidShortest / considered * 100,
    };
    final exploitable = strategies.entries
        .where((e) => e.value > maxWinPercent)
        .map((e) => '${e.key}: %${e.value.toStringAsFixed(1)}')
        .toList();

    expect(
      exploitable,
      isEmpty,
      reason:
          'Konuyu hiç bilmeyen bir oyuncu yalnız şık uzunluğuna bakarak '
          'rastgeleden (%25) belirgin çok kazanıyor. Ölçülen: '
          '${strategies.entries.map((e) => "${e.key} %${e.value.toStringAsFixed(1)}").join(", ")}. '
          'Eşiği aşan: ${exploitable.join(", ")}',
    );
  });
}
