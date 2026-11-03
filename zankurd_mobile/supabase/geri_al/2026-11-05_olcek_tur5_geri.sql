-- Geri alma: 2026-11-05_olcek_tur5.sql
-- Yamalanan iki işlevin (join_matchmaking, get_my_league) göç anında
-- olcek_tur3_yedek'e alınan eski gövdesini birebir geri yükler. TAMAMEN YA DA
-- HİÇ: önce İKİ yedek satırı (yalnız bu iki kesin ad; LIKE yok) ve md5 zincirleri
-- doğrulanır; biri eksik/bozuksa hiçbir şey geri alınmaz. İşlev yoksa (araya
-- başka göç DROP ettiyse) ya da canlı gövde göçten sonra değişmişse durur.
-- Geri yükleme sonrası ACL açıkça yeniden kurulur ve doğrulanır.
begin;

set local lock_timeout = '10s';

do $tur5_geri$
declare
  v_imzalar text[] := array['public.join_matchmaking(text)', 'public.get_my_league()'];
  v_imza text;
  v_oid regprocedure;
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_geri_gerek boolean[] := array[false, false];
  v_i integer;
begin
  -- Yedek tablosu istemci rollerine yazılabilir olmamalı.
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete') then
    raise exception 'tur5 geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;

  -- 1. Aşama: hepsini doğrula, hiçbirine dokunma.
  for v_i in 1 .. array_length(v_imzalar, 1) loop
    v_imza := v_imzalar[v_i];
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'tur5 geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur5:' || v_imza;
    if v_yedek is null then
      raise exception 'tur5 geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'tur5 geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_geri_gerek[v_i] := false; -- zaten geri alınmış
    elsif md5(v_simdi) = v_yama then
      v_geri_gerek[v_i] := true;
    else
      raise exception 'tur5 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
  end loop;

  -- 2. Aşama: geri yükle, yedek satırlarını sil.
  for v_i in 1 .. array_length(v_imzalar, 1) loop
    v_imza := v_imzalar[v_i];
    if v_geri_gerek[v_i] then
      select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'tur5:' || v_imza;
      execute regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    end if;
    delete from public.olcek_tur3_yedek where ad = 'tur5:' || v_imza;
  end loop;
end;
$tur5_geri$;

-- CREATE OR REPLACE sahibi ve ACL'yi korur; yine de açıkça kur ve doğrula.
revoke all on function public.join_matchmaking(text) from public, anon;
grant execute on function public.join_matchmaking(text) to authenticated;
revoke all on function public.get_my_league() from public, anon;
grant execute on function public.get_my_league() to authenticated;

do $tur5_geri_son$
declare
  v_imza text;
begin
  foreach v_imza in array array['public.join_matchmaking(text)', 'public.get_my_league()'] loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(v_imza)
        and p.prosecdef
        and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')
    ) then
      raise exception 'tur5 geri: % SECURITY DEFINER + search_path değil', v_imza;
    end if;
    if has_function_privilege('anon', to_regprocedure(v_imza), 'execute')
       or has_function_privilege('public', to_regprocedure(v_imza), 'execute') then
      raise exception 'tur5 geri: % anon/PUBLIC EXECUTE açık', v_imza;
    end if;
  end loop;
end;
$tur5_geri_son$;

commit;
