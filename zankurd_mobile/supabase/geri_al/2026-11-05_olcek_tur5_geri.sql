-- Geri alma: 2026-11-05_olcek_tur5.sql
-- Yamalanan iki işlevin (join_matchmaking, get_my_league) göç anında
-- olcek_tur3_yedek'e alınan eski gövdesini birebir geri yükler (yedek satırı
-- 'tur5:<imza>'); canlı gövdenin md5'i göçten sonraki yamalı gövdeyle
-- uyuşmuyorsa (araya başka göç girmişse) durur. Yedek yoksa dokunmaz.
begin;

set local lock_timeout = '10s';

do $tur5_geri$
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
    where y.ad like 'tur5:%'
    order by y.ad
  loop
    v_imza := substr(r.ad, 6);
    v_yama := substring(r.tanim from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(r.tanim, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = r.tanim
       or substring(r.tanim from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'tur5 geri: % yedeği bozuk', v_imza;
    end if;
    v_simdi := pg_get_functiondef(to_regprocedure(v_imza));
    if md5(v_simdi) = md5(v_eski) then
      delete from public.olcek_tur3_yedek where ad = r.ad;
      continue; -- zaten geri alınmış
    end if;
    if md5(v_simdi) <> v_yama then
      raise exception 'tur5 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
    execute v_eski;
    delete from public.olcek_tur3_yedek where ad = r.ad;
  end loop;
end;
$tur5_geri$;

commit;
