import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Çand ve Muzîk source-first batch'lerinin bekçisi.
///
/// ## Niçin ayrı bir bekçi
///
/// Bu iki batch runtime bankasına HENÜZ bağlı değil (ortak havuz 49, eşik
/// 100). Bağlı olmayan içeriği hiçbir mevcut test görmüyor: `all_banks_*`
/// yalnız `assets/data/` altını, `terminology_enforcement_test` yalnız
/// teknoloji pilotunun claim dosyasını okuyor. Aradaki boşlukta duran 24
/// kayıt, aktivasyon gününe kadar hiç sınanmadan bekleyecekti — ve tam o
/// gün, kapı maliyetinin en yüksek olduğu anda sınanacaktı.
///
/// ## Bu turda yakalanan kusurlar
///
/// Üçü de yazım sırasında ölçümle çıktı, kapı kuralına burada bağlandı:
///
///     cevap pozisyonu   Çand'da 12 sorunun 6'sı üçüncü şıktaydı ve dördüncü
///                       şık HİÇ doğru değildi (%50 / %0). Konuyu bilmeyen
///                       oyuncu üçüncü şıkkı işaretleyerek kazanır.
///     uzunluk sinyali   Üç soruda doğru şık tek başına en uzundu; çeldiriciler
///                       aynı ayrıntı düzeyine çekildi.
///     kalıp yinelemesi  Beş yıl sorusu neredeyse aynı kökü paylaşıyordu.
void main() {
  late List<Map<String, dynamic>> music;
  late List<Map<String, dynamic>> culture;
  late List<Map<String, dynamic>> all;
  late Set<String> blockedTerms;
  late Set<String> corpusTokens;
  late Set<String> allowed;

  List<Map<String, dynamic>> readList(String path) =>
      (jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  const sf = 'docs/content/source_first_expansion_2026_08';

  setUpAll(() {
    music = readList('$sf/music/music_questions.json');
    culture = readList('$sf/culture/culture_questions.json');
    all = [...music, ...culture];

    final glossary =
        jsonDecode(
              File(
                'docs/content/terminology/zankurd_project_glossary_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    blockedTerms = {
      for (final c
          in (glossary['concepts'] as List).cast<Map<String, dynamic>>())
        if ((c['projectAuthoringStatus'] as String).startsWith(
          'AUTHORING_BLOCKED',
        ))
          if (c['projectPreferredKurmanji'] != null)
            (c['projectPreferredKurmanji'] as String).toLowerCase(),
    };

    allowed = {
      for (final f in const [
        'allow_proper_nouns.json',
        'allow_inflections.json',
      ])
        ...(jsonDecode(File('$sf/$f').readAsStringSync())
                as Map<String, dynamic>)
            .keys
            .map((k) => k.toLowerCase()),
    };

    corpusTokens = <String>{};
    for (final bank in const [
      'assets/data/offline_questions.json',
      'assets/data/editorial_questions.json',
      'assets/data/community_questions.json',
      'assets/data/sentence_building_questions.json',
    ]) {
      corpusTokens.addAll(_words(File(bank).readAsStringSync().toLowerCase()));
    }
  });

  /// Oyuncuya görünen BÜTÜN Kurmancî metin — çeldiriciler dâhil. Bir soru,
  /// yanlış şıkkın yanlış olması sebebiyle sözleşmeden muaf değildir.
  List<String> visibleKu(Map<String, dynamic> q) => [
    q['promptKu'] as String,
    ...(q['answersKu'] as List).cast<String>(),
    q['explanationKu'] as String,
  ];

  List<String> visibleTr(Map<String, dynamic> q) => [
    q['promptTr'] as String,
    ...(q['answersTr'] as List).cast<String>(),
    q['explanationTr'] as String,
  ];

  test('bekçi boş küme üzerinde çalışmıyor', () {
    expect(music, hasLength(12));
    expect(culture, hasLength(12));
    expect(blockedTerms, isNotEmpty);
    expect(corpusTokens.length, greaterThan(5000));
    expect(allowed, isNotEmpty);
  });

  test('iki kategori dengeli: eşit sayı, aynı doğrulama seviyesi', () {
    expect(
      music.length,
      culture.length,
      reason: 'batch "balanced" diye üretildi; sayılar ayrışırsa değil',
    );
    for (final q in all) {
      expect(
        q['sourceAccessLevel'],
        'FETCHED_DIRECT',
        reason: '${q['questionId']}: arama özeti kaynak sayılmaz',
      );
    }
  });

  test('her kayıt gerçek bir kaynak URLsi ve olgu cümlesi taşıyor', () {
    for (final q in all) {
      final ref = q['sourceReference'] as String;
      expect(
        ref,
        startsWith('https://'),
        reason: '${q['questionId']}: iç künye kaynak değildir',
      );
      expect(
        (q['exactSupportingFact'] as String).trim(),
        isNotEmpty,
        reason: '${q['questionId']}: destekleyen cümle boş',
      );
      expect(q['riskClass'], isIn(const ['A', 'B', 'C']));
    }
  });

  test('şık yapısı sağlam: dört farklı şık, geçerli doğru indeks', () {
    for (final q in all) {
      final ku = (q['answersKu'] as List).cast<String>();
      final tr = (q['answersTr'] as List).cast<String>();
      final ci = q['correctIndex'] as int;
      expect(ku, hasLength(4), reason: '${q['questionId']}');
      expect(tr, hasLength(4), reason: '${q['questionId']}');
      expect(
        ku.toSet(),
        hasLength(4),
        reason: '${q['questionId']}: yinelenen şık',
      );
      expect(
        tr.toSet(),
        hasLength(4),
        reason: '${q['questionId']}: yinelenen şık',
      );
      expect(ci, inInclusiveRange(0, 3), reason: '${q['questionId']}');
    }
  });

  test('bloke Kurmancî terim hiçbir görünür alanda yok', () {
    final offenders = <String>[];
    for (final q in all) {
      for (final field in visibleKu(q)) {
        for (final term in blockedTerms) {
          if (_containsWord(field, term)) {
            offenders.add('${q['questionId']}: $term -> "$field"');
          }
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('her Kurmancî sözcük korpusta kanıtlı ya da izin listesinde', () {
    // Uydurulmuş Kurmancî terim, yanlış kaynaktan daha zararlıdır: oyuncu onu
    // doğru sanıp öğrenir. İzin listesi kaçış deliği değil, KAYIT: her girdi
    // ya bir özel addır ya da korpusta kanıtlı bir biçimin çekimidir.
    final unattested = <String>{};
    for (final q in all) {
      for (final field in visibleKu(q)) {
        for (final w in _words(field.toLowerCase())) {
          if (!corpusTokens.contains(w) && !allowed.contains(w)) {
            unattested.add('${q['questionId']}: $w');
          }
        }
      }
    }
    expect(unattested, isEmpty, reason: unattested.join('\n'));
  });

  test('izin listesindeki her çekim, korpusta kanıtlı bir lemmaya bağlı', () {
    // Liste kendini doğrulamazsa "izin verildi" demek "kanıtlandı" sanılır.
    final infl =
        jsonDecode(File('$sf/allow_inflections.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final entry in infl.entries) {
      final m = RegExp('«(.+?)»').firstMatch(entry.value as String);
      expect(
        m,
        isNotNull,
        reason: '${entry.key}: gerekçe lemmayı «...» içinde vermiyor',
      );
      expect(
        corpusTokens,
        contains(m!.group(1)),
        reason: '${entry.key}: gösterilen lemma korpusta yok',
      );
    }
  });

  test('cevap pozisyonu kategori içinde dengeli', () {
    for (final batch in [music, culture]) {
      final counts = <int, int>{};
      for (final q in batch) {
        counts.update(
          q['correctIndex'] as int,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
      final maxShare =
          counts.values.reduce((a, b) => a > b ? a : b) / batch.length;
      expect(
        maxShare,
        lessThanOrEqualTo(1 / 3 + 0.001),
        reason: 'pozisyon dağılımı $counts — bir şık kalıba dönüşmüş',
      );
      expect(
        counts.keys.toSet(),
        hasLength(4),
        reason: 'pozisyon dağılımı $counts — hiç doğru olmayan şık var',
      );
    }
  });

  test('doğru şık tek başına en uzun değil', () {
    // Naif ölçüm (beraberlik de sayar) yıl sorularında anlamsızdır: bütün
    // şıklar dört karakterdir. Oyuncunun kullanabileceği sinyal, doğru şıkkın
    // TEK BAŞINA en uzun olmasıdır.
    final flagged = <String>[];
    for (final q in all) {
      for (final key in const ['answersKu', 'answersTr']) {
        final lens = (q[key] as List)
            .cast<String>()
            .map((s) => s.length)
            .toList();
        final ci = q['correctIndex'] as int;
        final max = lens.reduce((a, b) => a > b ? a : b);
        if (lens[ci] == max && lens.where((l) => l == max).length == 1) {
          flagged.add('${q['questionId']}.$key $lens');
        }
      }
    }
    // Özel adların uzunluğu değiştirilemez (tshalghi 8, diğerleri 6); bu
    // yüzden sıfır değil, dar bir tavan.
    expect(flagged.length, lessThanOrEqualTo(2), reason: flagged.join('\n'));
  });

  test('soru kökü cevabı açık etmiyor', () {
    final circular = <String>[];
    for (final q in all) {
      for (final pair in [
        [
          q['promptKu'] as String,
          (q['answersKu'] as List)[q['correctIndex'] as int],
        ],
        [
          q['promptTr'] as String,
          (q['answersTr'] as List)[q['correctIndex'] as int],
        ],
      ]) {
        final answerWords = _content(pair[1] as String);
        if (answerWords.isNotEmpty &&
            answerWords.difference(_content(pair[0] as String)).isEmpty) {
          circular.add('${q['questionId']}: "${pair[1]}"');
        }
      }
    }
    expect(circular, isEmpty, reason: circular.join('\n'));
  });

  test('çeldirici kendini yanlış ilan etmiyor, şablon artığı taşımıyor', () {
    final selfLabel = RegExp(
      r'\((?:yanlış|şaş|ne rast|geçersiz)\)',
      caseSensitive: false,
    );
    final templateId = RegExp(r'\(\s*0\d{3}\s*\)');
    final placeholder = RegExp(
      r'\b(TODO|FIXME|XXX|placeholder)\b',
      caseSensitive: false,
    );
    for (final q in all) {
      for (final field in [...visibleKu(q), ...visibleTr(q)]) {
        expect(
          selfLabel.hasMatch(field),
          isFalse,
          reason: '${q['questionId']}: $field',
        );
        expect(
          templateId.hasMatch(field),
          isFalse,
          reason: '${q['questionId']}: $field',
        );
        expect(
          placeholder.hasMatch(field),
          isFalse,
          reason: '${q['questionId']}: $field',
        );
      }
    }
  });

  test('staged kayıtlar runtime bankasına SIZMAMIŞ', () {
    // Havuz eşiği 100; 49'da aktivasyon yok. Bir kaydın yanlışlıkla bankaya
    // girmesi, ölçülmemiş içeriğin oyuncuya ulaşması demektir.
    final live =
        jsonDecode(
              File('assets/data/offline_questions.json').readAsStringSync(),
            )
            as List;
    final liveIds = {for (final q in live) (q as Map)['id'] as String};
    for (final q in all) {
      expect(
        liveIds,
        isNot(contains(q['questionId'])),
        reason: '${q['questionId']} aktive edilmiş görünüyor',
      );
    }
  });

  test('devlet-merkezli coğrafya kalıbı kullanılmamış', () {
    // Cografya turunda 62 kayıt "hangi ülkededir" kalıbı yüzünden karantinaya
    // alınmıştı: Kürt yerlerinin tek kimliği egemen devlet olarak kuruluyordu.
    // Aynı kalıp Çand/Muzîk'te de yasak.
    final statePattern = RegExp(
      r'(hangi ülke|kîjan welat|hangi devlet|kîjan dewlet)',
      caseSensitive: false,
    );
    for (final q in all) {
      for (final field in [...visibleKu(q), ...visibleTr(q)]) {
        expect(
          statePattern.hasMatch(field),
          isFalse,
          reason: '${q['questionId']}: $field',
        );
      }
    }
  });
}

final _wordRe = RegExp(r"[a-zA-ZçêîşûÇÊÎŞÛğıöüĞİÖÜ]+");

Set<String> _words(String s) =>
    _wordRe.allMatches(s).map((m) => m.group(0)!.toLowerCase()).toSet();

const _stop = {
  'li',
  'di',
  'de',
  'ku',
  'ye',
  'û',
  'bi',
  'ji',
  'wek',
  'çi',
  'kîjan',
  'gorî',
  'nav',
  'ser',
  'tê',
  'ne',
  'vê',
  'van',
  'her',
  'jî',
  'bir',
  'bu',
  've',
  'ile',
  'için',
  'hangi',
  'nedir',
  'göre',
  'tenê',
  'yalnız',
};

Set<String> _content(String s) =>
    _words(s).where((w) => w.length > 2 && !_stop.contains(w)).toSet();

/// Terimin bir SÖZCÜK olarak geçip geçmediği. Dart'ta `\b` ASCII tabanlıdır ve
/// `ş`, `î`, `û` harflerinden önce eşleşmez; sınır bu yüzden elle kontrol
/// edilir.
bool _containsWord(String field, String term) {
  final haystack = field.toLowerCase();
  var from = 0;
  while (true) {
    final i = haystack.indexOf(term, from);
    if (i < 0) return false;
    final before = i == 0 ? '' : haystack[i - 1];
    if (before.isEmpty || !_wordRe.hasMatch(before)) return true;
    from = i + 1;
  }
}
