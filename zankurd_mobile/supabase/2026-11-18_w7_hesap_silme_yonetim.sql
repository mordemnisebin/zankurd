-- W7 / 2.1.2 (GPT-6 Pro ALAN 7 bulgu 1.3): hesap silinince yönetim kayıtlarında kullanıcı kimliği /
-- adı / notu kalıyordu. Geri alma: geri_al/2026-11-18_w7_hesap_silme_yonetim_geri.sql
--
-- NİÇİN (kodda doğrulandı)
--  admin_audit_log, admin_reward_grants, admin_contributor_rewards, user_moderation ve
--  admin_settings kullanıcıyı auth.users'a bağlamadan (düz uuid) ya da yalnız bir yönde
--  bağlayarak tutuyor; delete_my_account bu tablolara dokunmuyordu. Silinen hesabın UUID'si,
--  panelden yazılan görünen adı (detail.label) ve moderasyon notu (detail.note) günlükte
--  süresiz kalıyordu; gizlilik metni ve "hesabını sil" sayfası verinin silindiğini söylüyor.
--
--  Çözüm: `anonymize_deleted_user_in_admin_records(uuid)` (SECURITY DEFINER, istemciye KAPALI)
--  delete_my_account'tan, auth.users silinmeden önce çağrılır:
--   * admin_audit_log: hedef bu kullanıcıysa target_id sıfır-UUID'ye, detail'den 'note' atılır,
--     'label' "Hesabê jêbirî"ya çevrilir; detail içinde geçen kimlik metni her yerde sıfır-UUID
--     olur; admin_id bu kullanıcıysa (sahip kendi hesabını siliyor) sıfır-UUID olur.
--   * admin_reward_grants / admin_contributor_rewards: user_id satır başına RASTGELE yeni
--     uuid'e çevrilir (benzersizlik kısıtı çökmesin, kimlik geri çıkarılamasın); granted_by
--     bu kullanıcıysa sıfır-UUID (manual satırın "granted_by dolu" kısıtı korunur).
--   * user_moderation: satır zaten auth.users CASCADE ile gider; updated_by bu kullanıcıysa
--     sıfır-UUID (başkasına verilen moderasyonda yazan yönetici kimliği silinir).
--   * admin_settings.updated_by: boşaltılır.
--  Silinen hesabın para/ödül SAYILARI (coins, rank, dönem) korunur; yalnız kimlik bağı kopar.
--
-- Taban (canlı ✅, W4 sonrası, applied.md): delete_my_account md5 109b68e209e89f73d6cc3e5cdf5d6ba0.
-- Başka her durumda göç durur. Eski gövde 'w7:public.delete_my_account()' olarak
-- olcek_tur3_yedek'e alınır (md5 zinciri). Önce canlıda kuru çalıştırma:
--   select md5(pg_get_functiondef('public.delete_my_account()'::regprocedure));
-- = 109b68e209e89f73d6cc3e5cdf5d6ba0 olmalı.
-- Eski istemci sözleşmesi: delete_my_account imzası/dönüşü değişmez.
begin;

set local lock_timeout = '10s';

do $w7_onkosul$
begin
  if to_regprocedure('public.delete_my_account()') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regclass('public.admin_audit_log') is null
     or to_regclass('public.admin_reward_grants') is null
     or to_regclass('public.admin_contributor_rewards') is null
     or to_regclass('public.user_moderation') is null
     or to_regclass('public.admin_settings') is null then
    raise exception 'w7: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  if to_regprocedure('public.anonymize_deleted_user_in_admin_records(uuid)') is not null
     or exists (select 1 from public.olcek_tur3_yedek
                where ad = 'w7:public.delete_my_account()') then
    raise exception 'w7: göç zaten uygulanmış görünüyor (yeni nesne ya da yedek satırı var); elle incele';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) or has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w7: olcek_tur3_yedek istemci rollerine açık; yedek güvenilmez';
  end if;
end;
$w7_onkosul$;

create temp table w7_durum (
  sahip oid not null, acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w7_durum$
declare
  v_def text := pg_get_functiondef(to_regprocedure('public.delete_my_account()'));
begin
  if md5(v_def) <> '109b68e209e89f73d6cc3e5cdf5d6ba0' then
    raise exception 'w7: delete_my_account gövdesi bilinen canlı taban değil (md5 %); canlı gövde değişmiş olabilir, elle incele', md5(v_def);
  end if;
  insert into w7_durum
  select p.proowner, p.proacl::text, p.proconfig, p.prosecdef
  from pg_proc p where p.oid = to_regprocedure('public.delete_my_account()');
end;
$w7_durum$;

insert into public.olcek_tur3_yedek (ad, tanim, alindi)
select 'w7:public.delete_my_account()',
       pg_get_functiondef(to_regprocedure('public.delete_my_account()'))
         || E'\n-- md5:' || md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))),
       now();

-- ---------------------------------------------------------------------------
-- Yardımcı: silinen kullanıcıyı yönetim kayıtlarında anonimleştir (istemciye kapalı)
-- ---------------------------------------------------------------------------
create function public.anonymize_deleted_user_in_admin_records(p_user_id uuid)
 returns integer
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare
  c_anon_id constant uuid := '00000000-0000-0000-0000-000000000000';
  c_anon_name constant text := 'Hesabê jêbirî';
  v_uid text := p_user_id::text;
  v_adet integer := 0;
  v_n integer;
