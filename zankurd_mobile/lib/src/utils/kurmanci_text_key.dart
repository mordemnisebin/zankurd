import 'dart:convert';

/// Bir Kurmancî ifadeyi kararlı bir ses kaydı anahtarına çevirir.
///
/// ## Niçin var
///
/// Cihazda Kurmancî (`ku`) TTS sesi neredeyse hiç kurulu olmadığından
/// seslendirme fiilen ölüydü; ses artık ana dili Kurmancî olanların
/// kayıtlarından gelecek. Aynı ifade derste, sözlükte ve sorularda geçer ve
/// TEK kayda bağlanmalıdır; kayıt dosyaları da bu anahtarla adlanır. Anahtar
/// metinden türediği için ders ya da sözlük sırası değişse kayıt kaybolmaz.
///
/// ## Kural
///
/// Normalleştirme: birleştirici işaretli harfler tek harfe çevrilir
/// (`e` + U+0302 -> `ê`), küçük harf, boşluklar tek aralığa, baştaki ve
/// sondaki noktalama atılır. `ê/e`, `î/i`, `û/u`, `ş/s`, `ç/c` ayrı HARFLERDİR
/// ve birleştirilmez (`şev` ile `sev` iki ayrı sözcüktür). Okunur bir ASCII
/// gövde (yalnız ad için) + normalleştirilmiş metnin FNV-1a/32 özeti
/// (ayırt eden budur). `tool/ses/kayit_listesi.py` AYNI kuralı uygular; ikisi
/// `test/kurmanci_text_key_test.dart` içinde üretilmiş CSV üzerinden
/// karşılaştırılır.
String kurmanciTextKey(String text) {
  final normalized = normalizeKurmanciText(text);
  if (normalized.isEmpty) return '';
  return '${_slug(normalized)}_${_fnv1a32Hex(normalized)}';
}

const _combining = <String, String>{
  'ê': 'ê',
  'î': 'î',
  'û': 'û',
  'ç': 'ç',
  'ş': 'ş',
  // Romence virgüllü ş sık yanlış yazılır; Kurmancî ş'dir.
  'ș': 'ş',
};

final _spaces = RegExp(r'[ \t\r\n\f\v  -   　]+');
final _invisible = RegExp(r'[​-‍⁠﻿]');
final _edgeNonWord = RegExp(
  r'^[^\p{L}\p{N}\p{M}]+|[^\p{L}\p{N}\p{M}]+$',
  unicode: true,
);

/// Anahtarın girdisi olan normalleştirilmiş metin (bkz. [kurmanciTextKey]).
String normalizeKurmanciText(String text) {
  var s = text.replaceAll(_invisible, '').replaceAll(_spaces, ' ').trim();
  s = s.toLowerCase().replaceAll('̇', '');
  _combining.forEach((from, to) => s = s.replaceAll(from, to));
  s = s.replaceAll('’', "'").replaceAll('‘', "'");
  return s.replaceAll(_edgeNonWord, '');
}

const _asciiFold = <String, String>{
  'ç': 'c',
  'ê': 'e',
  'î': 'i',
  'ş': 's',
  'û': 'u',
  'ı': 'i',
  'ö': 'o',
  'ü': 'u',
  'ğ': 'g',
};

String _slug(String normalized) {
  final out = StringBuffer();
  for (final rune in normalized.runes) {
    final ch = String.fromCharCode(rune);
    final folded = _asciiFold[ch] ?? ch;
    final isAlnum = RegExp(r'^[a-z0-9]$').hasMatch(folded);
    out.write(isAlnum ? folded : '-');
  }
  final collapsed = out
      .toString()
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final cut = collapsed.length > 24 ? collapsed.substring(0, 24) : collapsed;
  final trimmed = cut.replaceAll(RegExp(r'-$'), '');
  return trimmed.isEmpty ? 'x' : trimmed;
}

/// FNV-1a 32 bit. Çarpma web'de 2^53'ü aşmasın diye parçalanır:
/// `h * 0x01000193 == h * 2^24 + h * 0x193 (mod 2^32)`.
String _fnv1a32Hex(String normalized) {
  var h = 0x811c9dc5;
  for (final byte in utf8.encode(normalized)) {
    h = (h ^ byte) & 0xFFFFFFFF;
    h = ((h & 0xFF) * 16777216 + h * 0x193) % 4294967296;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
