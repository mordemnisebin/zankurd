import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Temanın yazı tipini atlayan iki kod biçiminin bekçisi.
///
/// Metin ailesini temadan alır — ama iki yerde almaz ve ikisi de sessizce
/// sistem yazı tipine düşer: hata yok, kayıt yok, yalnız o metin ekranın
/// geri kalanından başka bir tiple çizilir.
///
/// 1. `CustomPainter` içindeki `TextPainter` temayı hiç görmez (çarkın
///    rakamları, haftalık grafiğin eksen etiketleri).
/// 2. `styleFrom(textStyle: ...)` temadan gelen biçimi **birleştirmez,
///    değiştirir**; ailesiz verilen biçim aileyi de siler (mağazadaki
///    fiyat etiketleri, giriş ekranındaki ikincil düğme).
///
/// İkisi de 2026-07-26 ekran turunda görüldü. Çalışma zamanında ölçmenin
/// yolu piksel karşılaştırmasıydı; onun yerine kaynak taranıyor.
void main() {
  /// [marker] ile başlayan her dengeli parantez bloğunu döndürür.
  Iterable<({String block, int line})> blocks(String source, String marker) {
    final found = <({String block, int line})>[];
    var index = source.indexOf(marker);
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
      found.add((
        block: source.substring(index, end),
        line: '\n'.allMatches(source.substring(0, index)).length + 1,
      ));
      index = source.indexOf(marker, end);
    }
    return found;
  }

  test('styleFrom(textStyle:) aileyi silmiyor', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final found in blocks(source, 'textStyle: const TextStyle(')) {
        if (!found.block.contains('fontFamily')) {
          offenders.add('${entity.path}:${found.line}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'styleFrom biçimi değiştirir: ailesiz verilirse yazı sistem '
          'tipine düşer: ${offenders.join(", ")}',
    );
  });

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
