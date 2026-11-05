-- Geri alma: 2026-11-16_w4_push_cihazlar.sql
-- clear_my_fcm_token(), clear_my_fcm_token(text) ve wake_push_delivery_v2()'nin göç anında
-- olcek_tur3_yedek'e alınan eski gövdelerini birebir geri yükler; senkron tetikleyicisini,
-- cihaz işlevlerini ve push_devices tablosunu siler. TAMAMEN YA DA HİÇ: yedek satırları ve md5
-- zinciri doğrulanmadan, ya da canlı gövde göçten sonra değişmişse hiçbir şey geri alınmaz.
-- UYARI: push_devices silinince çok cihazlı kayıtlar gider; her kullanıcıda yalnız
-- profiles.fcm_token (son cihaz) kalır. Edge (send-push) `get_push_device_tokens` yokluğunda
-- (PGRST202) yalnız claim'in verdiği tek jetona gönderir: önce Edge'i geri alın ya da uyumlu bırakın.
begin;

set local lock_timeout = '10s';

do $w4p_geri$
declare
  r record;
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_sahip oid;
  v_oid regprocedure;
begin
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or exists (
       select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
       where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
         and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
     ) then
    raise exception 'w4p geri: olcek_tur3_yedek istemci tarafından yazılabilir; yedek güvenilmez';
  end if;
  -- Önce HEPSİ doğrulanır; sonra geri yüklenir (hep ya da hiç).
  for r in select imza from (values
    ('public.clear_my_fcm_token()'), ('public.clear_my_fcm_token(text)'),
    ('public.wake_push_delivery_v2()')) as t(imza)
  loop
    v_oid := to_regprocedure(r.imza);
    if v_oid is null then
      raise exception 'w4p geri: % yok; geri alma durdu', r.imza;
    end if;
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w4:' || r.imza;
    if v_yedek is null then
      raise exception 'w4p geri: % yedek satırı yok; hiçbir şey geri alınmadı', r.imza;
    end if;
    v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    if v_yama is null or v_eski = v_yedek
       or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
      raise exception 'w4p geri: % yedeği bozuk (md5 zinciri); hiçbir şey geri alınmadı', r.imza;
    end if;
    v_simdi := pg_get_functiondef(v_oid);
    if md5(v_simdi) <> md5(v_eski) and md5(v_simdi) <> v_yama then
      raise exception 'w4p geri: % canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele', r.imza;
    end if;
  end loop;
  for r in select imza from (values
    ('public.clear_my_fcm_token()'), ('public.clear_my_fcm_token(text)'),
    ('public.wake_push_delivery_v2()')) as t(imza)
  loop
    v_oid := to_regprocedure(r.imza);
    select y.tanim into v_yedek from public.olcek_tur3_yedek y where y.ad = 'w4:' || r.imza for update;
    v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
    select p.proowner into v_sahip from pg_proc p where p.oid = v_oid;
    if md5(pg_get_functiondef(v_oid)) <> md5(v_eski) then
      execute v_eski;
      if not exists (select 1 from pg_proc p where p.oid = to_regprocedure(r.imza)
                     and p.proowner = v_sahip) then
        raise exception 'w4p geri: % sahibi değişti', r.imza;
      end if;
    end if;
    delete from public.olcek_tur3_yedek where ad = 'w4:' || r.imza;
  end loop;
end;
$w4p_geri$;

drop trigger if exists trg_profiles_fcm_devices_sync on public.profiles;
drop function if exists public.profiles_fcm_devices_sync();
drop function if exists public.get_push_device_tokens(uuid);
drop function if exists public.clear_push_device(uuid, text);
drop table if exists public.push_devices;

do $w4p_geri_son$
begin
  if has_function_privilege('anon', 'public.clear_my_fcm_token()', 'execute')
     or has_function_privilege('public', 'public.clear_my_fcm_token()', 'execute')
     or has_function_privilege('anon', 'public.clear_my_fcm_token(text)', 'execute')
     or has_function_privilege('public', 'public.clear_my_fcm_token(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.clear_my_fcm_token()', 'execute')
     or not has_function_privilege('authenticated', 'public.clear_my_fcm_token(text)', 'execute') then
    raise exception 'w4p geri: clear_my_fcm_token EXECUTE yetkisi bozuldu';
  end if;
  if has_function_privilege('anon', 'public.wake_push_delivery_v2()', 'execute')
     or has_function_privilege('authenticated', 'public.wake_push_delivery_v2()', 'execute') then
    raise exception 'w4p geri: wake_push_delivery_v2 istemciye açık';
  end if;
end;
$w4p_geri_son$;

commit;
