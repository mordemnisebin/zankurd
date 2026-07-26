import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Ekranda görünen her karakter uygulamanın yazı tipinde bulunmalı.
///
/// 2026-07-26: arayüz metinlerinde emoji ve simge karakterleri vardı —
/// `'Tüm görevler tamam! 🎉'`, `'$name 👀'`, `'✓ Kazanıldı'`, sıralama
/// madalyaları `🥇🥈🥉`. Rubik bunların **hiçbirini** taşımıyor. Eksik
/// glif hata vermez: sistem yazı tipine düşer. Sonuç, cümlenin ortasında
/// başka bir tipe geçen bir metin ve düz marka ikonlarının yanında renkli
/// bir emoji — cihazdan cihaza da değişir.
///
/// Bu test Rubik'in cmap tablosunu gerçekten okur; "emoji listesi" gibi
/// elle tutulan bir kara liste değildir. Yeni bir simge eklenirse, o
/// karakter fontta yoksa burada yakalanır.
///
/// Kapsam kaynak dizgelerdir; yorumlar ölçülmez, çünkü ekrana çıkmazlar.
void main() {
  /// TrueType `cmap` (format 4) tablosundaki kod noktaları.
  Set<int> fontCodePoints(String path) {
    final data = ByteData.sublistView(
      Uint8List.fromList(File(path).readAsBytesSync()),
    );
    final tableCount = data.getUint16(4);
    var cmapOffset = -1;
    for (var i = 0; i < tableCount; i++) {
      final record = 12 + 16 * i;
      final tag = String.fromCharCodes([
        for (var b = 0; b < 4; b++) data.getUint8(record + b),
      ]);
      if (tag == 'cmap') cmapOffset = data.getUint32(record + 8);
    }
    expect(cmapOffset, greaterThan(0), reason: 'cmap tablosu bulunamadı');

    final subtableCount = data.getUint16(cmapOffset + 2);
    var best = -1;
    for (var i = 0; i < subtableCount; i++) {
      final entry = cmapOffset + 4 + 8 * i;
      final platform = data.getUint16(entry);
      final encoding = data.getUint16(entry + 2);
      if (platform == 3 && (encoding == 1 || encoding == 10)) {
        best = cmapOffset + data.getUint32(entry + 4);
      } else if (platform == 0 && best < 0) {
        best = cmapOffset + data.getUint32(entry + 4);
      }
    }
    expect(best, greaterThan(0), reason: 'Unicode cmap alt tablosu yok');

    final points = <int>{};
    final format = data.getUint16(best);
    expect(format, 4, reason: 'beklenmeyen cmap biçimi: $format');
    final segCount = data.getUint16(best + 6) ~/ 2;
    for (var i = 0; i < segCount; i++) {
      final end = data.getUint16(best + 14 + 2 * i);
      final start = data.getUint16(best + 16 + segCount * 2 + 2 * i);
      if (end == 0xFFFF) continue;
      for (var c = start; c <= end; c++) {
        points.add(c);
      }
    }
    return points;
  }

  test('arayüz dizgelerinde yazı tipinin taşımadığı karakter yok', () {
    final covered = fontCodePoints('assets/fonts/Rubik-Regular.ttf');
    // Kurmancî ve Türkçe harfler zaten fontta; kontrol asıl simgeleri
    // hedefler. ASCII altı (boşluk, satır sonu) ve tipografik noktalama
    // için hızlı geçiş yapılır.
    bool isPlain(int code) => code < 0x2000;

    final offenders = <String>[];
    // Tek ve çift tırnaklı dizge sabitleri (kaçış ve satır sonu içermeyen).
    final stringLiteral = RegExp('\'([^\'\\\\\n]*)\'|"([^"\\\\\n]*)"');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        // Düzenli ifade kalıpları ekrana çıkmaz; kaynak metni **eşleştirmek**
        // için yazılırlar ve o metinde geçen işaretleri taşımak zorundadırlar.
        if (line.contains('RegExp(')) continue;
        for (final match in stringLiteral.allMatches(line)) {
          final literal = match.group(1) ?? match.group(2) ?? '';
          for (final rune in literal.runes) {
            if (isPlain(rune) || covered.contains(rune)) continue;
            offenders.add(
              '${entity.path}:${i + 1} → '
              'U+${rune.toRadixString(16).toUpperCase()} '
              '(${String.fromCharCode(rune)})',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Rubik bu karakterleri taşımıyor; sistem yazı tipine düşerler: '
          '${offenders.join(", ")}',
    );
  });

  test('metin kayıt defteri tek tür kesme işareti kullanır', () {
    // Paywall ekranında başlıkta "ZanKurd’u", hemen altındaki kartta
    // "ZanKurd'a" yazıyordu: aynı ekranda iki ayrı kesme işareti. Rubik
    // ikisini de taşır, yani bu bir glif kusuru değil, tipografi
    // tutarsızlığıdır — ama aynı gözle görülür (2026-07-26).
    //
    // Kapsam yalnız kayıt defteri: soru bankalarındaki alıntılar ve kaynak
    // künyeleri özgün yazımlarını korumalı, onları düzeltmek içeriği
    // değiştirmek olur.
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final curly = '\u2019'.allMatches(source).length;

    expect(
      curly,
      0,
      reason:
          'Kayıt defterinde eğri kesme işareti (U+2019) var; ekranlarda '
          'düz kesme ile karışıyor.',
    );
  });

  test('kayıt defteri turnuva kontenjanını sayıyla yazmıyor', () {
    // Kontenjan sunucuda ayarlanır (`tournaments.size`). Metne sayı yazmak
    // onu ilk değişiklikte yalan yapar: 8'den 4'e düşürüldüğünde oyun
    // merkezi "8 kişilik eleme" demeye devam ediyordu ve bunu ancak
    // uygulamayı elle gezerken gördüm (2026-07-27).
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final offenders = RegExp(
      r"'[^']*\b(4|8|16)\s*(kişilik|kesan|oyuncu|lîstikvan)[^']*'",
    ).allMatches(source).map((m) => m.group(0)!).toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Turnuva kontenjanı metne sabitlenmiş; sunucudaki değer '
          'değişince yanlış olur: ${offenders.join(", ")}',
    );
  });
}
