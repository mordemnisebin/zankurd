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
    final filler = RegExp(
      r'^(Di gotûbêja dersê de|Di nirxandina xwendekaran de'
      r'|Di çarçoveya dersê de)\s*,',
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
