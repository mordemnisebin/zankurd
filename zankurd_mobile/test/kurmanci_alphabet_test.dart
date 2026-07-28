import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kurmancî metinlerde Türkçe harf bulunmaz.
///
/// Kurmancî alfabesinde ı, ğ, ö, ü **yoktur**; İ de yoktur (i'nin büyüğü
/// I'dır). Bu harflerden biri bir Kurmancî metinde görünüyorsa ya Türkçe
/// bir kelime sızmıştır ya da harf yanlış yazılmıştır.
///
/// 2026-07-27 taraması dört tane buldu ve dördü de farklı bir kusurdu:
///
/// * "Te **yarış** di rêza {rank}. de qedand." — Türkçe kelime; Kurmancîsi
///   "pêşbirk". Sonuç ekranının en çok görünen cümlesiydi.
/// * "Bersiva ducarî: **şıkka** din hilbijêre" — yine Türkçe kelime;
///   Kurmancîsi "bijare". Üstelik joker ipucu, yani oyuncu coin harcadıktan
///   sonra okuduğu cümle.
/// * "**Bİ** DAWÎ BÛ" — Türkçe noktalı büyük İ. Kurmancîde i'nin büyüğü
///   noktasız I'dır; turnuva ağacında yazıyordu.
/// * "bi lîsansên **kamu malı**" — Türkçe terim, Kurmancî künye metninin
///   ortasında. Künye yasal bir metin; dilinin karışması onu da zayıflatır.
///
/// Dördü de gözle okunduğunda "biraz tuhaf" görünen, ama aranmadıkça
/// bulunmayan türden. Harf taraması bunları mekanik olarak yakalar.
void main() {
  test('Kurmancî metinlerde ı, ğ, ö, ü, İ geçmez', () {
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    // 'ku': 'metin'  — çok satırlı bitişik dizeler dahil.
    final entries = RegExp(r"'ku':\s*\n?\s*((?:'(?:[^'\\]|\\.)*'\s*)+)")
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toList();

    expect(entries, isNotEmpty, reason: 'Kurmancî metin bulunamadı');

    final offenders = entries
        .where((text) => RegExp('[ığöüİĞÖÜ]').hasMatch(text))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Kurmancî metinde Türkçe harf: ${offenders.join(" | ")}',
    );
  });
}
