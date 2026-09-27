/// Gizli kategoriler sunucuda da devre dışı — göç sözleşmesi bekçisi.
///
/// ## Kusur
///
/// İstemci Paradigma, Siyaset ve Teknolojî'yi listelerde göstermiyor ama
/// hızlı düellonun "Rastgele" kuyruğu gerçek kategoriyi sunucuda, etkin
/// kategoriler arasından seçiyor. Seçim gizli bir kategoriye düşünce iki
/// oyuncu uygulamada hiç göremedikleri bir kategoride eşleşiyordu.
/// `supabase/2026-09-28_hidden_categories_inactive.sql` bu kategorileri
/// `is_active = false` yapar.
///
/// ## Niçin sessiz kalırdı
///
/// Gizli kategori listesi iki yerde yaşıyor: Dart'ta `hiddenCategoryIds`,
/// SQL'de bu göç (ve düello seçimi). Biri değişip öteki unutulursa hiçbir
/// derleme ya da widget testi kızarmaz; kayma ancak canlı eşleşmede, rastgele
/// seçim o kategoriye düştüğünde görünürdü.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';

void main() {
  final sql = File(
    'supabase/2026-09-28_hidden_categories_inactive.sql',
  ).readAsStringSync();

  /// Yorum satırları atılmış SQL: geri alma örneği `is_active = true`
  /// içerdiği için iddialar yalnız çalışan komuta bakar.
  final statements = sql
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  test('devre dışı bırakılan liste istemcideki gizli listeyle birebir', () {
    final match = RegExp(r'where name in \(([^)]*)\)').firstMatch(statements);
    expect(match, isNotNull, reason: 'kategori listesi bulunamadı');
    final names = RegExp(
      r"'([^']+)'",
    ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
    expect(names, hiddenCategoryIds);
  });

  test('yalnız kategori etkinliğini kapatır, soruya ve silmeye dokunmaz', () {
    expect(statements, contains('update public.categories'));
    expect(statements, contains('set is_active = false'));
    expect(statements, isNot(contains('public.questions')));
    expect(statements.toLowerCase(), isNot(contains('delete')));
    expect(statements.toLowerCase(), isNot(contains('drop ')));
  });

  test('geri alma ve postflight dosyada yazılı', () {
    expect(sql, contains('set is_active = true'));
    expect(sql, contains('Postflight'));
  });

  test('applied.md satırı uygulanmadı olarak duruyor', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    final row = applied
        .split('\n')
        .firstWhere(
          (line) => line.contains('2026-09-28_hidden_categories_inactive.sql'),
          orElse: () => '',
        );
    expect(row, contains('⏳'));
  });
}
