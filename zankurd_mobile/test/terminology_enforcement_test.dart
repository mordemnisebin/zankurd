import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Bloke Kurmancî teknik terim, sorunun HİÇBİR görünür alanında bulunamaz.
///
/// ## Kusur
///
/// 2026-08-06'da kendi source-first pilotuma terminoloji sözleşmesini
/// uygulayınca beş sorunun üçü düştü:
///
///     sf_tech_0002  şîfre            çeldiricide: "Şîfre çewt e"
///     sf_tech_0003  şîfre            çeldiricide: "Şîfre pêwîst e"
///     sf_tech_0005  dane, înternet   promptKu ve explanationKu
///
/// İkisinde ihlal ÇELDİRİCİDEYDİ; soru kökü ve doğru cevap tertemizdi. Bir
/// soru, yanlış seçeneğin yanlış olması sebebiyle sözleşmeden muaf değildir:
/// oyuncu o metni de okur ve oradan da öğrenir.
///
/// Bu, aynı oturumda ikinci kez çıkan ders. Self-labelled distractor
/// kusurunda da kural yalnız baktığı kanalı korumuş, çeldiriciyi görmemişti.
/// Bekçi bu yüzden promptKu, dört seçeneğin TAMAMI, explanationKu ve varsa
/// hintKu üzerinde çalışır.
void main() {
  late Set<String> blocked;
  late List<Map<String, dynamic>> staged;

  setUpAll(() {
    final g =
        jsonDecode(
              File(
                'docs/content/terminology/zankurd_project_glossary_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final concepts = (g['concepts'] as List).cast<Map<String, dynamic>>();
    // Bir SÖZCÜK birden çok conceptId'de olabilir: `şîfre` hem
    // password (açık) hem encryption (bloke) kaydında geçiyor. Sözcüğü
    // yalnız bloke kayda bakıp yasaklamak, açık anlamıyla yazılmış
    // soruyu da düşürür — 2026-08-06'da NIST parola batch'inde tam bu
    // oldu. Doğru ölçü: sözcük HİÇBİR kayıtta açık değilse bloke sayılır.
    final allowedWords = {
      for (final c in concepts)
        if (c['approvedForQuestionAuthoring'] == true &&
            c['projectPreferredKurmanji'] != null)
          c['projectPreferredKurmanji'] as String,
    };
    blocked = {
      for (final c in concepts)
        if ((c['projectAuthoringStatus'] as String).startsWith(
          'AUTHORING_BLOCKED',
        ))
          if (c['projectPreferredKurmanji'] != null &&
              !allowedWords.contains(c['projectPreferredKurmanji']))
            c['projectPreferredKurmanji'] as String,
    };
    staged =
        (jsonDecode(
                  File(
                    'docs/content/source_first_expansion_2026_08/technology_pilot/technology_pilot_claims.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
  });

  /// Sorunun oyuncuya görünen BÜTÜN Kurmancî metni.
  List<String> visibleKurmanji(Map<String, dynamic> q) => [
    q['promptKu'] as String? ?? '',
    ...((q['answersKu'] as List?) ?? const []).cast<String>(),
    q['explanationKu'] as String? ?? '',
    q['hintKu'] as String? ?? '',
  ];

  /// Terimin bir SÖZCÜK olarak geçip geçmediği.
  ///
  /// Regex kullanılmıyor: Dart'ta `\b` ASCII tabanlıdır ve `ş`, `î`, `û`
  /// harflerinden önce eşleşmez — ilk yazımda kural "Şîfre çewt e"
  /// içindeki ihlali GÖRMEDİ ve bunu negatif fixture yakaladı. Unicode
  /// bayrağıyla da güvenilir sonuç alınamadı, bu yüzden sınır elle
  /// kontrol edilir: harf olmayan bir karakterle başlamalı.
  bool containsTerm(String field, String term) {
    final haystack = field.toLowerCase();
    final needle = term.toLowerCase();
    var from = 0;
    while (true) {
      final i = haystack.indexOf(needle, from);
      if (i < 0) return false;
      final before = i == 0 ? '' : haystack[i - 1];
      final isLetterBefore =
          before.isNotEmpty &&
          before != ' ' &&
          RegExp('[a-zçğıöşüêîûapzA-Z]').hasMatch(before);
      if (!isLetterBefore) return true;
      from = i + 1;
    }
  }

  List<String> offendersIn(Map<String, dynamic> q) {
    final hits = <String>[];
    for (final field in visibleKurmanji(q)) {
      for (final term in blocked) {
        if (containsTerm(field, term)) hits.add('$term -> "$field"');
      }
    }
    return hits;
  }

  test('sözleşme boş küme üzerinde çalışmıyor', () {
    // Bloke terim listesi ya da staged soru listesi boşalırsa asıl test
    // sessizce yeşile döner. O yüzden ikisi de burada sabitlenir.
    expect(blocked, isNotEmpty, reason: 'bloke terim listesi boş');
    expect(staged, isNotEmpty, reason: 'staged soru listesi boş');
    // Bu iki terim HÂLÂ bloke. `dane` bir zamanlar buradaydı; Wîkîferheng
    // girdisi okununca açıldı ve bu test onu yakaladı — sözleşme değişince
    // testin sessizce geçmemesi tam olarak istenen davranış.
    // `şîfre` bir zamanlar buradaydı; password anlamı açılınca listeden
    // çıktı ve bu test onu yakaladı. Hâlâ hiçbir anlamı açık olmayanlar:
    // Liste zamanla küçülüyor: `şîfre`, `dane`, `înternet`, `tor` sırayla
    // açıldı ve her açılışta bu assertion kırılıp beni uyardı. Şu an hiçbir
    // anlamı açık olmayan tek sözcük `sepan` — Wîkîferheng girdisi
    // 'uygulama' anlamını desteklemiyor.
    expect(blocked, contains('sepan'));
  });

  test('staged sorularda bloke terim yok', () {
    final offenders = <String>[];
    for (final q in staged) {
      final hits = offendersIn(q);
      if (hits.isNotEmpty) {
        offenders.add('${q['questionId']}: ${hits.join("; ")}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Bloke Kurmancî terim görünür alanda:\n${offenders.join("\n")}',
    );
  });

  test('bekçi çeldiricideki bloke terimi yakalıyor (negatif fixture)', () {
    // Gerçek düşen kaydın biçimi: ihlal YALNIZ çeldiricide.
    final bad = <String, dynamic>{
      'questionId': 'fixture_bad',
      'promptKu': 'Di HTTPê de koda 404 çi nîşan dide?',
      'answersKu': [
        'Çavkaniya xwestî nehat dîtin',
        'Daxwaz bi serkeftî qediya',
        'Sepan nehatiye barkirin',
        'Girêdan hêdî ye',
      ],
      'explanationKu': 'Koda 404 tê wateya ku çavkanî nehat dîtin.',
    };
    expect(
      offendersIn(bad),
      isNotEmpty,
      reason: 'çeldiricideki "sepan" yakalanmalıydı',
    );
  });

  test('bekçi temiz kaydı geçiriyor (pozitif fixture)', () {
    final good = <String, dynamic>{
      'questionId': 'fixture_good',
      'promptKu': 'URL bi giranî çi diyar dike?',
      'answersKu': [
        'Rengê rûpelê',
        'Mezinahiya wêneyan',
        'Navnîşana çavkaniyekê',
        'Dema xwendinê',
      ],
      'explanationKu': 'URL navnîşana çavkaniyekê ye.',
    };
    expect(offendersIn(good), isEmpty);
  });
}
