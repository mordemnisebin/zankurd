import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Satırlara bölünmüş dize sabitlerinde kelimelerin yapışmadığının bekçisi.
///
/// ## Kusur
///
/// Dart yan yana yazılan iki dize sabitini boşluksuz birleştirir. Uzun bir
/// metin satır sınırında bölünürken boşluk ne ilk parçanın sonunda ne ikinci
/// parçanın başında kalırsa iki kelime yapışır. 2026-09-28'de
/// `curated_movement_0010`un Türkçe açıklaması tam böyleydi:
/// `'...grupların örgütlenmesi'` + `'anlamına gelir.'` → oyuncu
/// "örgütlenmesianlamına" okuyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Derleyici için bu geçerli bir birleştirmedir, `dart format` da metnin
/// içine bakmaz. Soru bankası bekçileri yüklenen metnin biçimine (tırnak,
/// uzunluk, sızıntı) bakar ama yapışık kelimeyi sözlüğü olmayan bir test
/// yakalayamaz. Yakalanabilecek tek yer kaynaktır: bir satır harf ya da
/// noktalamayla biten bir dizeyle bitiyor ve sonraki satır harfle başlayan
/// bir dizeyle başlıyorsa aradaki boşluk unutulmuştur.
void main() {
  test('lib altında boşluksuz birleşen dize parçası yok', () {
    // İlk parça bir harf ya da cümle noktalamasıyla biter, ikinci parça bir
    // harfle başlar: arada boşluk yok demektir. `/` ile biten URL parçaları
    // ya da boş dizeler bu kalıba girmez.
    final end = RegExp(r"""[\p{L}.,;:!?]['"]$""", unicode: true);
    final start = RegExp(r"""^['"]\p{L}""", unicode: true);
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i + 1 < lines.length; i++) {
        final a = lines[i].trimRight();
        final b = lines[i + 1].trimLeft();
        if (a.trimLeft().startsWith('//')) continue;
        if (end.hasMatch(a) && start.hasMatch(b)) {
          offenders.add('${file.path}:${i + 1}: …${a.trimLeft()} | $b');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Yan yana dize parçaları boşluksuz birleşiyor; kelimeler yapışır:\n'
          '${offenders.join('\n')}',
    );
  });
}
