import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/kurmanci_text_key.dart';

/// Ses kaydı anahtarının bekçisi.
///
/// ## Kusur
///
/// Aynı ifade derste, sözlükte ve sorularda geçer; anahtar kararlı değilse
/// kayıt dosyası ifadeyi bulamaz, ses sessizce TTS'e (çoğu cihazda yok) düşer.
/// Anahtar ayrıca `ê/e`, `î/i`, `û/u`, `ş/s`, `ç/c` harflerini birleştirirse
/// iki ayrı sözcük (`şev` / `sev`) tek kaydı paylaşır ve biri yanlış okunur.
/// Python aracı (`tool/ses/kayit_listesi.py`) farklı anahtar üretirse kayıt
/// listesi uygulamayla uyuşmaz; bu yüzden CSV'nin her satırı Dart işleviyle
/// karşılaştırılır.
void main() {
  group('kararlılık', () {
    test(
      'büyük/küçük harf, boşluk ve sondaki noktalama anahtarı değiştirmez',
      () {
        final expected = kurmanciTextKey('Navê te çi ye');
        expect(kurmanciTextKey('  Navê   te çi ye?  '), expected);
        expect(kurmanciTextKey('NAVÊ TE ÇI YE!'), expected);
        expect(kurmanciTextKey('«Navê te çi ye».'), expected);
        expect(kurmanciTextKey('Navê te\nçi ye…'), expected);
      },
    );

    test('birleştirici işaretli harf, tek karakterli harfle aynı anahtar', () {
      expect(kurmanciTextKey('Kêç'), kurmanciTextKey('Kêç'));
      expect(kurmanciTextKey('Cîran'), kurmanciTextKey('Cîran'));
      expect(kurmanciTextKey('Dûr'), kurmanciTextKey('Dûr'));
      expect(kurmanciTextKey('çay'), kurmanciTextKey('çay'));
      expect(kurmanciTextKey('şev'), kurmanciTextKey('şev'));
      // Romence virgüllü ș sık yanlış yazılır.
      expect(kurmanciTextKey('șev'), kurmanciTextKey('şev'));
    });

    test('anahtar biçimi: okunur gövde + 8 hanelik özet', () {
      final key = kurmanciTextKey('Rojbaş');
      expect(key, matches(RegExp(r'^rojbas_[0-9a-f]{8}$')));
      expect(kurmanciTextKey('Rojbaş'), key);
    });

    test('boş ya da yalnız noktalama anahtarı boştur', () {
      expect(kurmanciTextKey('   '), '');
      expect(kurmanciTextKey('?!…'), '');
    });

    test('bilinen anahtar sabit (Python ile paylaşılan sözleşme)', () {
      expect(kurmanciTextKey('Alfabe'), 'alfabe_69bbecbc');
    });
  });

  group('ayrı harfler birleşmez', () {
    const pairs = <(String, String)>[
      ('ser', 'sêr'),
      ('sir', 'sîr'),
      ('sur', 'sûr'),
      ('sev', 'şev'),
      ('cay', 'çay'),
      ('dil', 'dîl'),
      ('kur', 'kûr'),
      ('ke', 'kê'),
    ];
    for (final (a, b) in pairs) {
      test('$a / $b', () {
        expect(kurmanciTextKey(a), isNot(kurmanciTextKey(b)));
        // Gövde ASCII'ye katlanır; ayıran özettir.
        expect(
          kurmanciTextKey(a).split('_').last,
          isNot(kurmanciTextKey(b).split('_').last),
        );
      });
    }
  });

  group('kayıt listesi (tool/ses/kayit_listesi.py)', () {
    final rows = _readCsv(File('tool/ses/kayit_listesi.csv'));

    test('başlık ve üç öncelik de dolu', () {
      expect(rows.first, ['oncelik', 'key', 'metin', 'kaynak', 'adet']);
      final data = rows.skip(1).toList();
      for (final priority in ['1', '2', '3']) {
        expect(
          data.where((r) => r[0] == priority),
          isNotEmpty,
          reason: 'öncelik $priority boş',
        );
      }
    });

    test('her satırın anahtarı Dart işleviyle aynı ve benzersiz', () {
      final seen = <String>{};
      for (final row in rows.skip(1)) {
        expect(kurmanciTextKey(row[2]), row[1], reason: 'metin: ${row[2]}');
        expect(seen.add(row[1]), isTrue, reason: 'yinelenen ${row[1]}');
      }
    });
  });
}

/// Tırnaklı alanları (`"a,b"`, `""`) destekleyen küçük CSV okuyucu.
List<List<String>> _readCsv(File file) {
  final text = file.readAsStringSync();
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n') {
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
