import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Türkçe varyant, Kurmancî varyantla aynı sınavı vermeli.
///
/// ## Kusur
///
/// `answersFor` Türkçe seçildiğinde `answersTr` listesini BÜTÜN olarak
/// değiştirir ve `correctAnswerFor` `correctAnswerTr` döndürür. Yani doğru
/// cevap DEĞERE göre çözülür — iki dilde farklı indekste durması yanlış
/// cevap üretmez. (İlk yazımda bu bekçi "kullanıcı başka bir soruya cevap
/// vermiş olur" diye gerekçelendirilmişti; yanlıştı ve düzeltildi.)
///
/// Gerçek kusur başkaydı ve ölçüldü (2026-08-06): çevrilmiş 55 sorunun
/// **%90,9'unda** doğru cevap Türkçe listede A şıkkında duruyor —
/// Kurmancî'de dağılım %32,9/31,5/16,6/19,0 iken. Çeviriler, doğru cevap
/// başa alınarak üretilmiş. Sonuç: **Türkçe oynayan biri "hep A" diyerek
/// çevrilmiş soruların %91'ini bilir.** Sınav olmaktan çıkar.
///
/// Bu bekçi iki şeyi sabitler: çeviri kaydı yarım kalamaz, ve Türkçe
/// varyantın doğru-cevap dağılımı bozulamaz.
void main() {
  final banks = <String, List<Map<String, dynamic>>>{};

  setUpAll(() {
    for (final asset in questionBankAssets) {
      banks[asset] = (jsonDecode(File(asset).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
    }
  });

  bool has(Map<String, dynamic> q, String key) {
    final v = q[key];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  List<Map<String, dynamic>> translated() => [
    for (final rows in banks.values)
      for (final q in rows)
        // Konum ancak dört şıklı soruda anlamlıdır. Yazılı cevapta tek
        // kanonik değer doğal olarak daima 0. indekstedir; onu "hep A"
        // hilesi ölçümüne katmak gerçek dağılımı kirletir.
        if ((q['answers'] as List?)?.length == 4 &&
            has(q, 'answersTr') &&
            has(q, 'correctAnswerTr'))
          q,
  ];

  test('bütün bankalar okunabildi', () {
    expect(banks, isNotEmpty);
    expect(
      banks.values.fold<int>(0, (a, b) => a + b.length),
      greaterThan(1000),
      reason: 'Banka listesi küçüldüyse bekçi kör kalır',
    );
  });

  test('Türkçe alanlar ya hep birlikte var ya hiç yok', () {
    final offenders = <String>[];
    banks.forEach((asset, rows) {
      for (final q in rows) {
        // Cümle kurma bu kuralın DIŞINDADIR — bu bir istisna değil, kuralın
        // kapsamının doğru çizilmesidir. `wordOrdering`de `answers` bir şık
        // listesi değil, Kurmancî KELİME HAVUZU'dur ve alıştırmanın kendisi
        // odur ("ez / diçim / malê" → "ez diçim malê"). Havuzu Türkçeye
        // çevirmek soruyu yok eder. Soru metnini ("Hevokê rêz bike" →
        // "Cümleyi sırala") çevirmek ise Türkçe oyuncuya ne yapacağını
        // anlatır. Yani burada yarım çeviri eksik değil, DOĞRU olanıdır.
        if (q['type'] == 'wordOrdering') {
          if (has(q, 'answersTr') || has(q, 'correctAnswerTr')) {
            offenders.add(
              '${q['id']} ($asset): cümle kurma sorusunun kelime havuzu '
              'Kurmancî kalmalı, çevrilmiş',
            );
          }
          continue;
        }
        final present = [
          'promptTr',
          'answersTr',
          'correctAnswerTr',
        ].where((k) => has(q, k)).toList();
        if (present.isEmpty || present.length == 3) continue;
        offenders.add('${q['id']} ($asset): yalnız ${present.join(", ")}');
      }
    });
    expect(
      offenders,
      isEmpty,
      reason:
          'Yarım çeviri `answersFor` tarafından sessizce yok sayılır; çeviri '
          'emeği görünmez olur:\n${offenders.take(10).join("\n")}',
    );
  });

  test('answersTr uzunluğu answers ile aynı', () {
    final offenders = <String>[];
    banks.forEach((asset, rows) {
      for (final q in rows) {
        if (!has(q, 'answersTr')) continue;
        final ku = (q['answers'] as List).length;
        final tr = (q['answersTr'] as List).length;
        if (ku != tr) offenders.add('${q['id']} ($asset): $ku vs $tr');
      }
    });
    expect(offenders, isEmpty, reason: offenders.take(10).join('\n'));
  });

  test('correctAnswerTr gerçekten answersTr içinde', () {
    // Bu GERÇEK bir doğruluk kuralıdır: sağlanmazsa `answersFor` güvenli
    // tarafa düşer ve Türkçe kullanıcı soruyu Kurmancî görür.
    final offenders = <String>[];
    banks.forEach((asset, rows) {
      for (final q in rows) {
        if (!has(q, 'answersTr') || !has(q, 'correctAnswerTr')) continue;
        final tr = (q['answersTr'] as List).cast<String>();
        if (!tr.contains(q['correctAnswerTr'])) {
          offenders.add('${q['id']} ($asset)');
        }
      }
    });
    expect(offenders, isEmpty, reason: offenders.take(10).join('\n'));
  });

  test('Türkçe varyantta doğru cevap tek şıkta yığılmıyor', () {
    final rows = translated();
    if (rows.length < 20) return; // örneklem anlamlı değil
    final pos = <int, int>{};
    for (final q in rows) {
      final tr = (q['answersTr'] as List).cast<String>();
      final i = tr.indexOf(q['correctAnswerTr'] as String);
      if (i >= 0) pos[i] = (pos[i] ?? 0) + 1;
    }
    final n = rows.length;
    final worst = pos.values.fold<int>(0, (a, b) => a > b ? a : b);
    final pct = 100 * worst / n;
    expect(
      pct,
      lessThanOrEqualTo(40.0),
      reason:
          'Türkçe varyantta doğru cevapların %${pct.toStringAsFixed(1)}\'i aynı '
          'şıkta. Kullanıcı içeriği bilmeden o şıkkı seçerek kazanır. '
          'Dağılım: $pos (n=$n)',
    );
  });

  test('Türkçe alanlar Kurmancî ile birebir aynı olamaz', () {
    final offenders = <String>[];
    banks.forEach((asset, rows) {
      for (final q in rows) {
        if (!has(q, 'promptTr')) continue;
        if ((q['prompt'] as String).trim() ==
            (q['promptTr'] as String).trim()) {
          offenders.add('${q['id']} ($asset)');
        }
      }
    });
    expect(offenders, isEmpty, reason: offenders.take(10).join('\n'));
  });
}
