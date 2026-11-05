-- W4 / 2.1.2 (GPT-6 Pro ALAN 4 #23 #13 #21): çok cihazlı push (cihaz başına jeton tablosu) +
-- uyandırma kilidi/gereksiz uyandırma.
-- Geri alma: geri_al/2026-11-16_w4_push_cihazlar_geri.sql
--
-- NİÇİN (kodda doğrulandı)
--  #23 `profiles.fcm_token` TEK sütun: aynı hesaba bağlı iki cihazdan yalnız en son kaydolan
--     push alıyordu (set_fcm_token öncekini eziyor). Çözüm: `push_devices` (jeton başına bir
--     satır, kullanıcı başına en çok 10).
--     GERİYE UYUM (eski istemci build 43 değişmeden çalışır, istemci değişikliği ZORUNLU DEĞİL):
--       - istemciler `set_fcm_token(text)` çağırmaya DEVAM eder; `profiles.fcm_token` hâlâ
--         "son kaydolan cihaz"dır (claim_push_outbox_v2 ve token-hazır tetikleyicisi buna
--         bakar). Yeni AFTER UPDATE tetikleyicisi (`trg_profiles_fcm_devices_sync`) bu değişimi
--         push_devices'a yansıtır; yani eski istemci de çok cihazlı tabloyu BESLER.
--       - send-push (Edge) `get_push_device_tokens(uid)` ile kullanıcının BÜTÜN cihaz
--         jetonlarına gönderir (RPC yoksa PGRST202 → yalnız claim'in verdiği tek jeton).
--     Jeton sahipliği: aynı jeton başka kullanıcıya geçerse satır yeni sahibe taşınır
--     (PRIMARY KEY token); set_fcm_token zaten eski profilden siler (tetikleyici o satırı
--     siler, sonra yeni sahip yazılır).
--     Çıkış güvenliği: `clear_my_fcm_token(text)` (yeni istemci) yalnız O cihazın satırını
--     siler ve profil jetonu o cihazınsa profili başka bir cihaza yönlendirir (çıkış başka
--     cihazı susturmaz, #4'ün sunucu yarısı); `clear_my_fcm_token()` (eski istemci, hangi
--     cihaz olduğunu bilmez) güvenli tarafta kalır: kullanıcının TÜM cihaz satırlarını ve
--     profil jetonunu siler (eski davranış: oturumu kapatılan cihazın jetonu bir daha
--     bildirim almamalı).
--  #13 wake_push_delivery_v2 jetonu olmayan kullanıcıların işleri için de Edge'i uyandırıyordu
--     (her biri `no_token` ile hemen "skipped"). Artık yalnız jetonlu (profil jetonu ya da
--     cihaz satırı) bir iş varsa uyandırır.
--  #21 wake_push_delivery_v2 tek `push_delivery_v2_config` satırını üreticinin işleminde
--     UPDATE ediyordu: eşzamanlı üreticiler satır kilidinde BEKLİYORDU (her bildirim üreten
--     işlem birbirini). Artık `FOR UPDATE SKIP LOCKED`: kilit başkasındaysa beklemeden
--     `false` döner (o üretici zaten uyandırıyor; kaçan iş dakikalık kurtarma cron'unda).
--
-- Taban (canlı ✅, applied.md): üç işlevin canlı gövdesi, göç zincirinin SON tanımıdır
-- (clear_my_fcm_token(): 2026-10-15_sosyal_ve_sertlestirme.sql; clear_my_fcm_token(text):
-- 2026-11-06_push_tur8.sql; wake_push_delivery_v2(): 2026-10-31_push_delivery_v2.sql +
-- 2026-11-04_olcek_sertlestirme.sql yaması). TAM gövde md5'i bilinen tabana eşitse
-- yamalanır; başka her durumda göç durur. Eski gövde ve md5'i olcek_tur3_yedek'e
-- ('w4:<imza>') alınır. Taban md5'leri yerelde PGlite'ta zincirden kurularak bulundu
-- (tool/test_w4_push_cihazlar_local.mjs aynı değerleri doğrular). Önce canlıda kuru
-- çalıştırma; her biri aşağıdaki sabitlere eşit olmalı:
--   select md5(pg_get_functiondef('public.clear_my_fcm_token()'::regprocedure));
--   select md5(pg_get_functiondef('public.clear_my_fcm_token(text)'::regprocedure));
--   select md5(pg_get_functiondef('public.wake_push_delivery_v2()'::regprocedure));
begin;

set local lock_timeout = '10s';

do $w4p_onkosul$
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.push_outbox') is null
     or to_regclass('public.push_delivery_v2_config') is null
     or to_regclass('public.olcek_tur3_yedek') is null
     or to_regprocedure('public.set_fcm_token(text)') is null
     or to_regprocedure('public.clear_my_fcm_token()') is null
     or to_regprocedure('public.clear_my_fcm_token(text)') is null
     or to_regprocedure('public.clear_fcm_token(uuid,text)') is null
     or to_regprocedure('public.wake_push_delivery_v2()') is null then
    raise exception 'w4p: beklenen canlı nesneler eksik; göçü uygulamadan önce incele';
  end if;
  if to_regclass('public.push_devices') is not null
     or to_regprocedure('public.get_push_device_tokens(uuid)') is not null
     or to_regprocedure('public.clear_push_device(uuid,text)') is not null
     or exists (select 1 from public.olcek_tur3_yedek where ad like 'w4:public.%fcm%'
                or ad = 'w4:public.wake_push_delivery_v2()') then
    raise exception 'w4p: göç zaten uygulanmış görünüyor (yeni nesne ya da yedek satırı var); elle incele';
  end if;
  if exists (
    select 1 from pg_class c, aclexplode(coalesce(c.relacl, '{}')) a
    where c.oid = 'public.olcek_tur3_yedek'::regclass and a.grantee <> c.relowner
      and a.grantee not in (select oid from pg_roles where rolname = 'service_role')
  ) or has_table_privilege('anon', 'public.olcek_tur3_yedek', 'insert,update,delete,select')
     or has_table_privilege('authenticated', 'public.olcek_tur3_yedek', 'insert,update,delete,select') then
    raise exception 'w4p: olcek_tur3_yedek istemci rollerine açık; yedek güvenilmez';
  end if;
end;
$w4p_onkosul$;

-- İmza, taban md5, nihai md5 (yama sonrası beklenen); sahip/ACL/ayar/secdef yamadan önce.
create temp table w4p_durum (
  imza text primary key, nihai text not null,
  sahip oid not null, acl text, ayar text[], secdef boolean not null
) on commit drop;
do $w4p_durum$
declare
  r record;
  v_def text;
begin
  for r in select * from (values
    ('public.clear_my_fcm_token()', '895b0ba521e856e09df809ebdf701aae', 'ea075ffe74c040ea22416803e3be33f2'),
    ('public.clear_my_fcm_token(text)', 'edca67b743a427d6704fad815eacf895', 'f04b886534d4bd727ef5b0e856f29a35'),
    ('public.wake_push_delivery_v2()', '76022d286066c2257d8f6ad72a4b4748', 'c3a2d5330fdc06be5ba23a038ff57c52')
  ) as t(imza, taban, nihai)
  loop
    v_def := pg_get_functiondef(to_regprocedure(r.imza));
    if md5(v_def) <> r.taban then
      raise exception 'w4p: % gövdesi bilinen canlı taban değil (md5 %); canlı gövde değişmiş olabilir, elle incele', r.imza, md5(v_def);
    end if;
    insert into w4p_durum
    select r.imza, r.nihai, p.proowner, p.proacl::text, p.proconfig, p.prosecdef
    from pg_proc p where p.oid = to_regprocedure(r.imza);
    insert into public.olcek_tur3_yedek (ad, tanim, alindi)
    values ('w4:' || r.imza, v_def || E'\n-- md5:' || md5(v_def), now());
  end loop;
end;
$w4p_durum$;

-- ---------------------------------------------------------------------------
-- Cihaz tablosu
-- ---------------------------------------------------------------------------
create table public.push_devices (
  token text primary key check (char_length(token) between 1 and 4096),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index push_devices_user_idx on public.push_devices (user_id, last_seen_at desc);
alter table public.push_devices enable row level security;
revoke all on table public.push_devices from public, anon, authenticated;
grant select, insert, update, delete on table public.push_devices to service_role;

-- Mevcut tek jetonlar çok cihazlı tabloya taşınır (bir kez).
insert into public.push_devices (token, user_id)
select distinct on (btrim(p.fcm_token)) btrim(p.fcm_token), p.id
from public.profiles p
where nullif(btrim(p.fcm_token), '') is not null
  and char_length(btrim(p.fcm_token)) <= 4096
  and exists (select 1 from auth.users u where u.id = p.id)
order by btrim(p.fcm_token), p.id
on conflict (token) do nothing;

-- profiles.fcm_token değişimini cihaz tablosuna yansıtır (eski istemci dahil).
--  - yeni değer: jeton bu kullanıcının cihazı olur (başka kullanıcıdaysa taşınır);
--    kullanıcı başına en çok 10 cihaz (en eski silinir);
--  - profil jetonu BOŞALDI (çıkış / başka hesaba geçiş): yalnız o ESKİ jetonun satırı
--    (bu kullanıcıdaki) silinir; başka bir değere GEÇTİYSE eski cihaz da yaşar (çok cihaz).
create function public.profiles_fcm_devices_sync()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_new text := nullif(btrim(new.fcm_token), '');
  v_old text := nullif(btrim(old.fcm_token), '');
begin
  if v_new is null then
    if v_old is not null then
      delete from public.push_devices where token = v_old and user_id = new.id;
    end if;
    return null;
  end if;
  if char_length(v_new) > 4096 then
    return null;
  end if;
  insert into public.push_devices as d (token, user_id)
  values (v_new, new.id)
  on conflict (token) do update
    set user_id = excluded.user_id, last_seen_at = now();
  delete from public.push_devices d
  where d.user_id = new.id
    and d.token in (
      select x.token from public.push_devices x
      where x.user_id = new.id
      order by x.last_seen_at desc, x.token
      offset 10
    );
  return null;
exception when others then
  -- Cihaz tablosu hatası jeton kaydını (set_fcm_token) bozamaz; profil jetonu geçerli kalır.
  return null;
end;
$function$;
revoke all on function public.profiles_fcm_devices_sync() from public, anon, authenticated, service_role;

create trigger trg_profiles_fcm_devices_sync
after update of fcm_token on public.profiles
for each row when (old.fcm_token is distinct from new.fcm_token)
execute function public.profiles_fcm_devices_sync();

-- Edge (service_role): kullanıcının gönderilecek jetonları (en yeni önce, en çok 10).
create function public.get_push_device_tokens(p_user_id uuid)
returns table (token text)
language sql
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select d.token from public.push_devices d
  where d.user_id = p_user_id
  order by d.last_seen_at desc, d.token
  limit 10;
$function$;

-- Edge (service_role): FCM "UNREGISTERED" dediği jetonu cihaz tablosundan ve (eşitse) profilden
-- kaldırır; profil jetonu o idiyse başka bir cihaza yönlendirir.
create function public.clear_push_device(p_user_id uuid, p_token text)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
begin
  if p_user_id is null or p_token is null or btrim(p_token) = '' then
    return;
  end if;
  delete from public.push_devices where token = btrim(p_token) and user_id = p_user_id;
  update public.profiles
  set fcm_token = (
    select d.token from public.push_devices d
    where d.user_id = p_user_id
    order by d.last_seen_at desc, d.token limit 1
  )
  where id = p_user_id and fcm_token = btrim(p_token);
end;
$function$;

revoke all on function public.get_push_device_tokens(uuid) from public, anon, authenticated;
revoke all on function public.clear_push_device(uuid, text) from public, anon, authenticated;
grant execute on function public.get_push_device_tokens(uuid) to service_role;
grant execute on function public.clear_push_device(uuid, text) to service_role;

-- ---------------------------------------------------------------------------
-- Yamalar (tam gövde değişimi; imza/SECURITY DEFINER/search_path/ACL aynı)
-- ---------------------------------------------------------------------------
create or replace function public.clear_my_fcm_token()
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then return; end if;
  -- Eski istemci hangi cihazın çıktığını bilmez: güvenli tarafta kal, kullanıcının bütün
  -- cihaz satırlarını sil (çıkış yapılan cihaz bir daha bildirim almasın). Yeni istemci
  -- clear_my_fcm_token(text) çağırır ve yalnız kendi cihazını siler.
  delete from public.push_devices where user_id = auth.uid();
  update public.profiles set fcm_token = null where id = auth.uid();
end;
$function$;

create or replace function public.clear_my_fcm_token(p_token text)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_token text := btrim(p_token);
begin
  if auth.uid() is null or p_token is null or v_token = '' then
    return;
  end if;
  -- Yalnız bu cihazın jetonu: başka cihazın jetonu korunur.
  delete from public.push_devices where token = v_token and user_id = auth.uid();
  -- Profil jetonu bu cihazınsa başka bir cihaza yönlendir (claim profil jetonuna bakar);
  -- başka cihaz yoksa NULL.
  update public.profiles
  set fcm_token = (
    select d.token from public.push_devices d
    where d.user_id = auth.uid()
    order by d.last_seen_at desc, d.token limit 1
  )
  where id = auth.uid() and fcm_token = v_token;
end;
$function$;

create or replace function public.wake_push_delivery_v2()
returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $wake$
declare
  v_url text;
  v_secret text;
  v_now timestamptz := clock_timestamp();
begin
  -- #13: yalnız jetonlu (profil jetonu ya da cihaz satırı) bir iş varsa uyandır; jetonsuz
  -- işler claim'de hemen `no_token` ile skipped olur, Edge'i boşuna kaldırırdı.
  if not exists (select 1 from public.push_delivery_v2_config c where c.singleton and c.enabled)
     or not exists (select 1 from public.push_outbox o
       where o.delivery_status in ('pending', 'retry', 'leased')
         and (o.claimed_at is null or o.claim_token is not null)
         and o.next_attempt_at <= v_now
         and (o.lease_until is null or o.lease_until <= v_now)
         and (exists (select 1 from public.profiles pr
                      where pr.id = o.to_user_id and nullif(btrim(pr.fcm_token), '') is not null)
              or exists (select 1 from public.push_devices d where d.user_id = o.to_user_id))) then
    return false;
  end if;
  select s.decrypted_secret into v_url from vault.decrypted_secrets s
    where s.name = 'send_push_url' limit 1;
  select s.decrypted_secret into v_secret from vault.decrypted_secrets s
    where s.name = 'cron_secret' limit 1;
  if nullif(btrim(v_url), '') is null or nullif(btrim(v_secret), '') is null then return false; end if;
  -- #21: sönümleme satırı BEKLEMEDEN kilitlenir. Satır başka bir üreticinin işleminde
  -- kilitliyse o üretici uyandırmayı zaten yapıyor: bekleme yok, `false`. (Eskiden koşullu
  -- UPDATE satır kilidinde bekliyor, eşzamanlı üreticiler birbirini sıraya diziyordu.)
  perform 1 from public.push_delivery_v2_config c where c.singleton for update skip locked;
  if not found then return false; end if;
  -- Sönümleme: son uyandırmadan bu yana 2 sn geçmediyse HTTP isteği atılmaz; çalışan Edge
  -- işlevi kuyruğu boşalana dek döngüde kalır, kaçan iş en geç dakikalık kurtarma cron'unda
  -- alınır.
  update public.push_delivery_v2_config c
     set last_wake_at = v_now
   where c.singleton
     and (c.last_wake_at is null or c.last_wake_at <= v_now - interval '2 seconds');
  if not found then return false; end if;
  perform net.http_post(url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := '{}'::jsonb, timeout_milliseconds := 20000);
  return true;
exception when others then
  -- Push teslimat altyapısı arkadaşlık/oda işlemini geri alamaz. Cron dener.
  return false;
end;
$wake$;

-- Yama sonrası md5 zinciri
do $w4p_zincir$
declare
  r record;
begin
  for r in select imza from w4p_durum loop
    update public.olcek_tur3_yedek
    set tanim = tanim || E'\n-- yama-md5:' || md5(pg_get_functiondef(to_regprocedure(r.imza)))
    where ad = 'w4:' || r.imza;
  end loop;
end;
$w4p_zincir$;

-- ---------------------------------------------------------------------------
-- Son denetimler
-- ---------------------------------------------------------------------------
do $w4p_son$
declare
  d record;
begin
  for d in select * from w4p_durum loop
    if not exists (
      select 1 from pg_proc p
      where p.oid = to_regprocedure(d.imza)
        and p.proowner = d.sahip and p.prosecdef = d.secdef
        and p.proconfig is not distinct from d.ayar
        and p.proacl::text is not distinct from d.acl
    ) then
      raise exception 'w4p: % sahip / search_path / ACL doğrulanamadı', d.imza;
    end if;
    if md5(pg_get_functiondef(to_regprocedure(d.imza))) <> d.nihai then
      raise exception 'w4p: % yama sonrası beklenen nihai md5 değil', d.imza;
    end if;
  end loop;
  if has_function_privilege('anon', 'public.clear_my_fcm_token()', 'execute')
     or has_function_privilege('public', 'public.clear_my_fcm_token()', 'execute')
     or has_function_privilege('anon', 'public.clear_my_fcm_token(text)', 'execute')
     or has_function_privilege('public', 'public.clear_my_fcm_token(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.clear_my_fcm_token()', 'execute')
     or not has_function_privilege('authenticated', 'public.clear_my_fcm_token(text)', 'execute') then
    raise exception 'w4p: clear_my_fcm_token EXECUTE yetkisi bozuldu (eski istemci kırılırdı)';
  end if;
  if has_function_privilege('anon', 'public.wake_push_delivery_v2()', 'execute')
     or has_function_privilege('authenticated', 'public.wake_push_delivery_v2()', 'execute') then
    raise exception 'w4p: wake_push_delivery_v2 istemciye açık';
  end if;
  if has_function_privilege('anon', 'public.get_push_device_tokens(uuid)', 'execute')
     or has_function_privilege('authenticated', 'public.get_push_device_tokens(uuid)', 'execute')
     or has_function_privilege('anon', 'public.clear_push_device(uuid,text)', 'execute')
     or has_function_privilege('authenticated', 'public.clear_push_device(uuid,text)', 'execute')
     or not has_function_privilege('service_role', 'public.get_push_device_tokens(uuid)', 'execute')
     or not has_function_privilege('service_role', 'public.clear_push_device(uuid,text)', 'execute') then
    raise exception 'w4p: cihaz işlevleri yalnız service_role çalıştırabilmeli';
  end if;
  if has_table_privilege('anon', 'public.push_devices', 'select,insert,update,delete')
     or has_table_privilege('authenticated', 'public.push_devices', 'select,insert,update,delete')
     or not (select c.relrowsecurity from pg_class c where c.oid = 'public.push_devices'::regclass) then
    raise exception 'w4p: push_devices istemciye açık ya da RLS kapalı';
  end if;
  if not exists (select 1 from pg_trigger t where t.tgname = 'trg_profiles_fcm_devices_sync'
                 and t.tgrelid = 'public.profiles'::regclass and not t.tgisinternal) then
    raise exception 'w4p: senkron tetikleyicisi kurulmadı';
  end if;
end;
$w4p_son$;

commit;
