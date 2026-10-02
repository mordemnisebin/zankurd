-- 2026-10-02: davet kodu ödülü ikinci kez alınamasın (güvenlik denetimi H1).
--
-- KUSUR: `redeem_referral_code` çifte ödülü yalnız `profiles.referred_by IS
-- NULL` ile kapatıyordu. Oysa `referred_by` ne `profiles_client_write_guard`
-- tetikleyicisinde korunuyordu ne de ekleme tetikleyicisinde; `authenticated`
-- kendi satırında tablo düzeyinde UPDATE hakkına sahip. Yani doğrulanmış bir
-- hesap REST'ten `PATCH /profiles?id=eq.<ben>` ile `referred_by = null`
-- yazıp RPC'yi yeniden çağırarak her seferinde iki tarafa 100 coin
-- (`referral_welcome` + `referral_invite`) bastırabiliyordu. Sessizdi: RPC
-- hep `success: true` dönüyor, defterde de her şey "meşru" görünüyordu.
--
-- DÜZELTME (üç katman, biri düşse öbürü tutar):
--   1. `profiles_client_write_guard`: istemci (authenticated/anon) UPDATE'inde
--      `referred_by` eski değerinde kalır. Yalnız security definer RPC yazar.
--   2. `profiles_client_insert_authority`: istemci INSERT'inde `referred_by`
--      NULL'a zorlanır (profil silinip yeniden eklenerek de sıfırlanamaz).
--   3. `referral_redemptions(user_id PK, ...)`: kullanım kaydı AYRI, istemci
--      erişimi olmayan bir tabloda tutulur; ödül, bu tabloya satır
--      eklenebilmesi şartına bağlıdır (PK çakışması = ikinci ödül yok).
--      `referred_by` bir şekilde (ör. referans veren hesabını silince FK
--      `on delete set null` ile) NULL olsa bile kayıt durur.
--
-- ESKİ İSTEMCİ UYUMU: RPC imzası (`redeem_referral_code(text) returns jsonb`)
-- ve dönüş anahtarları (`success`, `error`, `message`, `coins_awarded`,
-- `referrer_name`) AYNI; yeni ret yolu mevcut `already_redeemed` kodunu
-- kullanır. İstemci hiçbir yerde `referred_by` yazmıyor (lib/ ve mağaza
-- sürümü 468ea4a4 tarandı).
--
-- ARTA KALAN RİSK: hesap silinip başka bir Apple/Google kimliğiyle yeniden
-- kayıt (yeni uuid) yeni bir davet hakkı doğurur; bunu ancak kimlik (e-posta)
-- bazlı bir kayıt ya da daha sıkı kayıt hız sınırı kapatır (Dashboard).
--
-- GERİ ALMA: tetikleyici işlevlerinden `referred_by` satırını çıkarıp
-- `create or replace` ile eski gövdeleri (`2026-08-06_profile_insert_and_
-- league_authority` ve baseline) yeniden yazın; `redeem_referral_code` için
-- `2026-09-06_referral_verified_only.sql` yeniden çalıştırılır;
-- `drop table public.referral_redemptions` (kayıt kaybı = güvenlik kaybı,
-- yalnız acil durumda).

begin;

-- 1) Kullanım kaydı: istemci hiçbir yoldan okuyamaz/yazamaz.
create table if not exists public.referral_redemptions (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  -- FK YOK: referans veren hesabını silse bile kayıt (ve ödülün alındığı
  -- bilgisi) kalmalı.
  referrer_id uuid,
  redeemed_at timestamptz not null default now()
);

alter table public.referral_redemptions enable row level security;
revoke all on table public.referral_redemptions from public, anon, authenticated;

-- 2) Geriye dönük kayıt: bugüne dek ödül almış herkes "kullandı" sayılır.
insert into public.referral_redemptions (user_id, referrer_id, redeemed_at)
select p.id, p.referred_by, coalesce(p.updated_at, now())
from public.profiles p
where p.referred_by is not null
on conflict (user_id) do nothing;

-- `referred_by` sıfırlanmış olsa bile defterdeki karşılama ödülü iz bırakır.
insert into public.referral_redemptions (user_id, referrer_id, redeemed_at)
select ct.player_id, null, min(ct.created_at)
from public.coin_transactions ct
join public.profiles p on p.id = ct.player_id
where ct.reason = 'referral_welcome'
group by ct.player_id
on conflict (user_id) do nothing;

-- 3) Tetikleyici işlevleri: `referred_by` istemciden yazılamaz.
create or replace function public.profiles_client_write_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci guncellemeleri kisitlanir.
  if current_user in ('authenticated', 'anon') then
    -- XP yalnizca award_xp_delta() RPC'si uzerinden yazilir.
    new.xp := old.xp;
    new.xp_daily_total := old.xp_daily_total;
    new.xp_daily_date := old.xp_daily_date;
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := old.coins;
    new.rating := old.rating;
    -- Davet kaydi yalnizca redeem_referral_code() ile yazilir; istemci
    -- NULL'layip odulu yeniden alamaz (2026-10-02 guvenlik denetimi H1).
    new.referred_by := old.referred_by;
  end if;
  return new;
end;
$$;

