-- Geri alma: 2026-11-05_olcek_tur6.sql
-- Yamalanan dört işlevin (create_online_room_impl, reconcile_player_score_total,
-- get_tournament_bracket, resolve_expired_tournament_matches) göç anında
-- olcek_tur3_yedek'e alınan eski gövdesini birebir geri yükler; sonra göçün yarattığı
-- nesneleri kaldırır (cron işleri, process_tournament_expiry, günlük mutabakat
-- sweep/full işlevleri, kısmi indeks, imleç tablosu). TAMAMEN YA DA HİÇ: önce DÖRT yedek
-- satırı (yalnız bu kesin adlar; LIKE yok) ve md5 zincirleri doğrulanır; biri
-- eksik/bozuksa hiçbir şey geri alınmaz. İşlev yoksa ya da canlı gövde göçten sonra
-- değişmişse durur. Geri yükleme sonrası sahip/anon/PUBLIC/search_path doğrulanır
-- (CREATE OR REPLACE sahibi ve ACL'yi korur).
-- KAPSAM: ileri göçün olcek_tur3_yedek üzerindeki RLS/yetki kapatması geri ALINMAZ
-- (zararsızdır). Kalıcı imleç tablosundaki ilerleme kaybolur (yalnız tarama ilerlemesi).
-- Doğrulanan yedek değerleri geçici tabloda tutulur, yedek satırları FOR UPDATE ile
-- kilitlenir; geri yükleme oradan çalışır.
begin;

set local lock_timeout = '10s';

create temp table tur6_geri (
  imza text primary key, eski text not null, sahip oid not null, gerek boolean not null
) on commit drop;

do $tur6_geri$
declare
  v_imzalar text[] := array[
    'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
    'public.reconcile_player_score_total(integer,integer)',
    'public.get_tournament_bracket()',
    'public.resolve_expired_tournament_matches()'];
  v_imza text;
  v_oid regprocedure;
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_o oid;
  v_gerek boolean;
  r record;
begin
  -- Yedek tablosu istemci rollerine yazılabilir olmamalı.
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or exists (
       select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
       where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
         and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
     ) then
    raise exception 'tur6 geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;

  -- 1. Aşama: hepsini doğrula, hiçbirine dokunma.
  foreach v_imza in array v_imzalar loop
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'tur6 geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur6:' || v_imza for update;
    if v_yedek is null then
      raise exception 'tur6 geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'tur6 geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    select p.proowner into v_o from pg_proc p where p.oid = v_oid;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_gerek := false; -- zaten geri alınmış
    elsif md5(v_simdi) = v_yama then
      v_gerek := true;
    else
      raise exception 'tur6 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
    insert into tur6_geri values (v_imza, v_eski, v_o, v_gerek);
  end loop;

  -- 2. Aşama: geri yükle, yedek satırlarını sil.
  for r in select * from tur6_geri order by imza loop
    if r.gerek then
      execute r.eski;
      if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza) and p.proowner = r.sahip) then
        raise exception 'tur6 geri: % sahibi değişti', r.imza;
      end if;
    end if;
    delete from public.olcek_tur3_yedek where ad = 'tur6:' || r.imza;
  end loop;
end;
$tur6_geri$;

-- Göçün yarattığı nesneler. Gövdeler geri yüklendi (bracket yeniden kendi başına
-- süre dolumu yürütür), artık cron/yardımcılar gereksiz.
select cron.unschedule('tournament-expiry')
where exists (select 1 from cron.job where jobname = 'tournament-expiry');
select cron.unschedule('reconcile-player-score-daily-sweep')
where exists (select 1 from cron.job where jobname = 'reconcile-player-score-daily-sweep');
drop function if exists public.process_tournament_expiry();
drop function if exists public.reconcile_player_score_daily_sweep(integer, integer);
drop function if exists public.reconcile_player_score_daily_full(date, uuid, integer, integer);
drop index if exists public.tournament_matches_open_deadline_idx;
drop table if exists public.score_reconcile_daily_cursor;

do $tur6_geri_son$
declare
  v_imza text;
begin
  foreach v_imza in array array[
    'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)',
    'public.reconcile_player_score_total(integer,integer)',
    'public.get_tournament_bracket()',
    'public.resolve_expired_tournament_matches()'] loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(v_imza) and p.prosecdef and p.proconfig is not null
    ) then
      raise exception 'tur6 geri: % SECURITY DEFINER + search_path değil', v_imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(v_imza), 'execute')
       or has_function_privilege('public', to_regprocedure(v_imza), 'execute') then
      raise exception 'tur6 geri: % anon/PUBLIC EXECUTE açık', v_imza;
    end if;
  end loop;
end;
$tur6_geri_son$;

commit;
