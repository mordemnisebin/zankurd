import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CI'da PostgreSQL yok: bu bekçi yetki/şema sözleşmesidir, çalışan SQL
// kanıtı değildir. Ayrı rollback duman testi tool/presence_smoke.sql'dedir.
void main() {
  final sql = File('supabase/2026-10-30_presence.sql')
      .readAsStringSync()
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n')
      .toLowerCase();

  test('T1 XP profiline yazmak RLS ve updated_at tetiklerini değiştirirdi; '
      'eski satır testleri sunucu yetkisini ölçmüyordu', () {
    expect(
      sql,
      contains('alter table public.user_presence enable row level security'),
    );
    expect(sql, contains('visible boolean not null default false'));
    expect(sql, contains('references auth.users(id) on delete cascade'));
    expect(sql, isNot(contains('update public.profiles')));
    expect(sql, isNot(contains('alter table public.profiles')));
    expect(sql, contains('grant select (user_id, visible, last_seen_at)'));
    expect(
      sql,
      contains(
        'revoke all on public.user_presence from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'f.user_id = (select auth.uid()) and f.friend_id = user_presence.user_id',
      ),
    );
  });

  test('T1 sahte kimlik ve sık çağrı varlığı şişiremez; istemci süresi '
      'sunucu kısıtı sanılıyordu', () {
    final touch = sql
        .split('create or replace function public.touch_presence()')[1]
        .split(r'$function$;')[0];
    expect(touch, contains('v_uid uuid := auth.uid()'));
    expect(touch, contains('clock_timestamp()'));
    expect(touch, contains('where user_id = v_uid and visible'));
    expect(touch, contains("last_touch_at <= v_now - interval '60 seconds'"));
    expect(touch, isNot(contains('insert into')));
    expect(touch, contains('security definer'));
    expect(touch, contains('set search_path = pg_catalog, public'));
    expect(
      sql,
      contains(
        'revoke all on function public.touch_presence() from public, anon',
      ),
    );
  });

  test('T1 kapatma eski zamanı da gizler ve yeniden açma hız sınırını '
      'sıfırlamaz; yalnız anahtar testi sunucu sızıntısını kaçırırdı', () {
    final setting = sql
        .split('create or replace function public.set_presence_visibility')[1]
        .split(r'$function$;')[0];
    expect(setting, contains('v_uid uuid := auth.uid()'));
    expect(
      setting,
      contains(
        'last_seen_at = case when excluded.visible then p.last_seen_at else null end',
      ),
    );
    expect(setting, isNot(contains('last_touch_at =')));
    expect(
      sql,
      contains('case when p.visible then p.last_seen_at else null end'),
    );
  });

  test('T1 eski göçü kopyalamak sonraki düzeltmeleri silerdi; RPC örnekleri '
      'canlı gövde kaybını görmüyordu', () {
    expect(
      sql,
      contains("pg_get_functiondef('public.list_friends()'::regprocedure)"),
    );
    expect(
      sql,
      contains(
        'alter function public.list_friends() rename to list_friends_before_presence',
      ),
    );
    expect(sql, contains('select f.*, case when p.visible'));
    expect(sql, contains('from public.list_friends_before_presence() f'));
    expect(
      sql,
      contains(
        "to_regprocedure('public.list_friends_before_presence()') is null",
      ),
    );
    expect(sql, contains('original list_friends definition was not preserved'));
    expect(sql, contains('security invoker'));
    expect(sql.trim(), startsWith('begin;'));
    expect(sql.trim(), endsWith('commit;'));
    expect(sql, contains(r'do $verify$'));
  });
}
