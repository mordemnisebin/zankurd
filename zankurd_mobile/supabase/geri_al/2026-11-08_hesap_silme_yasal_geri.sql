-- Geri alma: 2026-11-08_hesap_silme_yasal.sql
-- delete_my_account'un göç anında olcek_tur3_yedek'e alınan eski gövdesini birebir geri
-- yükler ve yardımcı anonimleştirme işlevini siler. TAMAMEN YA DA HİÇ: yedek satırı ve md5
-- zinciri doğrulanmadan, ya da canlı gövde göçten sonra değişmişse hiçbir şey geri alınmaz.
-- Geri yükleme sonrası sahip/anon/PUBLIC doğrulanır (CREATE OR REPLACE sahibi ve ACL'yi korur).
-- Not: göçten ÖNCE anonimleştirilmiş anlık görüntüler geri alınmaz (geri alınacak bir şey yok).
begin;

set local lock_timeout = '10s';

do $tur10_geri$
declare
  v_yedek text;
  v_eski text;
  v_yama text;
  v_simdi text;
  v_oid regprocedure := to_regprocedure('public.delete_my_account()');
  v_sahip oid;
begin
  if has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete')
     or exists (
       select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
       where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
         and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
     ) then
    raise exception 'tur10 geri: olcek_tur3_yedek istemci tarafından yazılabilir; yedek güvenilmez';
  end if;
  if v_oid is null then
    raise exception 'tur10 geri: delete_my_account yok; geri alma durdu';
  end if;
  select y.tanim into v_yedek from public.olcek_tur3_yedek y
  where y.ad = 'tur10:public.delete_my_account()' for update;
  if v_yedek is null then
    raise exception 'tur10 geri: yedek satırı yok; hiçbir şey geri alınmadı';
  end if;
  v_yama := substring(v_yedek from E'\n-- yama-md5:([0-9a-f]+)$');
  v_eski := regexp_replace(v_yedek, E'\n-- md5:[0-9a-f]+\n-- yama-md5:[0-9a-f]+$', '');
  if v_yama is null or v_eski = v_yedek
     or substring(v_yedek from E'\n-- md5:([0-9a-f]+)\n') <> md5(v_eski) then
    raise exception 'tur10 geri: yedek bozuk (md5 zinciri); hiçbir şey geri alınmadı';
  end if;
  select p.proowner into v_sahip from pg_proc p where p.oid = v_oid;
  v_simdi := pg_get_functiondef(v_oid);
  if md5(v_simdi) = md5(v_eski) then
    null; -- zaten geri alınmış
  elsif md5(v_simdi) = v_yama then
    execute v_eski;
    if not exists (select 1 from pg_proc p where p.oid = to_regprocedure('public.delete_my_account()')
                   and p.proowner = v_sahip) then
      raise exception 'tur10 geri: delete_my_account sahibi değişti';
    end if;
  else
    raise exception 'tur10 geri: delete_my_account canlı gövdesi göçten sonra değişmiş (md5 uyuşmuyor); elle incele';
  end if;
  delete from public.olcek_tur3_yedek where ad = 'tur10:public.delete_my_account()';
end;
$tur10_geri$;

-- Yardımcı artık çağrılmaz; sil.
drop function if exists public.anonymize_deleted_user_in_snapshots(uuid);

do $tur10_geri_son$
begin
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute')
     or has_function_privilege('public', 'public.delete_my_account()', 'execute') then
    raise exception 'tur10 geri: delete_my_account anon/PUBLIC EXECUTE açık';
  end if;
  if not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then
    raise exception 'tur10 geri: delete_my_account authenticated EXECUTE yok';
  end if;
end;
$tur10_geri_son$;

commit;
