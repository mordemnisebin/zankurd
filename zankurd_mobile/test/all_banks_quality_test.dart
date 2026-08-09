import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/content_quality_policy.dart';
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

  /// Şık biçimini varsayan kontroller için bankalar.
  ///
  /// `wordOrdering` sorularında `answers` bir şık listesi değil, cümlenin
  /// **kelime havuzudur**; `correctAnswer` ise kurulmuş cümlenin kendisi
  /// ("Ez diçim malê"). "Doğru cevap şıklar arasında" gibi kurallar bu tipe
  /// uygulanınca sekiz sorunun sekizi de kusurlu görünür — oysa havuz ile
  /// cümlenin örtüşmesi `QuestionContentPolicy.validate` tarafından
  /// `word_ordering_content_test.dart` içinde zaten doğrulanıyor. Dil ve
  /// açıklama kontrolleri tipten bağımsızdır; onlar `banks` üzerinde kalır.
  late Map<String, List<QuizQuestion>> optionBanks;

  setUpAll(() {
    banks = {
      'offline': fromJson('assets/data/offline_questions.json'),
      'community': fromJson('assets/data/community_questions.json'),
      'editorial': fromJson('assets/data/editorial_questions.json'),
      'sentence': fromJson('assets/data/sentence_building_questions.json'),
      'expansion': fromJson('assets/data/expansion_2026_08_questions.json'),
      'sourceFirst': fromJson(
        'assets/data/source_first_2026_08_questions.json',
      ),
      'curated (Dart)': curatedQuestionBank,
    };
    optionBanks = {
      for (final entry in banks.entries)
        entry.key: entry.value
            .where((q) => q.type != QuestionType.wordOrdering)
            .toList(growable: false),
    };
  });

  test('her kaynak yüklenebiliyor ve boş değil', () {
    banks.forEach((name, questions) {
      expect(questions, isNotEmpty, reason: '$name bankası boş yüklendi');
    });
  });

  test(
    'runtime yükleyici aynı sıra ve kapsamla dokuz kaynağı birleştiriyor',
    () {
      final expected = [
        ...curatedQuestionBank,
        ...fromJson('assets/data/sentence_building_questions.json'),
        ...fromJson('assets/data/community_questions.json'),
        ...fromJson('assets/data/editorial_questions.json'),
        ...fromJson('assets/data/offline_questions.json'),
        // 2026-08-06 genişletmesi. Sıra `questionBankAssets` ile aynı olmalı:
        // aynı id birden çok bankada varsa SONRAKİ kazanır.
        ...fromJson('assets/data/expansion_2026_08_questions.json'),
        ...fromJson('assets/data/source_first_2026_08_questions.json'),
        // 2026-08-07: çıkarılan döngüsel kategori sorularının görsellerine
        // yazılan sorular. Bu liste `questionBankAssets` ile ayrışırsa test
        // uzunlukta düşer — dosyanın başındaki ders tam olarak budur.
        ...fromJson('assets/data/visual_2026_08_07_questions.json'),
        ...fromJson('assets/data/restore_2026_08_07_questions.json'),
      ];

      final runtime = QuestionBankLoader.instance.allQuestions;
      expect(runtime, hasLength(expected.length));
      expect(runtime.map((q) => q.id), equals(expected.map((q) => q.id)));
    },
  );

  test('hiçbir kaynakta sorulan terim şık olarak durmuyor', () {
    final quoted = RegExp(r'[«\x27"]([^«»\x27"]{2,60})[»\x27"]');
    final offenders = <String>[];

    optionBanks.forEach((name, questions) {
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
    optionBanks.forEach((name, questions) {
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
    optionBanks.forEach((name, questions) {
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
    optionBanks.forEach((name, questions) {
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
    optionBanks.forEach((name, questions) {
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
    optionBanks.forEach((name, questions) {
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
    //
    // 2026-07-30: cümle kurma bankası bu kontrole ilk kez bağlanınca sayı
    // 13'e çıktı. Gelen iki kayıt (`wo-ku-001`, `wo-ku-002`) tek tek okundu
    // ve ikisi de Türkçe cümle: "Kurmancî'de nesne fiilden önce gelir: özne
    // + nesne + fiil." Dilbilgisi öğreten açıklama doğası gereği Kurmancî
    // örnek sözcükle doludur; ölçüt onları dilin kendisi sayıyor. Tavan tam
    // olarak bu sınıfı kapsamak için var — kusur değil, ölçütün sınırı.
    //
    // 2026-07-30 (ikinci geçiş): sayı 13'ten 8'e indi ve iniş ölçütün
    // kendisinden geldi. `her`, `ne`, `de` üçü de iki dilde aynı yazılır
    // ama yalnız Kurmancî listesindeydi; "Her sabah tarlaya gider." gibi
    // düpedüz Türkçe cümleler Kurmancî sayılıyordu. Belirsiz sözcükler
    // artık hiçbir yöne sayılmıyor ve parantez içi karşılıklar da terim
    // sayılıp atılıyor — kardeş bekçi zaten öyle yapıyordu.
    //
    // Ölçüt keskinleşince iki gerçek kusur maskesini yitirdi:
    // `offline_7011` Kurmancî gövdeye dört Türkçe şık taşıyordu ve
    // `offline_2349`un tek açıklaması Türkçeydi — kural motoru eşleşme
    // bulamayınca onu "Şirove: " önekiyle Kurmancî yuvaya basıyordu.
    //
    // Kalan 8, Kurmancî özel ad ya da örnek sözcük taşıyan Türkçe
    // cümlelerdir (Mem û Zîn'i, Xoybûn, yek/du/sê…).
    const ceiling = 8;

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

  // 2026-07-30: bankanın %42'si on dört soru kalıbından geliyordu ve en sık
  // tek kalıp ("Rast e an şaş e: …") tek başına %15,6'ydı. Sorular bu yüzden
  // "yapay" hissettiriyordu: oyuncu arka arkaya beş soru çözünce beşinin de
  // aynı cümleyle başladığını görüyordu.
  //
  // Ölçüt bir mandal, hedef değil. Yeni soru yazan kişi tıkanmış kalıbı
  // kullanmakta serbest — ama yığılmayı **artıramaz**. Oran düştükçe tavan
  // da düşürülür; bu, uzunluk ve pozisyon mandallarıyla aynı mantık.
  test('soru kalıpları tek bir açılışta yığılmıyor', () {
    final opening = <String, int>{};
    var total = 0;
    banks.forEach((name, questions) {
      for (final question in questions) {
        final stripped = question.prompt.replaceAll(RegExp('«[^»]*»'), 'X');
        final words = stripped.split(RegExp(r'\s+')).take(4).join(' ');
        opening[words] = (opening[words] ?? 0) + 1;
        total++;
      }
    });

    final ranked = opening.values.toList()..sort((a, b) => b.compareTo(a));
    final topOne = ranked.first / total * 100;
    final topFourteen = ranked.take(14).fold(0, (a, b) => a + b) / total * 100;

    expect(
      topOne,
      lessThanOrEqualTo(16.0),
      reason:
          'Tek kalıp soruların %${topOne.toStringAsFixed(1)}\'ini taşıyor; '
          'oyuncu aynı cümleyi arka arkaya görüyor.',
    );
    expect(
      topFourteen,
      lessThanOrEqualTo(43.0),
      reason:
          'En sık on dört kalıp %${topFourteen.toStringAsFixed(1)} — '
          'gövde çeşitliliği azalıyor.',
    );
  });

  // 2026-07-30: altı soruda gövde Kurmancî ama şıkların **dördü de** Türkçeydi.
  // Kurmancî turu oynayan oyuncu Kurmancî bir soru okuyup Türkçe dört şıkla
  // karşılaşıyordu.
  //
  // Bu kusur mevcut iki dil bekçisinden de kaçıyordu, çünkü ikisi de
  // *uyumsuzluk* arıyor: `offLanguageDistractors` doğru cevaptan farklı dilde
  // şık arar, `answerIsGivenAwayByLanguage` dilce yalnız kalan şıkkı arar.
  // Dördü birden Türkçe olunca küme tutarlıdır — tutarlı ama yanlış dilde.
  // Onarım `tool/fix_turkish_only_option_sets.py` ile yapıldı.
  //
  // İstisna: soru zaten "bi Tirkî çi ne?" diye soruyorsa Türkçe cevap doğru
  // olanıdır (ör. `offline_2009`, `offline_tek_0002`, `offline_tek_0051`).
  test('Kurmancî soruda bütün şıklar Türkçe değil', () {
    final asksForTurkish = RegExp(
      r'bi\s+tirkî|tirkî\s+çi|di\s+tirkî\s+de',
      caseSensitive: false,
    );

    final offenders = <String>[];
    optionBanks.forEach((name, questions) {
      for (final question in questions) {
        final ku = question.localized(isKu: true);
        if (asksForTurkish.hasMatch(ku.prompt)) continue;
        final allTurkish = ku.answers.every(
          (option) =>
              QuestionLanguagePolicy.detectSentenceLanguage(option) == 'tr',
        );
        if (allTurkish) offenders.add('$name/${question.id}');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Kurmancî soru, tamamı Türkçe şık kümesi: ${offenders.join(", ")}',
    );
  });

  // 2026-07-30: banka üretilirken aynı olgu birden çok kalıp cümleyle
  // yazılmış. Oyuncu için bunlar iki soru değil, bir sorunun iki kopyası:
  //
  //     "Derbarê 'tembûr' de vebijêrka rast kîjan e?"        → aynı cevap
  //     "Ji bo Muzîkê derbarê 'tembûr' de vebijêrka rast…?"  → aynı cevap
  //
  // Böyle 289 fazladan kayıt vardı (1.601 → 1.312, %18). Kategoriyi bitirmeye
  // çalışan oyuncu aynı bilgiyi iki kez görüyordu; banka büyük görünüyor ama
  // öğrettiği şey o kadar değildi.
  //
  // Ölçüt tipe duyarlı: aynı sözcüğü hem görselden hem çeviriden sormak
  // kopya değil, iki ayrı alıştırmadır — `offline_0005` (görsel «av») ile
  // `offline_5031` (çeviri «av») bu yüzden ikisi de durur.
  //
  // Tek bilinçli istisna Teknolojî'de: «malper» çifti duruyor, çünkü onu da
  // silmek kategoriyi 40 soruluk yayın tabanının altına düşürüp kategoriyi
  // tümden gizletirdi (bkz. `category_visibility_test`). Bir Teknolojî
  // sorusu daha yazıldığında kopya kaldırılmalı.
  test('aynı olgu aynı biçimde iki kez sorulmuyor', () {
    final quoted = RegExp('[«\'"]([^«»\'"]{2,60})[»\'"]');
    final groups = <String, List<String>>{};

    optionBanks.forEach((name, questions) {
      for (final question in questions) {
        final term = quoted.firstMatch(question.prompt)?.group(1);
        if (term == null) continue;
        final key = [
          name,
          question.category,
          question.type.name,
          term.trim().toLowerCase(),
          question.correctAnswer.trim().toLowerCase(),
        ].join(' ');
        groups.putIfAbsent(key, () => []).add(question.id);
      }
    });

    final duplicates = groups.values.where((ids) => ids.length > 1).toList();
    final extras = duplicates.fold(0, (sum, ids) => sum + ids.length - 1);

    expect(
      extras,
      lessThanOrEqualTo(1),
      reason:
          'Aynı olgu birden çok kez soruluyor (fazladan $extras kayıt): '
          '${duplicates.take(5).map((ids) => ids.join(" = ")).join(" | ")}',
    );
  });

  // 2026-07-30 dil taraması: oyuncuya gösterilen soru ve şıklarda Kurmancîde
  // **var olmayan** sözcükler duruyordu. İki ayrı kaynaktan geliyorlardı:
  //
  // * `curated_question_bank.dart`ın Paradigma/Siyaset kümesi — "Fakltîzm",
  //   "Demorkrasîxerbirîna", "Kîmoka zîvkirî", "Kom-xwebûn rêxistin". Yedi
  //   soru inceleme kuyruğuna alındı (bkz. `_bozukKurmanciBekliyor`).
  // * `offline_questions.json` — "ava bile ne li ser qezencê": `bile` Türkçe
  //   sözcük, Kurmancî fiil `dibe`. Aynı bozuk şık 11 soruda tekrarlanıyordu
  //   ve birinde **doğru cevabın** içindeydi.
  //
  // Bu kusur sınıfı sinsidir: harf bekçisi göremez (harfler Kurmancî),
  // dil bekçisi göremez (cümle Kurmancî sayılır), yalnız sözcüğün kendisi
  // uydurmadır. Kurmancî öğreten bir üründe oyuncuya uydurma sözcüğü doğru
  // cevap diye göstermek, soruyu hiç sormamaktan kötüdür.
  test('oyuncuya gösterilen metinde bozuk Kurmancî sözcük yok', () {
    const garbled = <String>[
      'demorka', 'demorkra', // demokratîk
      'ava bile', // ava dibe
      'şûnartî', 'Kom-xwebûn', 'Kîmoka', 'Bakurûrê', 'Barsanî',
      'Bikarhnêrîn', 'Hukmêkerek', 'Fakltîzm', 'Fermendîzm',
      'Medyatîkdemokrasî', 'dihundirîne', 'endamentên', 'rihevketa',
      'rêxistinbranî', 'peydexandî', 'alîserdestiyê', 'Rojê nû',
    ];
    const policy = ContentQualityPolicy();

    final offenders = <String>[];
    banks.forEach((name, questions) {
      for (final question in questions) {
        // Kuyrukta bekleyen kayıtlar oyuncuya çıkmaz; kural onlar için değil.
        if (!policy.isEligible(question.metadata)) continue;
        final visible = [
          question.prompt,
          ...question.answers,
          question.correctAnswer,
        ].join(' ').toLowerCase();
        for (final word in garbled) {
          if (visible.contains(word.toLowerCase())) {
            offenders.add('$name/${question.id}: "$word"');
          }
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason:
          'Oynanabilir soruda uydurma Kurmancî sözcük:\n'
          '${offenders.join("\n")}',
    );
  });
}
