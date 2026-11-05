-- Geri alma: 2026-11-16_w1_odul_moderasyon.sql
-- Yamalanan 11 işlevin göç anında olcek_tur3_yedek'e ('w1:<imza>') alınan eski gövdesini
-- birebir geri yükler, ardından göçün YENİ işlevlerini ve tetikleyicisini siler. TAMAMEN YA
-- DA HİÇ: önce 11 yedek satırı (yalnız bu kesin adlar; LIKE yok) ve md5 zincirleri
-- doğrulanır; biri eksik/bozuksa hiçbir şey geri alınmaz. İşlev yoksa ya da canlı gövde
-- göçten sonra değişmişse durur. Geri yükleme sonrası sahip/anon/PUBLIC/search_path
-- doğrulanır (CREATE OR REPLACE sahibi ve ACL'yi korur).
-- KAPSAM: eklenen veri nesneleri (usage_daily_active.solo_n, admin_contributor_rewards.request_id
-- + benzersiz indeks) BİLEREK kalır: veri taşıyabilir, eski gövdeler onları kullanmaz.
-- Ayrıca olcek_tur3_yedek RLS/yetki kapatması geri ALINMAZ (zararsızdır).
begin;

set local lock_timeout = '10s';

create temp table w1_geri (
  imza text primary key, eski text not null, sahip oid not null, gerek boolean not null
) on commit drop;

do $w1_geri$
declare
  v_imzalar text[] := array[
    'public.claim_verified_solo_reward(uuid)',
    'public.claim_share_reward()',
    'public.redeem_referral_code(text)',
    'public.spend_coins_once(integer,text,text)',
    'public.record_activity(boolean)',
    'public.admin_reward_contributor(uuid,integer,text)',
    'public.admin_moderate_user(uuid,text,integer,text)',
    'public.get_my_league()',
    'public.ack_my_league_result()',
    'public.push_delivery_v2_allowed(uuid,uuid,text,timestamptz,jsonb)',
    'public.admin_enqueue_push()'];
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
    raise exception 'w1 geri: olcek_tur3_yedek anon/authenticated tarafından yazılabilir; yedek güvenilmez';
  end if;

  -- 1. Aşama: hepsini doğrula, hiçbirine dokunma.
  foreach v_imza in array v_imzalar loop
    v_oid := to_regprocedure(v_imza);
    if v_oid is null then
      raise exception 'w1 geri: % yok; geri alma durdu (yeniden yaratma yok)', v_imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w1:' || v_imza for update;
    if v_yedek is null then
      raise exception 'w1 geri: % yedek satırı yok; hiçbir işlev geri alınmadı', v_imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'w1 geri: % yedeği bozuk (md5 zinciri); hiçbir işlev geri alınmadı', v_imza;
    end if;
    select p.proowner into v_o from pg_proc p where p.oid = v_oid;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) = md5(v_eski) then
      v_gerek := false; -- zaten geri alınmış
    elsif md5(v_simdi) = v_yama then
      v_gerek := true;
    else
      raise exception 'w1 geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', v_imza;
    end if;
    insert into w1_geri values (v_imza, v_eski, v_o, v_gerek);
  end loop;

  -- 2. Aşama: geri yükle, yedek satırlarını sil.
  for r in select * from w1_geri order by imza loop
    if r.gerek then
      execute r.eski;
      if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza) and p.proowner = r.sahip) then
        raise exception 'w1 geri: % sahibi değişti', r.imza;
      end if;
    end if;
    delete from public.olcek_tur3_yedek where ad = 'w1:' || r.imza;
  end loop;
end;
$w1_geri$;

-- Göçün yeni nesneleri: yama gövdeleri geri yüklendi, artık onlara bağlı değil.
drop trigger if exists trg_w1_tournament_entries_restricted on public.tournament_entries;
drop function if exists public.w1_guard_tournament_entry();
drop function if exists public.admin_reward_contributor(uuid, integer, text, uuid);

-- Geri yükleme sonrası: SECURITY DEFINER / search_path yedekteki (eski) gövdeyle
-- tutarlı; tetikleyici olmayan işlevlerde anon/PUBLIC EXECUTE yok.
do $w1_geri_son$
declare
  r record;
  v_tetik boolean;
begin
  for r in select * from w1_geri loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(r.imza)
        and p.proowner = r.sahip
        and p.prosecdef = (split_part(r.eski, E'AS $', 1) ~* 'security definer')
        and (p.proconfig is not null) = (split_part(r.eski, E'AS $', 1) ~* 'set search_path')
    ) then
      raise exception 'w1 geri: % SECURITY DEFINER / search_path / sahip eski gövdeyle tutarsız', r.imza;
    end if;
    select p.prorettype = 'trigger'::regtype into v_tetik
    from pg_proc p where p.oid = to_regprocedure(r.imza);
    if not v_tetik
       and (has_function_privilege('anon', to_regprocedure(r.imza), 'execute')
            or has_function_privilege('public', to_regprocedure(r.imza), 'execute')) then
      raise exception 'w1 geri: % anon/PUBLIC EXECUTE açık', r.imza;
    end if;
  end loop;
end;
$w1_geri_son$;

commit;
