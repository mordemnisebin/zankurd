-- W4 / 2.1.2 (GPT-6 Pro ALAN 4 #3 #7 #9): Apple iptal kuyruğu + avatar süpürme imleci +
-- hesap silmede depolama nesnelerinin süpürücüye görünür kalması.
-- Geri alma: geri_al/2026-11-16_w4_apple_hesap_silme_geri.sql
--
-- NİÇİN (her madde kodda doğrulandı)
--  #3 apple_auth_tokens.user_id, auth.users'a ON DELETE CASCADE bağlıydı: Apple iptali
--     başarısız olduysa (ağ, Apple 5xx, anahtar eksik) kullanıcı hesabını silince iptal için
--     gereken refresh token da KALICI yok oluyor, Apple'daki bağlantı sonsuza dek açık
--     kalıyordu (Kılavuz 5.1.1(v)). Çözüm: FK kalkar. Hesap silinse de başarısız iptalin
--     jetonu satırda kalır ("yetim": user_id artık auth.users'ta yok); apple-revoke Edge
--     işlevinin `sweep` eylemi (pg_cron, ayrı göç 2026-11-16_w4_apple_cron.sql) yetimleri
--     yeniden dener, Apple başarıyı bildirince satır silinir. Yetim listesi YALNIZ
--     auth.users'ta karşılığı olmayan satırları verir: yaşayan bir kullanıcının jetonu
--     süpürmeyle ASLA iptal edilmez. Gizlilik: jeton yalnız iptal edilene dek tutulur
--     (20 denemeden sonra vazgeçilir; elle incelenir).
--  #7 avatar-sweep imleç saklamıyordu: her saat aynı ilk 20.000 kök girdi taranıyor, sonrası
--     hiç görülmüyordu. `avatar_sweep_state` tek satırlı imleç tablosudur (istemciye kapalı).
--  #9 delete_my_account içindeki doğrudan `DELETE FROM storage.objects` yalnız meta satırı
--     siler; fiziksel dosya kalır ve avatar-sweep yalnız Storage list() ile (= storage.objects
--     satırlarıyla) gördüğünden o dosyayı bir daha ASLA bulamaz. Bu göç doğrudan silmeyi
--     gövdeden çıkarır: nesne satırları hesap silindikten sonra da kalır, süpürücü bulur ve
--     Storage API'siyle gerçekten siler. (Yeni istemci kendi klasörünü zaten Storage API'siyle
--     siler; build 43 ve öncesi silmez: onlarınki süpürücüye kalır.)
--
-- Taban (canlı ✅, applied.md): delete_my_account = kalabalık_oda gövdesi + ölçek kilit yaması
-- + 2026-11-08_hesap_silme_yasal yaması; nihai md5 2e5e96d2061716e7a0f876ee03b2d7be (canlıda
-- ölçüldü, applied.md). Tam gövde md5'i bu tabana eşitse yamalanır; başka her durumda göç
-- durur. Eski gövde ve md5'i olcek_tur3_yedek'e ('w4:public.delete_my_account()') alınır.
-- Taban md5'i yerelde PGlite'ta zincirden kurularak yeniden doğrulanır
-- (tool/test_w4_apple_hesap_silme_local.mjs). Önce canlıda kuru çalıştırma:
--   select md5(pg_get_functiondef('public.delete_my_account()'::regprocedure));
-- = 2e5e96d2061716e7a0f876ee03b2d7be olmalı.
--
-- Eski istemci (build 43) sözleşmesi: delete_my_account imzası/dönüşü aynı; apple-revoke'un
-- eski istemci çağrıları (register/revoke) aynen çalışır.
begin;

set local lock_timeout = '10s';

do $w4a_onkosul$
begin
  if to_regprocedure('public.delete_my_account()') is null
     or to_regclass('public.apple_auth_tokens') is null
     or to_regclass('public.olcek_tur3_yedek') is null then
    raise exception 'w4a: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  if to_regprocedure('public.apple_orphan_tokens(integer)') is not null
     or to_regclass('public.avatar_sweep_state') is not null
     or exists (select 1 from public.olcek_tur3_yedek
                where ad = 'w4:public.delete_my_account()') then
    raise exception 'w4a: göç zaten uygulanmış görünüyor (yeni nesne ya da yedek satırı var); elle incele';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) or has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w4a: olcek_tur3_yedek istemci rollerine açık; yedek güvenilmez';
  end if;
