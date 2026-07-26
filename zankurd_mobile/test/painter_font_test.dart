import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `CustomPainter` içinde çizilen metnin yazı tipinin bekçisi.
///
/// Widget'lar aileyi temadan alır; `TextPainter` almaz. Aile yazılmayınca
/// metin sessizce sistem varsayılanına düşer — hata vermez, log basmaz,
/// yalnız o metin ekranın geri kalanından başka bir yazı tipiyle çizilir.
/// 2026-07-26 ekran turunda çarkın rakamları ile haftalık grafiğin eksen
/// etiketleri böyleydi.
///
/// Bunu çalışma zamanında ölçmenin yolu yok: piksel karşılaştırması
/// gerekirdi. Onun yerine kaynak taranıyor — `TextPainter` kullanan her
/// dosyadaki her `TextSpan` biçiminde ailenin adı geçmeli.
void main() {
  test('TextPainter kullanan her dosya yazı tipi ailesini yazıyor', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('TextPainter(')) continue;

      // Yalnız `TextSpan(` blokları denetlenir: aynı dosyadaki sıradan
      // `Text` widget'ları aileyi temadan alır ve onları da suçlamak
      // bekçiyi gürültüye boğardı. Blok, dengeli parantez sayılarak
      // ayrılır — içinde `Shadow(...)` gibi çağrılar var, satır sayımı
      // onları ortadan bölerdi.
      var index = source.indexOf('TextSpan(');
      while (index != -1) {
        var depth = 0;
        var end = source.indexOf('(', index);
        for (var i = end; i < source.length; i++) {
          if (source[i] == '(') depth++;
          if (source[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        final block = source.substring(index, end);
        if (!block.contains('fontFamily')) {
          final line = '\n'.allMatches(source.substring(0, index)).length + 1;
          offenders.add('${entity.path}:$line');
        }
        index = source.indexOf('TextSpan(', end);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Boyayıcıdaki metin ailesiz kalırsa sistem yazı tipine düşer: '
          '${offenders.join(", ")}',
    );
  });
}
