/// Gizli kategoriler sunucuda da devre dışı — göç sözleşmesi bekçisi.
///
/// 2026-09-30: ürün sahibi üç kategoriyi yeniden açtı; istemci listesi boş,
/// kapatma göçü ve açma göçü (`2026-09-30_hidden_categories_reopen.sql`)
/// ikisi de canlıda uygulandı (açma 2026-09-30). Bu dosya iki göçün de
/// sözleşmesini korur.
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

  test('2026-09-28 göçü tarihî kayıttır: kapattığı üç ad hâlâ yazılı', () {
    // İstemci listesi 2026-09-30'da boşaldı (`hiddenCategoryIds`), bu yüzden
    // artık birebir eşitlik aranmaz; bu göç canlıda uygulanmış bir kayıt.
    // Yine de içeriği sabit: reopen göçü tam bu üç adı geri açar.
    final match = RegExp(r'where name in \(([^)]*)\)').firstMatch(statements);
    expect(match, isNotNull, reason: 'kategori listesi bulunamadı');
    final names = RegExp(
      r"'([^']+)'",
    ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
    expect(names, {'Paradigma', 'Siyaset', 'Teknolojî'});
    expect(hiddenCategoryIds, isEmpty);
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

  // 2026-09-30: göç canlıya uygulandı ve salt okunur sorguyla doğrulandı
  // (Paradigma/Siyaset/Teknolojî pasif, Sînema aktif). Bekçi artık kaydın
  // "uygulandı" olduğunu korur: canlı durum ile kayıt ayrışmasın.
  test('applied.md satırı uygulandı olarak duruyor', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    final row = applied
        .split('\n')
        .firstWhere(
          (line) => line.contains('2026-09-28_hidden_categories_inactive.sql'),
          orElse: () => '',
        );
    expect(row, contains('✅'));
  });

  group('2026-09-30 yeniden açma göçü', () {
    final reopen = File(
      'supabase/2026-09-30_hidden_categories_reopen.sql',
    ).readAsStringSync();
    final reopenStatements = reopen
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');

    test('üç kategoriyi slug ile etkinleştirir, tek işlemde', () {
      expect(reopenStatements, contains('begin;'));
      expect(reopenStatements, contains('commit;'));
      expect(reopenStatements, contains('update public.categories'));
      expect(reopenStatements, contains('set is_active = true'));
      final match = RegExp(
        r'where slug in \(([^)]*)\)',
      ).firstMatch(reopenStatements);
      expect(match, isNotNull, reason: 'slug listesi bulunamadı');
      final slugs = RegExp(
        r"'([^']+)'",
      ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
      expect(slugs, {'paradigma', 'siyaset', 'teknoloji'});
    });

    test('etkin değilse hata veren doğrulama bloğu var', () {
      expect(reopenStatements, contains(r'do $$'));
      expect(reopenStatements, contains('raise exception'));
      expect(reopenStatements, contains('is_active = true'));
      expect(reopenStatements, contains('<> 3'));
    });

    test('soruya dokunmaz, silmez, düşürmez', () {
      expect(reopenStatements, isNot(contains('public.questions')));
      expect(reopenStatements.toLowerCase(), isNot(contains('delete')));
      expect(reopenStatements.toLowerCase(), isNot(contains('drop ')));
    });

    test('NİÇİN başlığı, geri alma ve postflight dosyada yazılı', () {
      expect(reopen, contains('Neden:'));
      expect(reopen, contains('Geri alma'));
      expect(reopen, contains('set is_active = false'));
      expect(reopen, contains('Postflight'));
    });

    // Göç 2026-09-30'da canlıya uygulandı; kayıt ile canlı ayrışmasın.
    test('applied.md satırı var ve uygulandı (✅) olarak duruyor', () {
      final applied = File('supabase/applied.md').readAsStringSync();
      final row = applied
          .split('\n')
          .firstWhere(
            (line) => line.contains('2026-09-30_hidden_categories_reopen.sql'),
            orElse: () => '',
          );
      expect(row, isNotEmpty, reason: 'applied.md satırı eksik');
      expect(row, contains('✅'));
      expect(row, isNot(contains('⏳')));
    });
  });
}
