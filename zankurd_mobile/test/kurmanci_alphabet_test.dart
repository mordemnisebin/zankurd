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
/// `lib/` altındaki her dosyadan Kurmancî metinleri toplar.
///
/// İki kaynak var ve tarama uzun süre yalnız birincisini görüyordu:
/// 1. Anahtar defteri — `'ku': 'metin'`.
/// 2. Satır içi kullanım — `isKu ? 'kurmancî' : 'türkçe'`. Yalnız ilk dal
///    (soru işaretinden hemen sonraki dize) Kurmancîdir.
///
/// 2026-07-31'e kadar bu dosya yalnız `strings.dart`i okuyordu; satır içi
/// metinlerin tamamı tarama alanının dışındaydı ve tam orada "Bersiv
/// (Arka Yüz)" gibi kusurlar yaşıyordu. Bir bekçinin kapsamı kusurun
/// yaşadığı yeri içermiyorsa o bekçi değildir.
List<({String path, String text})> _kurmanciTexts() {
  final registry = RegExp(r"'ku':\s*\n?\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
  final inline = RegExp(r"""[Kk]u\s*\?\s*'((?:[^'\\]|\\.)*)'""");
  final found = <({String path, String text})>[];

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    final isRegistry = entity.path.endsWith('strings.dart');
    for (final match in (isRegistry ? registry : inline).allMatches(source)) {
      found.add((path: entity.path, text: match.group(1)!));
    }
  }
  return found;
}

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

  test('satır içi Kurmancî metinlerde de ı, ğ, ö, ü, İ geçmez', () {
    // Defter dışında kalan `isKu ? '...'` dalları. "Bersiv (Arka Yüz)"
    // ve "Pirs (Ön Yüz)" tam burada yaşıyordu (2026-07-31 denetimi).
    final turkishLetters = RegExp('[ığöüİĞÖÜ]');
    final offenders = _kurmanciTexts()
        .where((entry) => !entry.path.endsWith('strings.dart'))
        .where((entry) => turkishLetters.hasMatch(entry.text))
        .map((entry) => '${entry.path}: ${entry.text}')
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Satır içi Kurmancî metinde Türkçe harf:\n'
          '${offenders.take(8).join("\n")}',
    );
  });

  test('Kurmancî metinlerde Türkçe işlev sözcüğü geçmez', () {
    // Harf taraması "sen" gibi kusurları prensip olarak yakalayamaz:
    // Türkçeye özgü harf içermezler. Ana ekrandaki seri cümlesi
    // "$_streak roj in ku **sen** bi rêkûpêk dilîzî!" bu boşluktan
    // geçmişti — cümlenin geri kalanı doğru Kurmancî olduğu için göze
    // "biraz tuhaf" gelip geçiyordu (2026-07-31 denetimi).
    //
    // Liste bilerek dar: yalnız Kurmancîde bağımsız sözcük OLMAYAN,
    // Türkçeye özgü işlev sözcükleri. Ödünç sözcük tartışması olanlar
    // (ör. "ama") dışarıda bırakıldı ki bekçi gürültü üretmesin.
    const turkishFunctionWords = [
      'sen',
      'ben',
      'biz',
      'siz',
      'için',
      'gibi',
      'daha',
      'çok',
      'veya',
      'kadar',
      'sonra',
      'önce',
      'yarış',
      'şıkka',
      'kamu',
    ];

    final offenders = <String>[];
    for (final entry in _kurmanciTexts()) {
      for (final word in turkishFunctionWords) {
        if (RegExp('\\b$word\\b', caseSensitive: false).hasMatch(entry.text)) {
          offenders.add('${entry.path}: "$word" → ${entry.text}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Kurmancî metinde Türkçe işlev sözcüğü:\n'
          '${offenders.take(8).join("\n")}',
    );
  });

  test('anahtar defterine paralel ikinci bir sözlük yok', () {
    // `QuizStrings` ve `CommonStrings` defterle çelişen karşılıklar
    // tutuyordu: aynı Kaydet düğmesi bir ekranda "Biparêze", ötekinde
    // "Tomar bike" diyordu. İkisi de `Tr.missingFor` bütünlük testinin
    // ve bu dosyadaki alfabe taramasının dışındaydı (2026-07-31).
    final lang = File('lib/src/l10n/lang.dart').readAsStringSync();
    for (final gone in ['class QuizStrings', 'class CommonStrings']) {
      expect(
        lang,
        isNot(contains(gone)),
        reason: 'Bir kavramın tek Kurmancî karşılığı olur, o da defterdedir.',
      );
    }
  });
}
