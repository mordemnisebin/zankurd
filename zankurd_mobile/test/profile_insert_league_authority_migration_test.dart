import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ekonomi ve lig sıralaması istemciden yazılamaz.
///
/// ## Kusurlar
///
/// İkisi de 2026-08-06'da, temiz bir üretim şeması klonunda, gerçek
/// `authenticated` rolü ve gerçek `request.jwt.claims` altında —
/// PostgREST'in çalıştırdığı mekanizmanın aynısı — üretildi.
///
/// 1. **Profil INSERT'inde sunucu yetkisi yoktu.**
///    `profiles_client_write_guard_trg` yalnız `BEFORE UPDATE`ti; INSERT
///    yolunda ekonomiyi koruyan hiçbir şey yoktu. INSERT politikası da
///    yalnız satırın sahibini doğruluyor, sütunları değil. Profil satırı
///    `auth.users` tetikleyicisiyle DEĞİL istemci tarafından açıldığı
///    için (`ensureProfile`/`upsertProfile`), her yeni kullanıcının ilk
///    yazımı tamamen kendi denetimindeydi:
///
///        insert into profiles (id, ..., coins, xp, rating)
///        values (<kendi uid>, ..., 999999, 888888, 7777);  -- KABUL
///
///    Coin gerçek mağaza parası, rating ise liderliğin kendisi.
///
///    Aynı oturumda ÇÜRÜTÜLEN yollar (zaten kapalıydı, dokunulmadı):
///    başka uid için satır açmak RLS'e takılıyor, kendi satırını silmek
///    0 satır etkiliyor, `on conflict do update` ise UPDATE guard'ına
///    düşüp coins/rating'i geri alıyor. Delik tam olarak ilk INSERT'ti.
///
/// 2. **Haftalık ligi herkes kapatabiliyordu.** `finalize_weekly_league`
///    `SECURITY DEFINER`, `authenticated` rolünde EXECUTE yetkisi var ve
///    gövdesinde rol kontrolü yok. Düz bir kullanıcı olarak çağrıldı ve
///    başarılı oldu. Fonksiyon salt okunur değil: haftayı 'closed'
///    yapıyor, `league_memberships`i silip yeniden yazıyor, terfi/düşme
///    hesaplıyor. İstemci bu RPC'yi hiç çağırmıyor — `lib/` içinde tek
///    geçtiği yer bir yorum satırı.
void main() {
  final migration = File(
    'supabase/2026-08-06_profile_insert_and_league_authority.sql',
  );

  late String sql;

  setUpAll(() {
    expect(migration.existsSync(), isTrue);
    sql = migration.readAsStringSync().toLowerCase();
  });

  group('profil INSERT yetkisi', () {
    test('INSERT tetikleyicisi kuruldu', () {
      expect(sql, contains('before insert on public.profiles'));
      expect(sql, contains('profiles_client_insert_authority'));
    });

    test('yalnız istemci rolleri kısıtlanır — sunucu yolları serbest', () {
      expect(
        sql,
        contains("current_user in ('authenticated', 'anon')"),
        reason:
            'security definer RPC\'ler postgres olarak çalışır; onlar '
            'kısıtlanırsa ödül ve mağaza yolları kırılır',
      );
    });

    test('ekonomi sütunları sunucu başlangıç değerine çekilir', () {
      expect(sql, contains('new.coins := 0'));
      expect(sql, contains('new.rating := 1000'));
      expect(sql, contains('new.xp := 0'));
      expect(sql, contains('new.xp_daily_total := 0'));
      expect(sql, contains('new.xp_daily_date := null'));
    });

    test('mevcut UPDATE guard yeniden tanımlanmadı', () {
      // Fazladan bir tanım, UPDATE korumasını sessizce zayıflatabilirdi.
      expect(
        sql,
        isNot(
          contains(
            'create or replace function public.profiles_client_write_guard()',
          ),
        ),
        reason: 'UPDATE guard bu göçün konusu değil; ona dokunulmamalı',
      );
    });

    test('INSERT politikası veya RLS gevşetilmedi', () {
      for (final forbidden in [
        'drop policy',
        'disable row level security',
        'create policy',
      ]) {
        expect(
          sql,
          isNot(contains(forbidden)),
          reason: 'Yetki eklenmeli, erişim genişletilmemeli',
        );
      }
    });
  });

  group('haftalık lig finalizasyonu', () {
    test('authenticated ve anon yetkisi geri alındı', () {
      expect(
        sql,
        contains(
          'revoke execute on function public.finalize_weekly_league(date) '
          'from authenticated',
        ),
      );
      expect(
        sql,
        contains(
          'revoke execute on function public.finalize_weekly_league(date) '
          'from anon',
        ),
      );
    });

    test('planlanmış sunucu yolu korundu', () {
      expect(
        sql,
        contains(
          'grant execute on function public.finalize_weekly_league(date) '
          'to service_role',
        ),
        reason: 'Haftalık kapanış çalışmaya devam etmeli',
      );
    });

    test('fonksiyon gövdesi yeniden yazılmadı', () {
      expect(
        sql,
        isNot(
          contains('create or replace function public.finalize_weekly_league'),
        ),
        reason:
            'Yetki sorunu yetkiyle çözülür; lig hesabının kendisi bu '
            'göçün konusu değil',
      );
    });

    test('istemci bu RPC\'yi hâlâ çağırmıyor', () {
      final repo = File(
        'lib/src/data/supabase_zankurd_repository.dart',
      ).readAsStringSync();
      expect(
        repo,
        isNot(contains("'finalize_weekly_league'")),
        reason:
            'İstemci çağırmaya başlarsa revoke onu kırar; o durumda bu '
            'karar yeniden düşünülmeli',
      );
    });
  });

  test('göç ileri yönlü ve tek işlem', () {
    expect(sql.trimLeft(), contains('begin;'));
    expect(sql, contains('commit;'));
  });
}