end;
$w4a_onkosul$;

create temp table w4a_durum (
  sahip oid not null, acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w4a_durum$
declare
  v_def text := pg_get_functiondef(to_regprocedure('public.delete_my_account()'));
begin
  if md5(v_def) <> '2e5e96d2061716e7a0f876ee03b2d7be' then
    raise exception 'w4a: delete_my_account gövdesi bilinen canlı taban değil (md5 %); canlı gövde değişmiş olabilir, elle incele', md5(v_def);
  end if;
  insert into w4a_durum
  select p.proowner, p.proacl::text, p.proconfig, p.prosecdef
  from pg_proc p where p.oid = to_regprocedure('public.delete_my_account()');
end;
$w4a_durum$;

insert into public.olcek_tur3_yedek (ad, tanim, alindi)
select 'w4:public.delete_my_account()',
       pg_get_functiondef(to_regprocedure('public.delete_my_account()'))
         || E'\n-- md5:' || md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))),
       now();

-- ---------------------------------------------------------------------------
-- #3 apple_auth_tokens: FK kalkar, yeniden deneme sayaçları
-- ---------------------------------------------------------------------------
do $w4a_fk$
declare
  r record;
begin
  for r in
    select c.conname from pg_constraint c
    where c.conrelid = 'public.apple_auth_tokens'::regclass and c.contype = 'f'
  loop
    execute format('alter table public.apple_auth_tokens drop constraint %I', r.conname);
  end loop;
end;
$w4a_fk$;

alter table public.apple_auth_tokens
  add column if not exists attempts integer not null default 0,
  add column if not exists last_attempt_at timestamptz;

-- Yetim = sahibi artık auth.users'ta olmayan satır. Yaşayan kullanıcının jetonu ASLA
-- dönmez (süpürme canlı bir kullanıcının Apple bağlantısını koparmasın).
create function public.apple_orphan_tokens(p_limit integer default 20)
 returns table (user_id uuid, refresh_token text)
 language sql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  select t.user_id, t.refresh_token
  from public.apple_auth_tokens t
  where not exists (select 1 from auth.users u where u.id = t.user_id)
    and t.attempts < 20
    and (t.last_attempt_at is null or t.last_attempt_at < now() - interval '10 minutes')
  order by t.created_at
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$function$;

create function public.apple_orphan_failed(p_user_id uuid)
 returns void
 language sql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
  update public.apple_auth_tokens
  set attempts = attempts + 1, last_attempt_at = now()
  where user_id = p_user_id
    and not exists (select 1 from auth.users u where u.id = p_user_id);
$function$;

revoke all on function public.apple_orphan_tokens(integer) from public, anon, authenticated;
revoke all on function public.apple_orphan_failed(uuid) from public, anon, authenticated;
grant execute on function public.apple_orphan_tokens(integer) to service_role;
grant execute on function public.apple_orphan_failed(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- #7 avatar süpürme imleci
-- ---------------------------------------------------------------------------
create table public.avatar_sweep_state (
  id smallint primary key check (id = 1),
  next_offset integer not null default 0 check (next_offset >= 0),
  updated_at timestamptz not null default now()
);
alter table public.avatar_sweep_state enable row level security;
revoke all on table public.avatar_sweep_state from public, anon, authenticated;
grant select, insert, update on table public.avatar_sweep_state to service_role;
insert into public.avatar_sweep_state (id, next_offset) values (1, 0);

-- ---------------------------------------------------------------------------
-- #9 delete_my_account yaması: doğrudan storage.objects silmesi gövdeden çıkar
-- ---------------------------------------------------------------------------
do $w4a_yama$
declare
  v_oid regprocedure := to_regprocedure('public.delete_my_account()');
  v_def text := pg_get_functiondef(v_oid);
  v_eski constant text :=
$e$  begin
    delete from storage.objects
    where bucket_id = 'avatars'
      and (storage.foldername(name))[1] = v_user_id::text;
  exception when others then
    null;
  end;
$e$;
  v_yeni constant text :=
$y$  -- (2026-11-16) Doğrudan SQL ile depolama nesne satırı silme KALDIRILDI: yalnız meta satırı
  -- siler, fiziksel dosya kalır ve satır gidince avatar-sweep (Storage list) dosyayı bir daha
  -- göremez. Nesne satırları kalır; yeni istemci Storage API'siyle önce siler, kalanı
  -- süpürücü siler.
$y$;
  v_adet integer;
begin
  v_adet := (length(v_def) - length(replace(v_def, v_eski, ''))) / length(v_eski);
  if v_adet <> 1 then
    raise exception 'w4a: delete_my_account için bağlayıcı metin % kez bulundu (1 beklenir); canlı gövde değişmiş, yeniden incele', v_adet;
  end if;
  execute replace(v_def, v_eski, v_yeni);
  update public.olcek_tur3_yedek
  set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(v_oid))
  where ad = 'w4:public.delete_my_account()';
