import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Metin renkleri temaya göre seçilmeli.
///
/// `AppTheme.textPrimary/textSub/textMuted` **karanlık temanın** sabit
/// renkleridir; açık temanın karşılıkları ayrı sabitlerdir ve doğru olanı
/// `textMutedColor(context)` gibi getter'lar seçer.
///
/// Sabit olanı doğrudan yazmak hata vermez, yalnız bir temada yanlış renk
/// verir. 2026-07-26'da üç yerde bu vardı; en görünürü sonuç ekranındaki
/// özet satırıydı: `#8F98A0` açık temanın krem zemininde yaklaşık **2,6:1**
/// kontrastla çıkıyordu (WCAG AA normal metin için 4,5:1 ister). Karanlık
/// temada doğru göründüğü için gözden kaçıyordu.
///
/// Yalnız **metin** biçimleri denetlenir. Rozet noktası, çerçeve örneği,
/// çevrimdışı göstergesi gibi süs renkleri kasten sabittir: onlar iki
/// temada da aynı anlamı taşır ve renkli bir yüzey üzerinde durur.
void main() {
  test(
    'TextStyle içinde tema sabiti değil, bağlama duyarlı renk kullanılır',
    () {
      const fixedTextColors = [
        'AppTheme.textPrimary',
        'AppTheme.textSub',
        'AppTheme.textMuted',
      ];

      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();

        var index = source.indexOf('TextStyle(');
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
          for (final fixed in fixedTextColors) {
            // `textMutedColor(context)` de `textMuted` ile başlar; sondaki
            // sınır olmadan getter'ın kendisi ihlal sayılırdı.
            final pattern = RegExp('${RegExp.escape(fixed)}(?![A-Za-z])');
            if (pattern.hasMatch(block)) {
              final line =
                  '\n'.allMatches(source.substring(0, index)).length + 1;
              offenders.add('${entity.path}:$line → $fixed');
            }
          }
          index = source.indexOf('TextStyle(', end);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Metin rengi temaya göre seçilmeli (ör. AppTheme.textMutedColor'
            '(context)): ${offenders.join(", ")}',
      );
    },
  );
}
