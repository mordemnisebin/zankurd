/// Haftalık lig kapanışı istemciye kapalı — sözleşme bekçisi.
///
/// ## Kusur
///
/// `finalize_weekly_league(date)` SECURITY DEFINER'dı ve `authenticated`
/// rolüne açıktı; gövdesinde çağıran denetimi yoktu. Giriş yapmış herhangi
/// bir oyuncu süren haftanın lig üyeliklerini silip yarım skorlarla yeniden
/// yazdırabilir, haftayı `closed` yapabilirdi (2026-10-24 güvenlik denetimi).
///
/// ## Niçin sessiz kalırdı
///
/// İstemci fonksiyonu hiç çağırmıyor; açık kalması hiçbir ekranda görünmez.
/// Supabase yeni fonksiyonlara varsayılan olarak EXECUTE verir, yani yeni bir
/// `create or replace` yetkiyi sessizce geri getirebilir.
///
/// ## Kural
///
/// Geri alma göçü var, üç rolden de alır ve applied.md'de uygulandı olarak
/// kayıtlıdır. Fonksiyonu yeniden tanımlayan sonraki bir göç yetkiyi de
/// yeniden almalıdır.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const migration = 'supabase/2026-10-24_lig_kapanisi_yetki.sql';

  test('lig kapanışı anon/authenticated/public rollerinden alınmış', () {
    final sql = File(migration).readAsStringSync();
    expect(
      sql,
      contains(
        'revoke execute on function public.finalize_weekly_league(date) '
        'from public, anon, authenticated;',
      ),
    );
    expect(sql.trimRight(), endsWith('commit;'));
  });

  test(
    'sonraki göçler lig kapanışını yeniden tanımlarsa yetkiyi geri alır',
    () {
      final later = Directory('supabase')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .where(
            (f) =>
                f.path.split('/').last.compareTo(migration.split('/').last) > 0,
          );
      for (final file in later) {
        final sql = file.readAsStringSync();
        if (!sql.contains('function public.finalize_weekly_league')) continue;
        expect(
          sql,
          contains('revoke execute on function public.finalize_weekly_league'),
          reason:
              '${file.path} lig kapanışını yeniden tanımlıyor ama yetkiyi '
              'geri almıyor; istemci yeniden çağırabilir.',
        );
      }
    },
  );

  test('applied.md kaydı var', () {
    expect(
      File('supabase/applied.md').readAsStringSync(),
      contains('2026-10-24_lig_kapanisi_yetki.sql'),
    );
  });
}
