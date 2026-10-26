import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kullanılmayan çeviri anahtarı birikmesin.
///
/// ## Kusur
///
/// 2026-10-27'de `K` içinde hiçbir yerden çağrılmayan 20 anahtar vardı
/// (eski ekranlardan kalan "Rakip bul", "Bugünkü tekrar" vb.). Sessizdiler:
/// derleme ve testler geçiyordu, ama her biri Kurmancî jürisinde boşuna
/// denetlenen, metin taramalarında yanlış alarm veren ölü metindi.
///
/// ## Bekçi
///
/// `strings.dart`taki her `static const` anahtarı `lib/`, `test/` ya da
/// `tool/` altında en az bir kez `K.<ad>` olarak geçmeli. Anahtar artık
/// kullanılmıyorsa hem bildirimi hem çeviri satırı silinir.
void main() {
  test('her çeviri anahtarı en az bir yerde kullanılıyor', () {
    final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
    final keys = RegExp(
      r"static const (\w+) =\s*'",
    ).allMatches(strings).map((m) => m.group(1)!).toList();
    expect(keys, isNotEmpty);

    final code = StringBuffer();
    for (final dir in ['lib', 'test', 'tool']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is File &&
            entity.path.endsWith('.dart') &&
            !entity.path.endsWith('l10n/strings.dart')) {
          code.writeln(entity.readAsStringSync());
        }
      }
    }
    final text = code.toString();
    final unused = [
      for (final key in keys)
        if (!RegExp('K\\.$key\\b').hasMatch(text)) key,
    ];
    expect(unused, isEmpty, reason: 'Kullanılmayan anahtarlar: $unused');
  });
}
