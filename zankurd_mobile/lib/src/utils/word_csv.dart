import 'dart:convert';
import 'dart:typed_data';

/// Kelime listesinin tek satırı: Kurmancî terim, Türkçe karşılık, Leitner
/// kutusu ve tekrar sayısı.
class WordCsvRow {
  const WordCsvRow({
    required this.termKu,
    required this.meaningTr,
    required this.box,
    required this.reviews,
  });

  final String termKu;
  final String meaningTr;
  final int box;
  final int reviews;
}

/// Kelime listesini Excel'in açabileceği CSV baytlarına çevirir.
///
/// * UTF-8 BOM başta: ê, î, û, ç, ş gibi Kurmancî harfler Excel'de bozulmaz.
/// * Her hücre tırnaklı; içteki tırnak `""` olur. Satır sonları boşluğa
///   çevrilir, böylece bir satır iki satıra bölünmez.
/// * Formül enjeksiyonu: `=`, `+`, `-`, `@` ya da sekmeyle başlayan hücre
///   tek tırnakla öne alınır; Excel onu formül olarak çalıştırmaz.
Uint8List buildWordCsvBytes(Iterable<WordCsvRow> rows) {
  final out = StringBuffer('kurmancî,türkçe,kutu,tekrar\r\n');
  for (final row in rows) {
    out
      ..write(_cell(row.termKu))
      ..write(',')
      ..write(_cell(row.meaningTr))
      ..write(',')
      ..write(row.box)
      ..write(',')
      ..write(row.reviews)
      ..write('\r\n');
  }
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(out.toString())]);
}

String _cell(String raw) {
  var value = raw.replaceAll(RegExp(r'[\r\n]+'), ' ');
  if (value.isNotEmpty && '=+-@\t'.contains(value[0])) {
    value = "'$value";
  }
  return '"${value.replaceAll('"', '""')}"';
}
