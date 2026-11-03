-- Geri alma: 2026-11-05_olcek_tur4.sql
-- Yamalanan beş işlevin (recompute_player_score_day, rebuild_player_score_daily,
-- reconcile_player_score_daily, leaderboard_daily_rows, weekly_league_assign)
-- göç anında olcek_tur3_yedek'e alınan eski gövdesini birebir geri yükler
-- (yedek satırı 'tur4:<imza>'); sonra yeni işlevleri ve player_score_total
-- tablosunu kaldırır. Yedek yoksa (göç hiç yamalamadıysa) o işleve dokunmaz.
-- Sıra önemli: okuyan işlev (leaderboard_daily_rows) tabloyu bırakmadan önce
-- eski gövdesine döner.
begin;

set local lock_timeout = '10s';

do $tur4_geri$
declare
  r record;
  v_eski text;
  v_yama text;
  v_imza text;
  v_simdi text;
begin
  for r in
    select y.ad, y.tanim
    from public.olcek_tur3_yedek y
    where y.ad like 'tur4:%'
    order by y.ad
  loop
    v_imza := substr(r.ad, 6);
    v_yama := substring(r.tanim from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(r.tanim, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = r.tanim
       or substring(r.tanim from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'tur4 geri: % yedeği bozuk', v_imza;
    end if;
    v_simdi := pg_get_functiondef(to_regprocedure(v_imza));
    if md5(v_simdi) = md5(v_eski) then
      delete from public.olcek_tur3_yedek where ad = r.ad;
      continue; -- zaten geri alınmış
    end if;
    if md5(v_simdi) <> v_yama then
      raise exception 'tur4 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
    execute v_eski;
    delete from public.olcek_tur3_yedek where ad = r.ad;
  end loop;
end;
$tur4_geri$;

drop function if exists public.reconcile_player_score_total(integer, integer);
drop function if exists public.rebuild_player_score_total_all();
drop function if exists public.rebuild_player_score_total(uuid, integer);
drop function if exists public.refresh_player_score_total(uuid);
drop table if exists public.score_total_reconcile_cursor;
drop table if exists public.player_score_total;

commit;
