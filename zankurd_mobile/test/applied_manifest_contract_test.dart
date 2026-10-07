import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// applied.md belirsiz satırlarının şişmesini önler.
///
/// "Diğer tüm .sql dosyaları | ?" gerçek bir kayıt değildir; yeni göçün
/// durumunu gizler. Açık `?` yalnız henüz canlıda doğrulanmamış dosyalar
/// için kalır.
void main() {
  test('applied.md yakalama satırı ve şişen belirsizlik taşımaz', () {
    final source = File('supabase/applied.md').readAsStringSync();
    expect(
      source,
      isNot(contains('| Diğer tüm .sql dosyaları |')),
      reason: 'Yakalama satırı her yeni göçü sessizce belirsiz sayar.',
    );

    final unverified = RegExp(
      r'^\| [^|]+ \| \? \|',
      multiLine: true,
    ).allMatches(source).length;
    expect(
      unverified,
      lessThanOrEqualTo(3),
      reason:
          'Doğrulanmamış satır arttı ($unverified). Yeni göç ya ✅ '
          'yazılmalı ya da bu tavan bilinçli yükseltilmeli.',
    );
  });
}
