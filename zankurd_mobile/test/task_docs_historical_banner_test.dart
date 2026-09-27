import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Otonom/kalan/tasarım görev Markdown'ları tarihî şerit taşımıyordu.
///
/// `TASARIM_TAMAMLAMA_GOREVI.md` 2367 test ve liderlik boşluğunu şimdiki
/// zamanla verir. Şerit olmayınca eski plan canlı görev gibi durur; kod ve
/// `applied.md` asıl kaynakken ajan bu dosyayı iş kuyruğu sanıyordu.
/// OTONOM ve KALAN şerit taşıyordu ama bekçi yoktu — yeni kopya şeritsiz
/// kalamaz.
///
/// `TASARIM_DEVAM_NOTU.md` (2026-08-19) listeden kaçmıştı; öteki üçü onu
/// "yönü anlatır" diye gösterdiği için canlı görünüyordu. "Yapılacak"
/// başlığıyla oda, eşleşme ve öğrenme ekranlarına kilim dokusu istiyor;
/// 2026-09-27 sadeleştirmesi (şık arkasındaki dokunun kaldırılması, öğren
/// ekranının yol + iki eyleme inmesi) tersine karar verdi. Şeritsiz kalsa
/// sonraki ajan dokuyu geri getirirdi.
void main() {
  const files = [
    'docs/OTONOM_IS_LISTESI.md',
    'docs/KALAN_ISLER_GOREVI.md',
    'docs/TASARIM_TAMAMLAMA_GOREVI.md',
    'docs/TASARIM_DEVAM_NOTU.md',
  ];

  for (final path in files) {
    test('${path.split('/').last} tarihî şerit taşır', () {
      final src = File(path).readAsStringSync();
      expect(src, contains('TARİHÎ'));
      expect(src, contains('kaynak değil'));
      expect(src, contains('applied.md'));
    });
  }
}
