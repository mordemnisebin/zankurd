-- Geri alma: 2026-11-13_yonetim_moderasyon.sql
-- Yamalanan 2 işlevin (leaderboard_daily_rows, get_verified_daily_event_board) göç
-- anında olcek_tur3_yedek'e alınan eski gövdesini birebir geri yükler ve üç
-- moderasyon tetikleyicisini + işlevlerini siler. TAMAMEN YA DA HİÇ: önce iki yedek
-- satırı (yalnız bu kesin adlar; LIKE yok) ve md5 zincirleri doğrulanır; biri
-- eksik/bozuksa hiçbir şey geri alınmaz. İşlev yoksa ya da canlı gövde göçten sonra
-- değişmişse durur. Geri yükleme sonrası sahip/anon/PUBLIC/search_path doğrulanır
-- (CREATE OR REPLACE sahibi ve ACL'yi korur). KAPSAM: ileri göçün olcek_tur3_yedek
-- üzerindeki RLS/yetki kapatması geri ALINMAZ (zararsızdır); yalnız 'yonetim:' satırları silinir.
-- Kullanıcı moderasyon durumu (user_moderation) ve 2026-11-12 göçünün nesneleri
-- yerinde kalır.
begin;

set local lock_timeout = '10s';

create temp table yonetim_geri (
  imza text primary key, eski text not null, sahip oid not null, secdef boolean not null,
  ayar text[], acl text, gerek boolean not null
) on commit drop;

do $yonetim_geri$
declare
  v_imzalar text[] := array[
    'public.leaderboard_daily_rows(integer,uuid[])',
    'public.get_verified_daily_event_board()'];
  v_imza text;
  v_oid regprocedure;
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_gerek boolean;
begin
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or exists (
       select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
       where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
         and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
     ) then
    raise exception 'yonetim geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;

  -- 1. Aşama: hepsini doğrula, hiçbirine dokunma.
  foreach v_imza in array v_imzalar loop
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'yonetim geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'yonetim:' || v_imza for update;
    if v_yedek is null then
      raise exception 'yonetim geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'yonetim geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_gerek := false; -- zaten geri alınmış
    elsif md5(v_simdi) = v_yama then
      v_gerek := true;
    else
      raise exception 'yonetim geri: % canlı gövdesi göçün yazdığı gövde değil (başka bir değişiklik araya girmiş); hiçbir işlev geri alınmadı', v_imza;
    end if;
    insert into yonetim_geri
    select v_imza, v_eski, p.proowner, p.prosecdef, p.proconfig, p.proacl::text, v_gerek
    from pg_proc p where p.oid = v_oid;
  end loop;
end;
$yonetim_geri$;

-- 2. Aşama: eski gövdeleri yükle.
do $yonetim_geri2$
declare r record;
begin
  for r in select * from yonetim_geri where gerek loop
    execute r.eski;
  end loop;
end;
$yonetim_geri2$;

drop trigger if exists trg_moderation_room_players on public.room_players;
drop trigger if exists trg_moderation_async_duels on public.async_duels;
drop trigger if exists trg_moderation_room_messages on public.room_messages;
drop function if exists public.moderation_guard_room_player();
drop function if exists public.moderation_guard_async_duel();
drop function if exists public.moderation_guard_room_message();

-- Sahip / ACL / search_path / SECURITY DEFINER değişmedi; eski gövde birebir döndü.
do $yonetim_geri3$
declare r record;
begin
  for r in select * from yonetim_geri loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip and p.prosecdef = r.secdef
        and p.proconfig is not distinct from r.ayar
        and p.proacl::text is not distinct from r.acl
    ) then
      raise exception 'yonetim geri: % sahip / search_path / ACL doğrulanamadı', r.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(r.imza))) <> md5(r.eski) then
      raise exception 'yonetim geri: % geri yükleme sonrası gövde eski gövde değil', r.imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
       or has_function_privilege('public', to_regprocedure(r.imza), 'execute') then
      raise exception 'yonetim geri: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
end;
$yonetim_geri3$;

delete from public.olcek_tur3_yedek
where ad in (
  'yonetim:public.leaderboard_daily_rows(integer,uuid[])',
  'yonetim:public.get_verified_daily_event_board()');

commit;
