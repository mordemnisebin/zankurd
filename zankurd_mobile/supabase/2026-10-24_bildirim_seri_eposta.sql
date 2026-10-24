-- 2026-10-24 — Bildirim tercihleri, seri onarımı, nazik e-posta doğrulama
--
-- Üç özellik, tek göç (hepsi yalnız EKLEME; 2.1.0 istemcisinin kullandığı
-- imzalara dokunulmaz):
--
-- B1  Bildirim tercihleri (sunucu tarafı)
--     profiles.push_duel / push_social  boolean not null default true.
--     claim_push_outbox türü tercihe göre süzer (kind -> tercih):
--       async_duel_*                              -> push_duel
--       friend_request, friend_accept, room_invite -> push_social
--     Süzgeç SUNUCUDADIR: tercihi bilmeyen 2.1.0 istemcisinin kullanıcısı da
--     varsayılanı (açık) alır, tercihini kapatan 2.1.1 kullanıcısının
--     kapalı türü hiç gönderilmez (satır gönderilmeden kapatılır).
--     Yazma: set_my_push_prefs(p_duel, p_social) (null = değişmez). Okuma:
--     get_my_account_flags(). İkisi de authenticated'a açık.
--
-- B2  Seri onarımı (spend_streak_repair)
--     Seri istemcide yerel tutulur; sunucudaki tek şey JETON harcamasıdır.
--     `spend_coins` idempotent DEĞİL ve gerekçe beyaz listesi var; bu yüzden
--     `spend_streak_freeze` örüntüsüyle ayrı bir RPC: gerekçe
--     'streak_repair:<yyyy-mm>' (kısmi tekil indeks) + streak_repairs tablosu
--     (kullanıcı başına AY başına en çok 1 onarım). Aynı ay + aynı kırılma
--     günüyle ikinci çağrı yeniden ücret KESMEZ, 'already_repaired' döner;
--     aynı ay başka bir kırılma günüyle çağrı 'monthly_limit' ile reddedilir.
--     Premium bayrağı (p_premium) istemcinin beyanıdır: sunucuda abonelik
--     bilgisi yok (RevenueCat istemcide). Kötüye kullanımın azami getirisi
--     ayda bir kez, yerelde tutulan bir seri değerini geri almaktır (jeton
--     ya da sıralama etkisi yok); bu kabul edildi ve belgelendi.
--
-- B3  Nazik e-posta doğrulama
--     profiles.email_verified_at (istemci YAZAMAZ: profiles_client_write_guard
--     canlı gövdesine tek satır eklendi). Tek yazım yolu
--     mark_my_email_verified(): oturum JWT'sinin `amr` talebinde, son 15 dk
--     içinde başlamış bir 'otp' (ya da 'magiclink') yöntemi olmalı — yani
--     kullanıcı e-postasına gelen kodu GERÇEKTEN girmiş. E-posta/parola
--     girişi 'password' amr'si taşır ve REDDEDİLİR. Ek olarak JWT `email`
--     talebi auth.users.email ile eşleşmeli; anonim oturum reddedilir.
--     NOT: e-posta/parola hesapları "Confirm email KAPALI" olduğu için
--     auth.users.email_confirmed_at doğrulama kanıtı DEĞİLDİR (kayıtta
--     otomatik dolar); bu yüzden amr kullanıldı.
--
-- Gövdeler CANLI tanımlardan (pg_get_functiondef, 2026-10-24) kopyalandı:
-- claim_push_outbox ve profiles_client_write_guard; yalnız belirtilen
-- eklemelerle. Kanıt betiği:
-- supabase/kanit/2026-10-24_bildirim_seri_eposta_kanit.sql (begin…rollback,
-- ÖNCE ve SONRA çalıştırılır).
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-24_bildirim_seri_eposta.sql

begin;

-- B1 / B3: sütunlar -------------------------------------------------------
alter table public.profiles
  add column if not exists push_duel boolean not null default true,
  add column if not exists push_social boolean not null default true,
  add column if not exists email_verified_at timestamptz;

