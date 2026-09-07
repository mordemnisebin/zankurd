import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-09-05 öğrenme denetimi Markdown'ları tarihî şerit taşımıyordu.
///
/// `RAPOR.md` 2.572 test / 1.846 uyarı sayılarını şimdiki zamanla verir.
/// Şerit olmayınca üretilmiş denetim güncel kaynak gibi durur; kod ve
/// `applied.md` asıl kaynakken ajan bu klasörü canlı envanter sanıyordu.
/// Bekçi yalnız izlenen `.md` tarar — CSV/JSON üretici şeması, PNG ikili,
/// `question_quality/` gitignore'daki adjudication çıktısı.
void main() {
  final files =
      Directory('docs/audit')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.md') &&
                !f.path.contains(
                  '${Platform.pathSeparator}question_quality${Platform.pathSeparator}',
                ),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('öğrenme denetimi arşivinde markdown var', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final rel = file.path.replaceFirst(RegExp(r'.*docs/audit/'), '');
    test('$rel tarihî şerit taşır', () {
      final src = file.readAsStringSync();
      expect(src, contains('TARİHÎ'));
      expect(src, contains('kaynak değil'));
      expect(src, contains('applied.md'));
    });
  }
}