begin
  if p_user_id is null then
    return 0;
  end if;

  -- Günlük: hedef bu kullanıcı ya da detail içinde kimliği geçen satırlar.
  update public.admin_audit_log a
  set target_id = case when a.target_id = v_uid then c_anon_id::text else a.target_id end,
      admin_id = case when a.admin_id = p_user_id then c_anon_id else a.admin_id end,
      detail = case
        when a.target_id = v_uid then
          replace(((a.detail - 'note') || case when a.detail ? 'label'
                    then jsonb_build_object('label', c_anon_name) else '{}'::jsonb end)::text,
                  v_uid, c_anon_id::text)::jsonb
        when position(v_uid in a.detail::text) > 0 then
          replace(a.detail::text, v_uid, c_anon_id::text)::jsonb
        else a.detail end
  where a.target_id = v_uid
     or a.admin_id = p_user_id
     or position(v_uid in a.detail::text) > 0;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;

  update public.admin_reward_grants
  set user_id = gen_random_uuid()
  where user_id = p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;
  update public.admin_reward_grants
  set granted_by = c_anon_id
  where granted_by = p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;

  update public.admin_contributor_rewards
  set user_id = gen_random_uuid()
  where user_id = p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;
  update public.admin_contributor_rewards
  set granted_by = c_anon_id
  where granted_by = p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;

  -- Bu kullanıcının kendi moderasyon satırı auth.users CASCADE ile gider; başkasına
  -- yazılan satırlardaki yazan-kimlik burada silinir.
  update public.user_moderation
  set updated_by = c_anon_id
  where updated_by = p_user_id and user_id <> p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;
  delete from public.user_moderation where user_id = p_user_id;

  update public.admin_settings
  set updated_by = null
  where updated_by = p_user_id;
  get diagnostics v_n = row_count;
  v_adet := v_adet + v_n;

  return v_adet;
end;
$function$;

revoke all on function public.anonymize_deleted_user_in_admin_records(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- delete_my_account yaması: yardımcı, auth.users silinmeden önce çağrılır
-- ---------------------------------------------------------------------------
do $w7_yama$
declare
  v_oid regprocedure := to_regprocedure('public.delete_my_account()');
  v_def text := pg_get_functiondef(v_oid);
  v_eski constant text :=
$e$  perform public.anonymize_deleted_user_in_snapshots(v_user_id);
$e$;
  v_yeni constant text :=
$y$  perform public.anonymize_deleted_user_in_snapshots(v_user_id);

  -- (2026-11-18) Yönetim kayıtlarında (günlük, ödül, moderasyon) kimlik / ad / not
  -- anonimleştirilir; auth.users silinmeden ÖNCE (hedef kimliği hâlâ bilinir).
  perform public.anonymize_deleted_user_in_admin_records(v_user_id);
$y$;
  v_adet integer;
begin
  v_adet := (length(v_def) - length(replace(v_def, v_eski, ''))) / length(v_eski);
  if v_adet <> 1 then
    raise exception 'w7: delete_my_account için bağlayıcı metin % kez bulundu (1 beklenir); canlı gövde değişmiş, yeniden incele', v_adet;
  end if;
  execute replace(v_def, v_eski, v_yeni);
  update public.olcek_tur3_yedek
  set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w7:public.delete_my_account()';
end;
$w7_yama$;

-- ---------------------------------------------------------------------------
-- Son kontroller
-- ---------------------------------------------------------------------------
do $w7_son$
declare
  d record;
begin
  select * into d from w7_durum;
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.delete_my_account()')
      and p.proowner = d.sahip and p.prosecdef = d.secdef
      and p.proconfig is not distinct from d.ayar
      and p.proacl::text is not distinct from d.acl
  ) then
    raise exception 'w7: delete_my_account sahip / search_path / ACL doğrulanamadı';
  end if;
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute')
     or has_function_privilege('public', 'public.delete_my_account()', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then
    raise exception 'w7: delete_my_account EXECUTE yetkisi bozuldu';
  end if;
  if has_function_privilege('anon', 'public.anonymize_deleted_user_in_admin_records(uuid)', 'execute')
     or has_function_privilege('public', 'public.anonymize_deleted_user_in_admin_records(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.anonymize_deleted_user_in_admin_records(uuid)', 'execute') then
    raise exception 'w7: anonimleştirme yardımcısı istemciye açık';
  end if;
  if not exists (select 1 from pg_proc p
                 where p.oid = to_regprocedure('public.anonymize_deleted_user_in_admin_records(uuid)')
                   and p.prosecdef and p.proconfig is not null) then
    raise exception 'w7: yardımcı SECURITY DEFINER + sabit search_path değil';
  end if;
  if pg_get_functiondef(to_regprocedure('public.delete_my_account()'))
       not like '%anonymize_deleted_user_in_admin_records%' then
    raise exception 'w7: delete_my_account yardımcıyı çağırmıyor';
  end if;
end;
$w7_son$;

do $w7_md5$
begin
  -- Nihai md5 elle sabitlenir (PGlite zinciri aynı değeri üretir; test doğrular).
  if md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))) <> '640c65f6fbcb60aa6ac3fea77cabec90' then
    raise exception 'w7: delete_my_account yama sonrası beklenen nihai md5 değil';
  end if;
end;
$w7_md5$;

commit;