comment on column public.profiles.push_duel is
  'Düello bildirimleri (async_duel_*) açık mı. Varsayılan açık.';
comment on column public.profiles.push_social is
  'Arkadaş ve oda daveti bildirimleri (friend_request, friend_accept, room_invite) açık mı. Varsayılan açık.';
comment on column public.profiles.email_verified_at is
  'Nazik e-posta doğrulaması (6 haneli kod) tamamlanma zamanı. Yalnız mark_my_email_verified() yazar; oyun ya da sıralama bununla KAPILANMAZ.';

-- B3: istemci email_verified_at'i yazamaz --------------------------------
CREATE OR REPLACE FUNCTION public.profiles_client_write_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
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
    -- E-posta dogrulamasi yalnizca mark_my_email_verified() ile yazilir
    -- (2026-10-24): istemci kendini "dogrulanmis" yapamaz.
    new.email_verified_at := old.email_verified_at;
  end if;
  return new;
end;
$function$;

-- B1: tercih okuma / yazma ------------------------------------------------
create or replace function public.get_my_account_flags()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_row public.profiles%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  select * into v_row from public.profiles where id = v_uid;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;
  return jsonb_build_object(
    'success', true,
    'push_duel', v_row.push_duel,
    'push_social', v_row.push_social,
    'email_verified_at', v_row.email_verified_at
  );
end;
$function$;

create or replace function public.set_my_push_prefs(
  p_duel boolean default null,
  p_social boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel boolean;
  v_social boolean;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  update public.profiles
  set push_duel = coalesce(p_duel, push_duel),
      push_social = coalesce(p_social, push_social)
  where id = v_uid
  returning push_duel, push_social into v_duel, v_social;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;
  return jsonb_build_object(
    'success', true, 'push_duel', v_duel, 'push_social', v_social);
end;
$function$;

-- B1: claim_push_outbox türü tercihe göre süzer ---------------------------
-- Canlı gövde + iki ekleme (işaretli): adım 1'de tercihi kapalı satır
-- gönderilmeden kapatılır, adım 2'de seçilmez.
CREATE OR REPLACE FUNCTION public.claim_push_outbox(p_limit integer DEFAULT 20)
 RETURNS TABLE(job_id uuid, to_user_id uuid, kind text, title text, body text, fcm_token text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  -- 1) Yalnız YAŞ, ENGEL ya da KAPALI TERCİH yüzünden anlamsızlaşan satırlar
  --    GÖNDERİLMEDEN kapatılır (claimed_at yazılır, çağırana dönmez). Oda
  --    daveti 30 dk, öteki türler (kind null dahil) 24 saat sonra
  --    anlamsızdır; alıcı ile gönderen arasında (iki yönde) engel varsa
  --    bildirim sızmasın. from_user_id null ise (düello daveti) engel
  --    denetimi tetikleyicide yapılır. Tek çağrıda en çok 500 satır.
  update public.push_outbox o
  set claimed_at = now()
  where o.id in (
    select d.id
    from public.push_outbox d
    where d.claimed_at is null
      and (
        d.created_at < now() - case
          when coalesce(d.kind, '') = 'room_invite' then interval '30 minutes'
          else interval '24 hours'
        end
        or (
          d.from_user_id is not null
          and exists (
            select 1 from public.blocked_users b
            where (b.blocker_id = d.to_user_id and b.blocked_id = d.from_user_id)
               or (b.blocker_id = d.from_user_id and b.blocked_id = d.to_user_id)
          )
        )
        -- [2026-10-24] Alıcı bu türü kapatmışsa hiç gönderilmez.
        or exists (
          select 1 from public.profiles pp
          where pp.id = d.to_user_id
            and (
              (coalesce(d.kind, '') like 'async\_duel%' and not pp.push_duel)
              or (
                coalesce(d.kind, '') in ('friend_request', 'friend_accept', 'room_invite')
                and not pp.push_social
              )
            )
        )
      )
    order by d.created_at
    limit 500
    for update skip locked
  );

  -- 2) Gönderilecek seçim: yaş/engel koşulları burada da tekrarlanır
  --    (adım 1 sınırlı ya da kilitli satırı atlamış olabilir) ve YALNIZ
  --    profili + fcm_token'ı olanlar işaretlenir. Profili/token'ı olmayanın
  --    bildirimi yanmaz; token gelince gider, yoksa yaştan düşer.
  return query
  with picked as (
    select o.id
    from public.push_outbox o
    join public.profiles pr on pr.id = o.to_user_id
    where o.claimed_at is null
      and nullif(pr.fcm_token, '') is not null
      -- [2026-10-24] Tercih süzgeci (adım 1 sınırlı kalmış olabilir).
      and not (coalesce(o.kind, '') like 'async\_duel%' and not pr.push_duel)
      and not (
        coalesce(o.kind, '') in ('friend_request', 'friend_accept', 'room_invite')
        and not pr.push_social
      )
      and o.created_at >= now() - case
        when coalesce(o.kind, '') = 'room_invite' then interval '30 minutes'
        else interval '24 hours'
      end
      and not (
        o.from_user_id is not null
        and exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = o.to_user_id and b.blocked_id = o.from_user_id)
             or (b.blocker_id = o.from_user_id and b.blocked_id = o.to_user_id)
        )
      )
    order by o.created_at
    limit greatest(1, least(coalesce(p_limit, 20), 100))
    for update of o skip locked
  ),
  marked as (
    update public.push_outbox o
    set claimed_at = now()
    from picked
    where o.id = picked.id
    returning o.id, o.to_user_id, o.kind, o.title, o.body
  )
  select
    marked.id,
    marked.to_user_id,
    marked.kind,
    marked.title,
    marked.body,
    p.fcm_token
  from marked
  join public.profiles p on p.id = marked.to_user_id;
