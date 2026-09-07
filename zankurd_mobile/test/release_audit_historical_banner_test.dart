import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-01 yayın denetimi Markdown'ları tarihî şerit taşıyordu;
/// `ZANKURD_FINDINGS.json` taşımıyordu.
///
/// JSON 1302 test / 1.9.1+13 / P0-P3 sayılarını şimdiki zamanla verir.
/// Şerit olmayınca makine-okur çıktı güncel kaynak gibi durur; errata ve
/// sonraki göçler applied.md'de dururken ajan bu dosyayı canlı envanter
/// sanıyordu. Bekçi klasördeki her dosyayı tarar — yeni kopya da şeritsiz
/// kalamaz.
void main() {
  final files =
      Directory(
          '../docs/release_audit',
        ).listSync(recursive: true).whereType<File>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('yayın denetimi arşivinde dosya var', () {
    expect(files, isNotEmpty);
  });

  for (final file in files) {
    final rel = file.path.replaceFirst(RegExp(r'.*release_audit/'), '');
    test('$rel tarihî şerit taşır', () {
      final src = file.readAsStringSync();
      expect(src, contains('TARİHÎ'));
      expect(src, contains('kaynak değil'));
      expect(src, contains('applied.md'));
    });
  }

  test('FINDINGS.json geçerli JSON kalır', () {
    final src = File(
      '../docs/release_audit/2026-08-01/ZANKURD_FINDINGS.json',
    ).readAsStringSync();
    expect(jsonDecode(src), isA<Map<String, dynamic>>());
  });
}
