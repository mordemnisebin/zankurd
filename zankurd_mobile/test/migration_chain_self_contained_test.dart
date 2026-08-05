import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Göç zinciri yalnız repo + Docker ile kurulabilmeli.
///
/// `2026-08-01_security_advisor_hardening.sql`, hiçbir göçte TANIMLANMAYAN
/// `rls_auto_enable()` fonksiyonuna koşulsuz bir `revoke` uyguluyordu.
/// Fonksiyon canlıda var (izlenmeyen bir kaynaktan geldi) ama temiz bir
/// veritabanında yok; `revoke` `42883` veriyor ve tek transaction olduğu
/// için dosyadaki DİĞER bütün revoke'lar da geri alınıyordu. Yani zincir
/// yeni bir makinede kurulamıyordu ve yerel doğrulama ancak elle stub
/// yazılarak ilerleyebilmişti (2026-08-03).
///
/// Bu bekçi iki şeyi birden korur: zincirin kendi kendine yeterliliğini ve
/// revoke'un güvenlik amacını — koşullu hâle gelmesi "sessizce atlandı"
/// anlamına gelmemeli.
void main() {
  final supabase = Directory('supabase');

  List<File> migrations() => supabase
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList();

  test('tanimsiz fonksiyona kosulsuz revoke kalmadi', () {
    // `rls_auto_enable` bu depoda hiçbir yerde tanımlanmıyor.
    final defined = migrations().any(
      (f) => RegExp(
        r'create\s+(or\s+replace\s+)?function\s+(public\.)?rls_auto_enable',
        caseSensitive: false,
      ).hasMatch(f.readAsStringSync()),
    );
    expect(defined, isFalse, reason: 'Tanim eklendiyse bu bekci guncellenmeli');

    for (final file in migrations()) {
      final sql = file.readAsStringSync();
      for (final line in sql.split('\n')) {
        final trimmed = line.trim();
        // Koşulsuz revoke: satır doğrudan `revoke` ile başlıyor.
        if (trimmed.startsWith(
          'revoke execute on function '
          'public.rls_auto_enable',
        )) {
          fail(
            '${file.path}: tanimsiz fonksiyona kosulsuz revoke — '
            'temiz kurulumda zincir kirilir',
          );
        }
      }
    }
  });

  test('revoke amaci korunuyor: fonksiyon varsa anon calistiramaz', () {
    final sql = File(
      'supabase/2026-08-01_security_advisor_hardening.sql',
    ).readAsStringSync();

    // Koşullu hâle gelmesi, güvenlik niyetinin silindiği anlamına
    // gelmemeli: varlık kontrolü VE revoke birlikte durmalı.
    expect(sql, contains("p.proname = 'rls_auto_enable'"));
    expect(
      sql,
      contains('revoke execute on function public.rls_auto_enable()'),
    );
    expect(sql, contains('from public, anon'));
    // Aynı adda argümanlı bir varyant yanlışlıkla eşleşmesin.
    expect(sql, contains('p.pronargs = 0'));
  });

  test('diger revoke hedefleri zincirde tanimli', () {
    // Bu dosyadaki revoke listesi uzun; hedeflerinden biri daha
    // tanımsızsa aynı kırılma yeniden yaşanır. `rls_auto_enable` tek
    // bilinen istisnadır ve yukarıda koşula bağlandı.
    final advisor = File(
      'supabase/2026-08-01_security_advisor_hardening.sql',
    ).readAsStringSync();
    final targets =
        RegExp(
            r'revoke execute on function public\.([a-z_]+)',
          ).allMatches(advisor).map((m) => m.group(1)!).toSet()
          ..remove('rls_auto_enable');
    expect(targets, isNotEmpty);

    final allSql =
        migrations().map((f) => f.readAsStringSync()).join('\n') +
        Directory('supabase/archive')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .map((f) => f.readAsStringSync())
            .join('\n');

    for (final fn in targets) {
      // Şema öneki ve büyük/küçük harf göçler arasında tutarsız:
      // eski dosyalar `CREATE OR REPLACE FUNCTION foo(`, yenileri
      // `create or replace function public.foo(` yazıyor. İkisi de geçerli.
      expect(
        RegExp(
          'create\\s+(or\\s+replace\\s+)?function\\s+(public\\.)?$fn\\b',
          caseSensitive: false,
        ).hasMatch(allSql),
        isTrue,
        reason: '$fn hicbir gocte tanimlanmiyor',
      );
    }
  });
}