end;
$function$;

-- B2: seri onarımı --------------------------------------------------------
create table if not exists public.streak_repairs (
  player_id  uuid not null references public.profiles(id) on delete cascade,
  month_key  text not null check (month_key ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  break_day  date not null,
  paid       boolean not null,
  created_at timestamptz not null default now(),
  primary key (player_id, month_key)
);
alter table public.streak_repairs enable row level security;
-- Politika YOK: istemci tabloya doğrudan erişemez; yalnız RPC (definer).
revoke all on public.streak_repairs from public, anon, authenticated;

comment on table public.streak_repairs is
  'Seri onarımı kaydı: kullanıcı başına AY başına en çok bir satır. spend_streak_repair yazar.';

-- Anahtarlı onarım ücretleri için yapısal tekillik (spend_streak_freeze örüntüsü).
create unique index if not exists coin_transactions_streak_repair_key_uidx
  on public.coin_transactions (player_id, reason)
  where reason like 'streak_repair:%';

create or replace function public.spend_streak_repair(
  p_month text,
  p_break_day text,
  p_premium boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_cost constant integer := 100;
  v_now_utc date := (now() at time zone 'utc')::date;
  v_break date;
  v_month text := nullif(btrim(coalesce(p_month, '')), '');
  v_reason text;
  v_existing public.streak_repairs%rowtype;
  v_balance integer;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  -- Ay anahtarı yalnız yyyy-mm; saat dilimi payı için geçen/şimdiki/gelecek ay.
  if v_month is null or v_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
     or v_month not in (
       to_char(v_now_utc - 31, 'YYYY-MM'),
       to_char(v_now_utc, 'YYYY-MM'),
       to_char(v_now_utc + 31, 'YYYY-MM')
     ) then
    return jsonb_build_object('success', false, 'error', 'invalid month');
  end if;

  begin
    v_break := to_date(coalesce(p_break_day, ''), 'YYYY-MM-DD');
  exception when others then
    return jsonb_build_object('success', false, 'error', 'invalid break day');
  end;
  -- Onarım "son 24 saatte kırılan" seri içindir: kırılma günü yakın olmalı.
  if v_break < v_now_utc - 4 or v_break > v_now_utc + 1 then
    return jsonb_build_object('success', false, 'error', 'break day out of range');
  end if;

  v_reason := 'streak_repair:' || v_month;

  -- Aynı kullanıcının eşzamanlı iki denemesi sıraya girer.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select * into v_existing
  from public.streak_repairs
  where player_id = v_uid and month_key = v_month;
  if found then
    select coalesce(sum(amount), 0)::integer into v_balance
    from public.coin_transactions where player_id = v_uid;
    if v_existing.break_day = v_break then
      return jsonb_build_object(
        'success', true, 'already_repaired', true,
        'paid', v_existing.paid, 'balance', v_balance);
    end if;
    return jsonb_build_object(
      'success', false, 'error', 'monthly_limit', 'balance', v_balance);
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions where player_id = v_uid;

  if coalesce(p_premium, false) then
    insert into public.streak_repairs (player_id, month_key, break_day, paid)
    values (v_uid, v_month, v_break, false);
    return jsonb_build_object(
      'success', true, 'already_repaired', false, 'paid', false,
      'amount', 0, 'balance', v_balance);
  end if;

  if v_balance < v_cost then
    return jsonb_build_object(
      'success', false, 'error', 'insufficient balance', 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_cost, v_reason);
  insert into public.streak_repairs (player_id, month_key, break_day, paid)
  values (v_uid, v_month, v_break, true);

  return jsonb_build_object(
    'success', true, 'already_repaired', false, 'paid', true,
    'amount', v_cost, 'balance', v_balance - v_cost);
end;
$function$;

-- B3: e-posta doğrulama işareti ------------------------------------------
create or replace function public.mark_my_email_verified()
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_claims jsonb := coalesce(auth.jwt(), '{}'::jsonb);
  v_email text := lower(nullif(btrim(coalesce(v_claims->>'email', '')), ''));
  v_otp_fresh boolean;
  v_verified_at timestamptz;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;
  if coalesce((v_claims->>'is_anonymous')::boolean, false) or v_email is null then
    return jsonb_build_object('success', false, 'error', 'no email session');
  end if;

  -- Kod ile giriş kanıtı: amr = [{"method":"otp","timestamp":<epoch>}].
  -- Parola girişi 'password' taşır; yenilenen jeton eski amr'yi korur ama
  -- zaman damgası da eski kalır, bu yüzden 15 dk pencere uygulanır.
  select exists (
    select 1
    from jsonb_array_elements(
      case when jsonb_typeof(v_claims->'amr') = 'array'
           then v_claims->'amr' else '[]'::jsonb end
    ) a
    where a->>'method' in ('otp', 'magiclink')
      and (a->>'timestamp') ~ '^[0-9]+$'
      and (a->>'timestamp')::numeric >= extract(epoch from now()) - 900
  ) into v_otp_fresh;
  if not v_otp_fresh then
    return jsonb_build_object('success', false, 'error', 'otp session required');
  end if;

  -- Kod, bu hesabın kayıtlı adresine gitmiş olmalı.
  if not exists (
    select 1 from auth.users u
    where u.id = v_uid and lower(u.email) = v_email
  ) then
    return jsonb_build_object('success', false, 'error', 'email mismatch');
  end if;

  update public.profiles
  set email_verified_at = coalesce(email_verified_at, now())
  where id = v_uid
  returning email_verified_at into v_verified_at;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;
  return jsonb_build_object('success', true, 'email_verified_at', v_verified_at);
end;
$function$;

-- Yetkiler ----------------------------------------------------------------
revoke execute on function public.claim_push_outbox(integer) from public, anon, authenticated;

revoke all on function public.get_my_account_flags() from public, anon;
grant execute on function public.get_my_account_flags() to authenticated;
revoke all on function public.set_my_push_prefs(boolean, boolean) from public, anon;
grant execute on function public.set_my_push_prefs(boolean, boolean) to authenticated;
revoke all on function public.spend_streak_repair(text, text, boolean) from public, anon;
grant execute on function public.spend_streak_repair(text, text, boolean) to authenticated;
revoke all on function public.mark_my_email_verified() from public, anon;
grant execute on function public.mark_my_email_verified() to authenticated;

commit;
