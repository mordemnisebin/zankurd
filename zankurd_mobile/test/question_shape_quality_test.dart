import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Soru "biçim olarak" da iyi olmalı: muğlak kök, tembel çeldirici yok.
///
/// ## Kusur
///
/// Uygulama sahibi 2026-08-18'de bankaya bakıp "bazı sorular çok saçma
/// duruyor" dedi ve örnek verdi: şıkların hepsi "müziğe yakındır / uzaktır"
/// gibi bulanık ilişki cümleleri. Tarama onu doğruladı ve iki ayrı kusur
/// çıkardı:
///
/// **Tembel çeldirici.** Beş soruda iki ya da daha fazla şık aynı kalıptaydı:
/// `bi <bir şey> ve girêdayî ye` ("… ile ilgilidir"). Örnek —
///
///     Di çanda Kurdî de derbarê kilim motifleri de kîjan rasttir e?
///       bi hunera destan ve girêdayî ye
///       bi hunera dengbêjiyê ve girêdayî ye
///       bi rênivîsa Hawarê ve girêdayî ye
///       bi avhewaya deştê ve girêdayî ye
///
/// Dört şık da aynı boş kalıp; hangisinin "doğru" olduğu keyfî. Bu bir soru
/// değil, tahmin oyunudur.
///
/// **Muğlak soru kökü.** `herî zêde bi kîjan qadê re têkildar e` ("en çok
/// hangi alanla ilgilidir") kalıbı, birden fazla savunulabilir cevabı olan
/// sorular üretiyordu: Newroz "baharın gelişi" ile de "toplumsal bağların
/// güçlenmesi" ile de ilgilidir.
///
/// Dokuz soru çıkarıldı. Bekçi yenilerinin girmesini engelliyor.
///
/// ## Niçin başka bekçiler görmedi
///
/// Yapısal denetimlerin hepsi bu soruları GEÇİRİYORDU: dört ayrı şık var,
/// doğru cevap şıklar arasında, açıklama uzunluğu yeterli, kaynak açılıyor.
/// Kusur yapıda değil, sorunun ANLAMINDAydı — ve anlam ölçen tek bekçi
/// yoktu.
void main() {
  final lazyDistractor = RegExp(
    r'^bi .{3,60} ve girêdayî ye$',
    caseSensitive: false,
  );
  final vagueStems = [
    RegExp('herî zêde bi kîjan qadê re têkildar', caseSensitive: false),
    RegExp('herî zêde nêzîkî kîjan', caseSensitive: false),
    RegExp('herî zêde .{0,25}rave dike', caseSensitive: false),
  ];

  List<Map<String, dynamic>> loadAll() {
    final all = <Map<String, dynamic>>[];
    for (final asset in questionBankAssets) {
      final file = File(asset);
      if (!file.existsSync()) continue;
      for (final raw in jsonDecode(file.readAsStringSync()) as List) {
        all.add(raw as Map<String, dynamic>);
      }
    }
    return all;
  }

  test('hiçbir soruda iki şık birden boş ilişki kalıbı taşımaz', () {
    final all = loadAll();
    expect(
      all.length,
      greaterThan(1000),
      reason: 'Bekçi kör kalmasın: bankalar yüklenemediyse sayı boşa sıfırdır.',
    );

    final offenders = <String>[];
    for (final question in all) {
      final answers =
          (question['answers'] as List?)?.cast<Object?>() ?? const [];
      final lazy = answers
          .where((a) => lazyDistractor.hasMatch('$a'.trim()))
          .length;
      if (lazy >= 2) {
        offenders.add('${question['id']}: $lazy şık "… ve girêdayî ye"');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Şıkların çoğu aynı boş kalıpta; doğru cevap keyfî kalıyor:\n'
          '${offenders.join("\n")}',
    );
  });

  test('muğlak "en çok ... ile ilgili" soru kökü kullanılmıyor', () {
    final offenders = <String>[];
    for (final question in loadAll()) {
      final prompt = '${question['prompt'] ?? ''}';
      if (vagueStems.any((pattern) => pattern.hasMatch(prompt))) {
        offenders.add('${question['id']}: ${prompt.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu kalıp birden çok savunulabilir cevabı olan sorular üretiyor; '
          'oyuncu doğru düşünüp yanlış cevap alır:\n${offenders.join("\n")}',
    );
  });
}
