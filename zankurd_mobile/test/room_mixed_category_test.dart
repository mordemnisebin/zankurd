import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kategorisiz oda karışıktır (2026-10-27).
///
/// ## Kusur
///
/// Karışık oda sunucuda `category_id` boş tutulur. Oda sunucudan okunurken
/// (koda katılma, yeniden yükleme) istemci boş kategoriyi `'Ziman'`a
/// düşürüyordu: 4 cihazlı uçtan uca testte "Karışık" kurulan oda, uygulama
/// yeniden açılınca ve katılan oyuncuda "Dil" görünüyordu.
///
/// ## Bekçi
///
/// Oda okuyan yollarda boş kategori `'Tevlihev'`e (Karışık) düşer; `'Ziman'`
/// varsayılanı geri gelmez.
void main() {
  test('oda okuyan yollar boş kategoriyi Karışık sayar', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(source, contains("room['category_name'] as String? ?? 'Tevlihev'"));
    expect(source, contains("category?['name'] as String? ?? 'Tevlihev'"));
    expect(
      source,
      isNot(contains("room['category_name'] as String? ?? 'Ziman'")),
    );
    expect(source, isNot(contains("category?['name'] as String? ?? 'Ziman'")));
  });
}
