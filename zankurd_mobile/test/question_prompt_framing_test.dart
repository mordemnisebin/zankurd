import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Soru gövdesi ders çerçevesi dolgusuyla başlamaz.
///
/// 2026-07-27: bankadaki 2387 sorunun **479'u** şu iki kalıptan biriyle
/// başlıyordu —
///
///   "Di gotûbêja dersê de, di qada ziman de têgeha 'ergatîf' bi kîjan
///    ravekirinê çêtir tê fêmkirin?"
///   "Di nirxandina xwendekaran de, di qada ziman de têgeha 'ergatîf' bi
///    kîjan ravekirinê çêtir tê fêmkirin?"
///
/// "Ders tartışmasında" ve "öğrenci değerlendirmesinde": ikisi de hiçbir
/// şey söylemiyor, makine üretiminden kalma çerçeve cümleleri. Oyuncu her
/// soruda önce bu dolguyu okuyordu.
///
/// Asıl kusur önek silinince göründü: **aynı soru üç kez vardı.** 240
/// grubun 239'u üçlüydü — tıpatıp aynı gövde, aynı doğru cevap, yalnız
/// çeldiricilerin sırası karışık. Bankanın "kategori içinde gövdeler
/// benzersiz" bekçisi bunu göremiyordu, çünkü önekler gövdeleri farklı
/// kılıyordu: dolgu, bekçiyi de atlatıyordu.
///
/// Bu yüzden burada iki bekçi var: biri dolguyu, öbürü dolgu olmadan
/// kalan kopyayı yasaklar. Tek başına ilki, önekli yeni bir kopyayı
/// durduramazdı.
void main() {
  final prompts = <String, List<String>>{};
  final byKey = <String, List<String>>{};

  setUpAll(() {
    for (final name in const [
      'assets/data/offline_questions.json',
      'assets/data/editorial_questions.json',
    ]) {
      final list = (jsonDecode(File(name).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      for (final q in list) {
        final id = q['id'] as String;
        prompts[id] = [q['prompt'] as String, q['category'] as String];
        final key = [
          q['category'],
          (q['prompt'] as String).trim().toLowerCase().replaceAll(
            RegExp(r'\s+'),
            ' ',
          ),
          (q['correctAnswer'] as String).trim().toLowerCase(),
        ].join('|');
        (byKey[key] ??= []).add(id);
      }
    }
  });

  test('gövde ders çerçevesi dolgusuyla başlamıyor', () {
    // İkinci dolgu: kategori adı zaten kartın üstünde çip olarak yazıyor,
    // yani "di qada Cografyaê de" ekranda görünen bir şeyi tekrar ediyordu.
    // Üstelik bankanın iç anahtarını kullanıyor ve Kurmancî çekimi bozuktu
    // ("Cografyaê" yerine "Cografyayê"): dolgu hem gereksiz hem yanlıştı.
    final filler = RegExp(
      r'^(Di gotûbêja dersê de|Di nirxandina xwendekaran de'
      r'|Di çarçoveya dersê de)\s*,'
      r'|\b(di|li) qada \S+( de)?\b',
      caseSensitive: false,
    );
    final offenders = prompts.entries
        .where((e) => filler.hasMatch(e.value.first))
        .map((e) => e.key)
        .toList();
    expect(
      offenders,
      isEmpty,
      reason: 'ders çerçevesi dolgusu: ${offenders.take(10).join(", ")}',
    );
  });

  test('gövdedeki alıntı terimlerde yarı çeviri kalmadı', () {
    // 2026-07-27: Kurmancî gövdelerin içinde Kürtçe ada Türkçe bir sözcük
    // yapışmış terimler duruyordu — makine çevirisinin yarıda bıraktığı
    // yerler: 'Memê Alan destanı', 'Behdînan bölgesi', 'dengbêj makamı'.
    // Kurmancîde tamlama ters kurulur (destana Memê Alan) ve Türkçe iyelik
    // eki yoktur; bunlar "biraz tuhaf" değil doğrudan yanlıştı.
    //
    // Ölçüt: Kurmancî bir gövdede tırnak içindeki terim Türkçe harf
    // taşımamalı. Çeviri soruları ("bi Tirkî çi ye?") doğal olarak muaf;
    // Türkçe özel adlar da adıyla muaf.
    // 2026-07-30: bu desenin iki kör noktası vardı.
    //
    // Biri alıntı işaretiydi: `'…'` ve `«…»` taranıyordu ama `"…"`
    // taranmıyordu. Banka üç tırnak kuralını birden taşıdığı için çift
    // tırnaklı Türkçe terimler bekçiye hiç görünmüyordu. Tırnaklar «»
    // kuralında birleştirilince (`tool/normalize_question_typography.py`)
    // 33 kayıt açığa çıktı.
    //
    // Öteki muafiyet desenidir: çeviri sorusu yalnız "bi Tirkî" kalıbıyla
    // tanınıyordu. Banka aynı soruyu altı ayrı kalıpla soruyor —
    // "Hevwateya «masa» bi Kurmancî çi ye?", "Ji bo gotina «göz»…",
    // "Kîjan ji van peyva Kurmancî ye ku wateya wê «kapı» ye?". Onlarda
    // Türkçe terim sorunun konusudur, kusur değil.
    //
    // Ayıklama sonrası kalan dört kayıt gerçek kusurdu: Kurmancî gövdede
    // Türkçe **kavram** adı ("Çoğulculuk", "Demokratik çözüm"). Dördünün
    // de Kurmancî karşılığı bankada zaten geçiyordu.
    final translationQuestion = RegExp(
      'bi Tirkî|Tirkî de|Türkçe|wateya Tirkî|bi Kurmancî|Hevwateya'
      '|peyva Kurmancî ye ku wateya|ji bo gotina|tê xwestin|wateya wê'
      '|Kurmancî «[^»]+» =|tê wateya «',
      caseSensitive: false,
    );
    final quotedTerm = RegExp("'([^']{3,40})'|«([^»]{3,40})»");
    final turkish = RegExp('[ığöüİĞÖÜ]');
    // Türkçe özel adlar: müzik grubu ve film adları.
    const properNames = {'offline_10878', 'comm_sin_0107'};

    final offenders = <String>[];
    for (final entry in prompts.entries) {
      if (properNames.contains(entry.key)) continue;
      final prompt = entry.value.first;
      if (translationQuestion.hasMatch(prompt)) continue;
      for (final match in quotedTerm.allMatches(prompt)) {
        final term = match.group(1) ?? match.group(2)!;
        if (turkish.hasMatch(term)) offenders.add('${entry.key} ($term)');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'yarı çevrilmiş terim: ${offenders.join(", ")}',
    );
  });

  test('aynı gövde + aynı doğru cevap iki kez geçmiyor', () {
    final duplicates = byKey.entries
        .where((e) => e.value.length > 1)
        .map((e) => e.value.join("="))
        .toList();
    expect(
      duplicates,
      isEmpty,
      reason: 'kopya soru: ${duplicates.take(10).join(" | ")}',
    );
  });
}
