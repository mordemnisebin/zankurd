import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/word_csv.dart';

/// Kelime CSV dökümü (2026-10-25, Opus 5.5 kararı: "şimdi"). Bekçi: Excel
/// için BOM, Kurmancî harfler, formül enjeksiyonu ve satır bölünmesi.
void main() {
  String decode(List<int> bytes) => utf8.decode(bytes.sublist(3));

  test('başta UTF-8 BOM var ve Kurmancî harfler bozulmadan geçer', () {
    final bytes = buildWordCsvBytes(const [
      WordCsvRow(termKu: 'Şekir', meaningTr: 'şeker', box: 2, reviews: 3),
    ]);
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    expect(decode(bytes), contains('"Şekir","şeker",2,3'));
  });

  test('başlık satırı ve CRLF satır sonu', () {
    final text = decode(buildWordCsvBytes(const []));
    expect(text, 'kurmancî,türkçe,kutu,tekrar\r\n');
  });

  test('formül enjeksiyonu: =, +, -, @ ve sekme tek tırnakla korunur', () {
    final text = decode(
      buildWordCsvBytes(const [
        WordCsvRow(
          termKu: '=HYPERLINK("x")',
          meaningTr: '+1',
          box: 1,
          reviews: 0,
        ),
        WordCsvRow(termKu: '-ab', meaningTr: '@x', box: 1, reviews: 0),
        WordCsvRow(termKu: '\tsekme', meaningTr: 'ok', box: 1, reviews: 0),
      ]),
    );
    expect(text, contains('"\'=HYPERLINK(""x"")","\'+1",1,0'));
    expect(text, contains('"\'-ab","\'@x",1,0'));
    expect(text, contains('"\'\tsekme","ok",1,0'));
  });

  test('tırnak kaçışı ve satır sonu boşluğa çevrilir', () {
    final text = decode(
      buildWordCsvBytes(const [
        WordCsvRow(
          termKu: 'a"b',
          meaningTr: 'satır\nbölünmez',
          box: 4,
          reviews: 9,
        ),
      ]),
    );
    expect(text, contains('"a""b","satır bölünmez",4,9'));
    // Başlık + tek veri satırı: iki CRLF, arada başka satır sonu yok.
    expect(text.split('\r\n').length, 3);
  });
}
