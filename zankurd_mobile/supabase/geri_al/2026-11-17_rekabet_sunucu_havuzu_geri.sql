-- Geri alma: 2026-11-17_rekabet_sunucu_havuzu.sql
-- Yamalanan 6 işlevin göç anında olcek_tur3_yedek'e ('w10:<imza>') alınan eski gövdesini
-- birebir geri yükler, sonra iki yardımcıyı (_w10_competitive_pool, _w10_daily_server_only)
-- düşürür. TAMAMEN YA DA HİÇ: önce 6 yedek satırı ve md5 zincirleri doğrulanır; biri
-- eksik/bozuksa hiçbir şey geri alınmaz. Canlı gövde göçten sonra değişmişse durur.
-- KAPSAM: questions.server_only / prompt_tr / options_tr sütunları, questions_options_tr_shape
-- kısıtı, questions_server_only_pool_idx indeksi ve app_runtime_config.
-- competitive_server_only_pool sütunu SİLİNMEZ (paket 4 satırlarının verisi kaybolmasın);
-- gövdeler eskiye dönünce bayrak etkisizdir. Yedek tablosu kapatması geri ALINMAZ.
begin;

set local lock_timeout = '10s';

create temp table w10_geri (
  imza text primary key, eski text not null, sahip oid not null, gerek boolean not null
) on commit drop;

do $w10_geri$
declare
  v_imzalar text[] := array[
    'public.weighted_question_pick(uuid[],uuid[],integer)',
    'public.async_duel_questions_payload(uuid[])',
    'public.present_async_duel_question_v2(uuid,integer)',
    'public._w2_daily_set(date)',
    'public.present_verified_daily_question(uuid,integer)',
    'public.get_room_questions_v2(uuid)'];
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
    raise exception 'w10 geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;

  -- 1. Aşama: hepsini doğrula, hiçbirine dokunma.
  foreach v_imza in array v_imzalar loop
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'w10 geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w10:' || v_imza for update;
    if v_yedek is null then
      raise exception 'w10 geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'w10 geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    select p.proowner into v_o from pg_proc p where p.oid = v_oid;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_gerek := false; -- zaten geri alınmış
    elsif md5(v_simdi) = v_yama then
      v_gerek := true;
    else
      raise exception 'w10 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
    insert into w10_geri values (v_imza, v_eski, v_o, v_gerek);
  end loop;

  -- 2. Aşama: geri yükle, yedek satırlarını sil.
  for r in select * from w10_geri order by imza loop
    if r.gerek then
      execute r.eski;
      if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza) and p.proowner = r.sahip) then
        raise exception 'w10 geri: % sahibi değişti', r.imza;
      end if;
    end if;
    delete from public.olcek_tur3_yedek where ad = 'w10:' || r.imza;
  end loop;
end;
$w10_geri$;

-- Geri yükleme sonrası: SECURITY DEFINER / search_path yedekteki (eski) gövdeyle
-- tutarlı; tetikleyici olmayan işlevlerde anon/PUBLIC EXECUTE yok.
do $w10_geri_son$
declare
  r record;
  v_tetik boolean;
begin
  for r in select * from w10_geri loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = (split_part(r.eski, E'AS $', 1) ~* 'security definer')
        and (p.proconfig is not null) = (split_part(r.eski, E'AS $', 1) ~* 'set search_path')
    ) then
      raise exception 'w10 geri: % SECURITY DEFINER / search_path / sahip eski gövdeyle tutarsız', r.imza;
    end if;
    select p.prorettype = 'trigger'::regtype into v_tetik
    from pg_proc p where p.oid = to_regprocedure(r.imza);
    if not v_tetik
       and (has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
            or has_function_privilege('public', to_regprocedure(r.imza), 'execute')) then
      raise exception 'w10 geri: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
end;
$w10_geri_son$;

-- Yardımcılar: artık hiçbir gövde başvurmuyor (yukarıda eski gövdeler geri yüklendi).
drop function if exists public._w10_competitive_pool(uuid[], integer);
drop function if exists public._w10_daily_server_only();

commit;
