/// `lib/src/widgets/` altında ÖLÜ dosya bırakılmadığının bekçisi.
///
/// ## Kusur
///
/// `error_dialog.dart` (66 satır) hiçbir yerden çağrılmıyordu. 2026-08-23
/// taramasında bulundu ve silindi. Tek "referansı" `tool/apply_rest_l10n
/// .py` içindeydi; o betik kendi belgesinde "tek seferlik göç aracı"
/// diyor ve EDITS haritası geçmişte ne değiştirdiğinin kaydı — canlı bir
/// bağımlılık değil.
///
/// ## Niçin sessiz kaldı
///
/// Ölü kod hiçbir şeyi kırmaz: `dart analyze` temiz kalır, testler geçer,
/// uygulama çalışır. Yalnız okuyanı yanıltır ("bu diyalog nerede
/// kullanılıyor?") ve pakete girer. Hiçbir otomatik kapı bakmıyordu.
///
/// ## Niçin SINIF adı aranıyor, dosya adı değil
///
/// İlk ölçüm dosya adını (`error_dialog.dart`) aradı ve dört dosyayı
/// "kullanılmıyor" sandı; üçü yanlıştı, çünkü Dart dosyayı adıyla değil
/// içindeki SINIFI adıyla kullanır. Bir widget `foo_bar.dart` içinde
/// `Baz` sınıfı tanımlıyorsa, onu kullanan dosya `Baz` yazar.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('widgets/ altında hiçbir dosya ölü kalmaz', () {
    final widgetDir = Directory('lib/src/widgets');
    expect(
      widgetDir.existsSync(),
      isTrue,
      reason: 'Bekçi kör kalmasın: dizin bulunamadıysa test anlamsızdır.',
    );

    // Tüm lib/ kaynağını tek metinde topla; her dosya için kendisi hariç
    // aranacak.
    final sources = <String, String>{};
    for (final root in ['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          sources[entity.path] = entity.readAsStringSync();
        }
      }
    }
    expect(sources.length, greaterThan(50), reason: 'Kaynaklar okunamadı.');

    final olu = <String>[];
    for (final entry in sources.entries) {
      if (!entry.key.startsWith('lib/src/widgets/')) continue;

      // Dosyanın tanımladığı PUBLIC üst düzey adlar.
      final adlar = RegExp(
        r'^(?:class|mixin|extension|enum)\s+([A-Z]\w*)',
        multiLine: true,
      ).allMatches(entry.value).map((m) => m.group(1)!).toList();
      if (adlar.isEmpty) continue;

      final kullanildi = adlar.any((ad) {
        final desen = RegExp(r'\b' + ad + r'\b');
        return sources.entries.any(
          (other) => other.key != entry.key && desen.hasMatch(other.value),
        );
      });
      if (!kullanildi) olu.add('${entry.key} (${adlar.join(", ")})');
    }

    expect(
      olu,
      isEmpty,
      reason:
          'Bu dosyaların tanımladığı hiçbir ad lib/ içinde başka yerden '
          'kullanılmıyor. Ya kullan ya sil:\n${olu.join("\n")}',
    );
  });
}