create or replace function public.profiles_client_insert_authority()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- security definer fonksiyonlar (postgres olarak calisir) serbesttir;
  -- yalnizca dogrudan REST/istemci eklemeleri kisitlanir. Mevcut UPDATE
  -- guard'iyla ayni kosul, ayni gerekce.
  if current_user in ('authenticated', 'anon') then
    -- Coin bakiyesi ve rating hicbir zaman istemciden yazilmaz.
    new.coins := 0;
    new.rating := 1000;
    -- XP yalnizca award_xp_delta() RPC'si uzerinden yazilir.
    new.xp := 0;
    new.xp_daily_total := 0;
    new.xp_daily_date := null;
    -- Davet bilgisi istemciden eklenemez (H1).
    new.referred_by := null;
  end if;
  return new;
end;
$$;

-- 4) RPC: kayıt tablosuna satır girebilmek ödülün ön koşulu.
create or replace function public.redeem_referral_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_clean_code text;
  v_referrer record;
  v_caller record;
  v_rows integer;
  v_reward_amount constant integer := 100;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'unauthenticated';
  end if;

  -- Misafir (anonymous identity) veya kimliği olmayan oturum ödül alamaz.
  -- `auth.users.is_anonymous` sürümden sürüme yok; identities yeter.
  if not exists (
       select 1
       from auth.identities i
       where i.user_id = v_user_id
         and i.provider is distinct from 'anonymous'
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'not_verified',
      'message', 'Referral requires a verified account'
    );
  end if;

  v_clean_code := upper(trim(p_code));
  if v_clean_code = '' then
    raise exception 'invalid_code';
  end if;

  -- Satır kilidi: aynı kullanıcının eşzamanlı iki çağrısını sıraya koyar.
  select id, referred_by, player_tag
  into v_caller
  from public.profiles
  where id = v_user_id
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;

  if v_caller.referred_by is not null
     or exists (
       select 1 from public.referral_redemptions rr
       where rr.user_id = v_user_id
     )
  then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  select id, display_name, player_tag
  into v_referrer
  from public.profiles
  where player_tag = v_clean_code
     or player_tag = 'ZK-' || v_clean_code
     or replace(player_tag, 'ZK-', '') = v_clean_code
  limit 1
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'code_not_found',
      'message', 'Invalid referral code'
    );
  end if;

  if v_referrer.id = v_user_id then
    return jsonb_build_object(
      'success', false,
      'error', 'own_code',
      'message', 'Cannot use own code'
    );
  end if;

  -- Ödülün gerçek kapısı: PK çakışırsa ikinci ödül verilmez.
  insert into public.referral_redemptions (user_id, referrer_id)
  values (v_user_id, v_referrer.id)
  on conflict (user_id) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    return jsonb_build_object(
      'success', false,
      'error', 'already_redeemed',
      'message', 'Referral code already used'
    );
  end if;

  update public.profiles
  set referred_by = v_referrer.id,
      updated_at = now()
  where id = v_user_id;

  insert into public.coin_transactions (player_id, amount, reason)
  values
    (v_user_id, v_reward_amount, 'referral_welcome'),
    (v_referrer.id, v_reward_amount, 'referral_invite');

  return jsonb_build_object(
    'success', true,
    'coins_awarded', v_reward_amount,
    'referrer_name', coalesce(v_referrer.display_name, 'Heval')
  );
end;
$$;

revoke all on function public.redeem_referral_code(text) from public, anon;
grant execute on function public.redeem_referral_code(text) to authenticated;

-- 5) Doğrulama: biri tutmazsa tüm işlem geri alınır.
do $$
begin
  if to_regclass('public.referral_redemptions') is null then
    raise exception 'referral_redemptions yok';
  end if;
  if not (select c.relrowsecurity from pg_class c
          where c.oid = 'public.referral_redemptions'::regclass) then
    raise exception 'referral_redemptions: RLS kapalı';
  end if;
  if has_table_privilege('authenticated', 'public.referral_redemptions', 'select')
     or has_table_privilege('authenticated', 'public.referral_redemptions', 'insert')
     or has_table_privilege('anon', 'public.referral_redemptions', 'select') then
    raise exception 'referral_redemptions istemciye açık';
  end if;
  if pg_get_functiondef('public.profiles_client_write_guard()'::regprocedure)
       not like '%new.referred_by := old.referred_by%' then
    raise exception 'update guard referred_by korumuyor';
  end if;
  if pg_get_functiondef('public.profiles_client_insert_authority()'::regprocedure)
       not like '%new.referred_by := null%' then
    raise exception 'insert authority referred_by sıfırlamıyor';
  end if;
  if pg_get_functiondef('public.redeem_referral_code(text)'::regprocedure)
       not like '%referral_redemptions%' then
    raise exception 'redeem_referral_code kayıt tablosunu kullanmıyor';
  end if;
  if has_function_privilege('anon', 'public.redeem_referral_code(text)', 'execute') then
    raise exception 'redeem_referral_code anon''a açık';
  end if;
  if not has_function_privilege('authenticated', 'public.redeem_referral_code(text)', 'execute') then
    raise exception 'redeem_referral_code authenticated''a kapalı';
  end if;
  if (select count(*) from pg_trigger
      where tgrelid = 'public.profiles'::regclass
        and tgname in ('profiles_client_write_guard_trg',
                       'profiles_client_insert_authority_trg')) <> 2 then
    raise exception 'profiles koruma tetikleyicileri eksik';
  end if;
  -- Geriye dönük kayıt: referred_by dolu herkes kayıtlı olmalı.
  if exists (
    select 1 from public.profiles p
    where p.referred_by is not null
      and not exists (select 1 from public.referral_redemptions rr
                      where rr.user_id = p.id)
  ) then
    raise exception 'referred_by dolu ama kayıtsız profil var';
  end if;
end $$;

commit;