end;
$w4a_yama$;

-- ---------------------------------------------------------------------------
-- Son kontroller
-- ---------------------------------------------------------------------------
do $w4a_son$
declare
  d record;
begin
  select * into d from w4a_durum;
  if not exists (
    select 1 from pg_proc p
    where p.oid = to_regprocedure('public.delete_my_account()')
      and p.proowner = d.sahip and p.prosecdef = d.secdef
      and p.proconfig is not distinct from d.ayar
      and p.proacl::text is not distinct from d.acl
  ) then
    raise exception 'w4a: delete_my_account sahip / search_path / ACL doğrulanamadı';
  end if;
  if pg_get_functiondef(to_regprocedure('public.delete_my_account()')) like '%storage.objects%' then
    raise exception 'w4a: delete_my_account hâlâ storage.objects siliyor';
  end if;
  if has_function_privilege('anon', 'public.delete_my_account()', 'execute')
     or has_function_privilege('public', 'public.delete_my_account()', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_my_account()', 'execute') then
    raise exception 'w4a: delete_my_account EXECUTE yetkisi bozuldu';
  end if;
  if exists (select 1 from pg_constraint c
             where c.conrelid = 'public.apple_auth_tokens'::regclass and c.contype = 'f') then
    raise exception 'w4a: apple_auth_tokens hâlâ yabancı anahtar taşıyor';
  end if;
  if has_function_privilege('anon', 'public.apple_orphan_tokens(integer)', 'execute')
     or has_function_privilege('authenticated', 'public.apple_orphan_tokens(integer)', 'execute')
     or has_function_privilege('anon', 'public.apple_orphan_failed(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.apple_orphan_failed(uuid)', 'execute')
     or not has_function_privilege('service_role', 'public.apple_orphan_tokens(integer)', 'execute')
     or not has_function_privilege('service_role', 'public.apple_orphan_failed(uuid)', 'execute') then
    raise exception 'w4a: yetim jeton işlevleri yalnız service_role çalıştırabilmeli';
  end if;
  if has_table_privilege('anon', 'public.avatar_sweep_state', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.avatar_sweep_state', 'select,insert,update,delete')
     or not (select c.relrowsecurity from pg_class c where c.oid = 'public.avatar_sweep_state'::regclass) then
    raise exception 'w4a: avatar_sweep_state istemciye açık ya da RLS kapalı';
  end if;
  if has_table_privilege('anon', 'public.apple_auth_tokens', 'select')
     or has_table_privilege('authenticated', 'public.apple_auth_tokens', 'select') then
    raise exception 'w4a: apple_auth_tokens istemciye açık';
  end if;
end;
$w4a_son$;

do $w4a_md5$
begin
  -- Nihai md5 elle sabitlenir (PGlite zinciri aynı değeri üretir; test doğrular).
  if md5(pg_get_functiondef(to_regprocedure('public.delete_my_account()'))) <> '109b68e209e89f73d6cc3e5cdf5d6ba0' then
    raise exception 'w4a: delete_my_account yama sonrası beklenen nihai md5 değil';
  end if;
end;
$w4a_md5$;

commit;
