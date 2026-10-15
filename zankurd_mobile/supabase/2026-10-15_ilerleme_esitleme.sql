-- 2026-10-15: İLERLEME EŞİTLEME + SOLO ÖDÜL TEKİLLİĞİ + TEK "BUGÜN".
--
-- NİÇİN (üç ayrı kusur, tek göç):
--
--   1. KAYITLI KULLANICI İLERLEMESİNİ KAYBEDİYORDU. Seri, rozet, seviye
--      yolu, aralıklı tekrar kuyruğu, ustalık yalnız cihazdaki
--      SharedPreferences'ta yaşıyordu; çıkış yapınca silinir, telefon
--      değişince ya da uygulama yeniden kurulunca geri gelmezdi. Premium
--      "seri koruma" satıyor ama seri hesabı izlemiyordu. Çözüm: hesaba
--      bağlı, sürümlü tek bir JSON anlık görüntüsü (`player_progress`),
--      istemciye kapalı tablo + iki RPC. İstemci cihazla BİRLEŞTİRİR
--      (rozet birleşimi, sayaç/seviye/ustalıkta en yüksek, seri = son oynama
--      günü yeni olan kayıt, tekrar kuyruğu birleşimi); sunucu yalnız saklar,
--      yorumlamaz. Misafirler de kullanabilir: yükseltme (linkIdentity /
--      updateUser) kimliği değiştirmez, veri onunla gider.
--      Hesap silme: `player_progress.player_id` -> `profiles(id) ON DELETE
--      CASCADE`; `delete_my_account` auth.users satırını siler, profiles
--      cascade'iyle bu tablo da gider (canlıda doğrulandı: profiles_id_fkey
--      confdeltype = 'c'). Doğrulama bloğu iki kenarı da denetler.
--
--   2. `claim_solo_reward` TEKİL DEĞİLDİ. Çevrimdışı/kopan bağlantıda
--      istemci aynı turu kuyruğa alıp yeniden gönderiyordu; ilk çağrı
--      sunucuda işlenmiş ama yanıtı kaybolmuşsa ikinci çağrı ikinci kez
--      jeton yazıyordu (günlük tavana kadar). Yeni imza
--      `claim_solo_reward(int,int,int,uuid)`: `p_client_round_id` ile
--      (player_id, client_round_id) tekil kaydı tutulur, aynı kimlikle ikinci
--      çağrı İLK sonucu `already_claimed: true` ile döner ve ÖDEMEZ.
--      ESKİ İMZA `claim_solo_reward(int,int,int)` yayındaki iOS 2.0.x için
--      aynı davranışla durur (artık yeni imzaya `null` kimlikle devreder).
--      Yeni imzada varsayılan DEĞER YOK: PostgREST adlandırılmış argümanla
--      çağrıyı iki imza arasında seçemezse PGRST203 verirdi.
--
--   3. "BUGÜN" UTC'ydi. Günlük tavanlar (solo tur, çark, oda ödülü) UTC
--      günüyle sayılıyordu: Türkiye'de gece 03:00'te sıfırlanır, akşam
--      oynayan oyuncu aynı "günde" iki tavan görürdü. `public.app_today()`
--      (Europe/Istanbul takvim günü) tek kaynak; aşağıdaki beş fonksiyon onu
--      kullanır. `claim_solo_reward` günün sınırlarını da İstanbul gününe
--      çevirir (eskiden `v_today::timestamptz` oturum dilimine, UTC'ye,
--      bakıyordu).
--
-- CANLIDA current_date KULLANAN FONKSİYONLAR (2026-10-15 salt okuma):
--   DEĞİŞTİRİLENLER (günlük tavan/çark/oda ödülü):
--     claim_solo_reward(int,int,int)   v_today + [v_today, v_today+1) aralığı
--     award_spin_coins()               v_today (ödül dizinini de seçer)
--     can_spin_today()                 spin_date = current_date
--     claim_daily_spin()               spin_date = current_date
--     claim_quiz_reward(uuid,...)      v_today (room_reward_daily.reward_date)
--   DEĞİŞTİRİLMEYENLER (kapsam dışı; istemci/ürün kararı gerekir):
--     award_xp_delta(int)              xp_daily_date (5 kullanım), UTC
--     award_xp_delta_once              award_xp_delta'ya devreder
--     sync_mission_completion          v_today := CURRENT_DATE
--     get_today_contest()              day_key / doy, UTC (yarışma günü)
--     save_tournament_progress         v_today := CURRENT_DATE
--     league_week_start / finalize_weekly_league  hafta sınırı 'UTC' (bilinçli)
--   Sütun varsayılanı, görünüm ve tetikleyicide current_date yok.
--   Geçiş günü: göçten önce UTC gününe yazılmış `spin_wheel_history` /
--   `room_reward_daily` satırları yeni İstanbul gününün satırıyla çakışabilir
--   (en çok bir günlük, tek seferlik küçük kayma).
--
-- GRANT (canlı proacl'e uyumlu: postgres, authenticated, service_role; anon
-- YOK): iki yeni tablo istemciye tamamen kapalı (RLS açık, politika yok, hiçbir
-- rolde SELECT/INSERT/UPDATE/DELETE); RPC'ler authenticated'a açık, anon'a ve
-- public'e kapalı. Anonim (misafir) oturum da `authenticated` rolüyle gelir.
--
-- ESKİ İSTEMCİ UYUMU: eski 3 argümanlı `claim_solo_reward` aynı JSON'u
-- döndürür; yeni RPC'ler/tablolar eski istemciyi etkilemez.
--
-- TEKRAR: idempotent (create ... if not exists, create or replace, revoke/
-- grant tekrarı zararsız). İkinci çalıştırma aynı sonucu verir.
-- GERİ ALMA:
--   drop function if exists public.get_my_progress();
--   drop function if exists public.save_my_progress(jsonb);
--   drop function if exists public.claim_solo_reward(integer, integer, integer, uuid);
--   drop table if exists public.player_progress;
--   drop table if exists public.solo_reward_claims;
--   -- 3 argümanlı claim_solo_reward + award_spin_coins/can_spin_today/
--   -- claim_daily_spin/claim_quiz_reward: önceki gövdeler
--   -- `current_date` kullanıyordu (2026-08-10_solo_round_reward.sql ve
--   -- ilgili göçler); yeniden uygulanır. drop function public.app_today();
-- Uygulama: supabase db query --linked -f supabase/2026-10-15_ilerleme_esitleme.sql
-- (Bu dosya canlıya UYGULANMADI; Docker olmadığından yerelde de çalıştırılmadı.
--  Bkz. supabase/applied.md.)

begin;

-- ---------------------------------------------------------------------
-- 1) Tek "bugün": Europe/Istanbul takvim günü
-- ---------------------------------------------------------------------

create or replace function public.app_today()
returns date
language sql
stable
set search_path = public
as $$
  select (now() at time zone 'Europe/Istanbul')::date;
$$;

-- Yalnız SECURITY DEFINER fonksiyonlar (sahip yetkisiyle) çağırır.
revoke all on function public.app_today() from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 2) İlerleme anlık görüntüsü
-- ---------------------------------------------------------------------

create table if not exists public.player_progress (
  player_id uuid primary key references public.profiles (id) on delete cascade,
  snapshot jsonb not null,
  updated_at timestamptz not null default now(),
  constraint player_progress_snapshot_shape
    check (
      jsonb_typeof(snapshot) = 'object'
      and octet_length(snapshot::text) <= 262144
    )
);

alter table public.player_progress enable row level security;
alter table public.player_progress force row level security;
-- Politika YOK ve doğrudan yetki YOK: erişim yalnız aşağıdaki RPC'lerle.
revoke all on table public.player_progress from public, anon, authenticated;

create or replace function public.get_my_progress()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.player_progress%rowtype;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_row
  from public.player_progress
  where player_id = v_uid;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'snapshot', v_row.snapshot,
    'updated_at', v_row.updated_at
  );
end;
$$;

create or replace function public.save_my_progress(p_snapshot jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := now();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object' then
    raise exception 'Invalid snapshot';
  end if;

  -- 256 KB: gerçek bir anlık görüntü onlarca KB'tır; sınır kötüye kullanımı
  -- ve yanlışlıkla şişen yükü keser (tabloda CHECK ile de güvence altında).
  if octet_length(p_snapshot::text) > 262144 then
    raise exception 'Snapshot too large';
  end if;

  perform 1 from public.profiles where id = v_uid;
  if not found then
    raise exception 'Profile missing';
  end if;

  insert into public.player_progress (player_id, snapshot, updated_at)
  values (v_uid, p_snapshot, v_now)
  on conflict (player_id) do update
    set snapshot = excluded.snapshot,
        updated_at = excluded.updated_at;

  return jsonb_build_object('ok', true, 'updated_at', v_now);
end;
$$;

revoke all on function public.get_my_progress() from public, anon;
grant execute on function public.get_my_progress() to authenticated;
revoke all on function public.save_my_progress(jsonb) from public, anon;
grant execute on function public.save_my_progress(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3) Solo ödül tekilliği
-- ---------------------------------------------------------------------

create table if not exists public.solo_reward_claims (
  player_id uuid not null references public.profiles (id) on delete cascade,
  client_round_id uuid not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (player_id, client_round_id)
);

alter table public.solo_reward_claims enable row level security;
alter table public.solo_reward_claims force row level security;
revoke all on table public.solo_reward_claims from public, anon, authenticated;

create or replace function public.claim_solo_reward(
  p_correct_count integer,
  p_total_questions integer,
  p_best_streak integer,
  p_client_round_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  -- İstanbul gününün [başı, sonu) aralığı; `v_today::timestamptz` oturum
  -- dilimine (UTC) bakardı.
  v_day_start timestamptz := public.app_today()::timestamp
    at time zone 'Europe/Istanbul';
  v_day_end timestamptz := (public.app_today() + 1)::timestamp
    at time zone 'Europe/Istanbul';
  v_daily_cap constant integer := 45;
  v_max_questions constant integer := 50;
  v_earned_today integer;
  v_remaining integer;
  v_amount integer;
  v_result jsonb;
  v_prior jsonb;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'amount', 0,
      'error', 'Authenticated user required'
    );
  end if;

  -- Girdiler istemciden gelir ve doğrulanamaz; yine de SAÇMA değerler
  -- reddedilir. Üst sınırı tavan koyar.
  if p_total_questions is null
     or p_total_questions <= 0
     or p_total_questions > v_max_questions
     or p_correct_count is null
     or p_correct_count < 0
     or p_correct_count > p_total_questions
     or p_best_streak is null
     or p_best_streak < 0
     or p_best_streak > p_total_questions then
    return jsonb_build_object('amount', 0, 'error', 'Invalid round summary');
  end if;

  -- Kilit: eşzamanlı iki talep (aynı kimlikli yeniden gönderim dahil) sıraya
  -- girer; tavanı ve tekillik kaydını birlikte aşamazlar.
  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'Profile missing');
  end if;

  -- Aynı tur ikinci kez gelirse İLK sonucu döndür, ödeme yapma.
  if p_client_round_id is not null then
    select c.result into v_prior
    from public.solo_reward_claims c
    where c.player_id = v_user_id
      and c.client_round_id = p_client_round_id;
    if found then
      return v_prior || jsonb_build_object('already_claimed', true);
    end if;
  end if;

  select coalesce(sum(amount), 0)
    into v_earned_today
  from public.coin_transactions
  where player_id = v_user_id
    and reason = 'solo_round'
    and created_at >= v_day_start
    and created_at < v_day_end;

  v_remaining := greatest(v_daily_cap - v_earned_today, 0);
  if v_remaining = 0 then
    v_result := jsonb_build_object(
      'amount', 0,
      'daily_cap', v_daily_cap,
      'cap_reached', true
    );
  else
    v_amount := least(4 + p_correct_count + p_best_streak, v_remaining);

    insert into public.coin_transactions (player_id, amount, reason)
    values (v_user_id, v_amount, 'solo_round');

    v_result := jsonb_build_object(
      'amount', v_amount,
      'daily_cap', v_daily_cap,
      'cap_reached', v_amount >= v_remaining
    );
  end if;

  if p_client_round_id is not null then
    insert into public.solo_reward_claims (
      player_id, client_round_id, result
    ) values (v_user_id, p_client_round_id, v_result)
    on conflict (player_id, client_round_id) do nothing;
  end if;

  return v_result;
end;
$$;

-- Yayındaki iOS 2.0.x eski imzayı çağırır: aynı davranış, kimliksiz.
create or replace function public.claim_solo_reward(
  p_correct_count integer,
  p_total_questions integer,
  p_best_streak integer
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.claim_solo_reward(
    p_correct_count, p_total_questions, p_best_streak, null::uuid
  );
$$;

revoke all on function public.claim_solo_reward(integer, integer, integer, uuid)
  from public, anon;
grant execute on function public.claim_solo_reward(integer, integer, integer, uuid)
  to authenticated;
revoke all on function public.claim_solo_reward(integer, integer, integer)
  from public, anon;
grant execute on function public.claim_solo_reward(integer, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------
-- 4) Çark ve oda ödülü: aynı "bugün" (gövdeler CANLI tanımlardan, yalnız
--    current_date -> public.app_today())
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.award_spin_coins()
 RETURNS TABLE(success boolean, reward_amount integer, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_today date := public.app_today();
  v_spin_id uuid;
  v_reward integer;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
begin
  if v_user_id is null then
    return query select false, 0, 'Authenticated user required'::text;
    return;
  end if;

  perform 1 from public.profiles where id = v_user_id for update;
  if not found then
    return query select false, 0, 'Profile missing'::text;
    return;
  end if;

  v_reward := v_rewards[
    (
      (extract(day from v_today)::integer
        + extract(month from v_today)::integer * 31)
      % array_length(v_rewards, 1)
    ) + 1
  ];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_user_id, v_today, v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return query select false, 0, 'Already spun today'::text;
    return;
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_user_id, v_reward, 'spin_wheel');

  return query select true, v_reward, 'Spin awarded successfully'::text;
end;
$function$;

CREATE OR REPLACE FUNCTION public.can_spin_today()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select auth.uid() is not null
    and not exists (
      select 1
      from public.spin_wheel_history
      where user_id = auth.uid()
        and spin_date = public.app_today()
    );
$function$;

CREATE OR REPLACE FUNCTION public.claim_daily_spin()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_spin_id uuid;
  v_rewards integer[] := array[10, 25, 50, 15, 75, 20, 100, 30];
  v_reward integer;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  v_reward := v_rewards[1 + floor(random() * array_length(v_rewards, 1))::int];

  insert into public.spin_wheel_history (user_id, spin_date, reward_amount)
  values (v_player_id, public.app_today(), v_reward)
  on conflict (user_id, spin_date) do nothing
  returning id into v_spin_id;

  if v_spin_id is null then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_reward, 'daily_spin:server');

  return jsonb_build_object(
    'amount', v_reward,
    'already_claimed', false
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_quiz_reward(p_room_id uuid DEFAULT NULL::uuid, p_score integer DEFAULT 0, p_correct_count integer DEFAULT 0, p_best_streak integer DEFAULT 0, p_total_questions integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_player_id uuid := auth.uid();
  v_room_status text;
  v_room_ended_reason text;
  v_current_question_index integer;
  v_room_score integer;
  v_correct_count integer;
  v_total_questions integer;
  v_answer_count integer;
  v_amount integer;
  v_base integer;
  v_base_paid integer;
  v_earned_today integer;
  v_today date := public.app_today();
  v_daily_cap constant integer := 300;
  v_reason text;
  v_entry_fee integer := 0;
  v_winner_id uuid := null;
begin
  if v_player_id is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0));

  perform 1 from public.profiles where id = v_player_id for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  if p_room_id is null then
    return jsonb_build_object(
      'amount', 0,
      'verification_required', true
    );
  end if;

  select r.status, r.ended_reason, r.current_question_index, coalesce(r.entry_fee, 0)
  into v_room_status, v_room_ended_reason, v_current_question_index, v_entry_fee
  from public.rooms r
  join public.room_players rp
    on rp.room_id = r.id
   and rp.player_id = v_player_id
  where r.id = p_room_id
  for update of r;

  if not found then
    raise exception 'Player is not in the room';
  end if;

  if v_room_status <> 'finished' then
    return jsonb_build_object('amount', 0, 'room_not_finished', true);
  end if;

  if v_room_ended_reason is distinct from 'completed' then
    return jsonb_build_object(
      'amount', 0,
      'room_not_completed', true,
      'ended_reason', v_room_ended_reason
    );
  end if;

  select count(*)::integer into v_total_questions
  from public.room_questions rq
  where rq.room_id = p_room_id;

  if v_total_questions < 1
     or coalesce(v_current_question_index, -1) < v_total_questions then
    return jsonb_build_object(
      'amount', 0,
      'room_progress_incomplete', true
    );
  end if;

  select
    count(*)::integer,
    count(*) filter (where pa.is_correct)::integer,
    coalesce(sum(pa.points_awarded), 0)::integer
  into v_answer_count, v_correct_count, v_room_score
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id
   and rq.question_id = pa.question_id
  where pa.room_id = p_room_id
    and pa.player_id = v_player_id;

  if v_answer_count <> v_total_questions then
    return jsonb_build_object('amount', 0, 'answers_incomplete', true);
  end if;

  v_reason := 'quiz_complete:room=' || p_room_id::text;
  select max(coin_tx.amount)::integer
  into v_amount
  from public.coin_transactions coin_tx
  where coin_tx.player_id = v_player_id
    and coin_tx.reason = v_reason;
  if v_amount is not null then
    return jsonb_build_object(
      'amount', v_amount,
      'already_claimed', true
    );
  end if;

  v_base :=
    case when v_total_questions >= 10 then 20 else 8 end
    + (v_correct_count * 6)
    + (v_room_score / 80);

  -- Günlük tavan: yalnız performans ödülü sayılır, bahis payı sayılmaz.
  -- Profil satırı yukarıda kilitli olduğundan eşzamanlı iki talep tavanı
  -- birlikte aşamaz.
  select rd.coins into v_earned_today
  from public.room_reward_daily rd
  where rd.player_id = v_player_id
    and rd.reward_date = v_today;

  v_base_paid := least(
    v_base,
    greatest(v_daily_cap - coalesce(v_earned_today, 0), 0)
  );

  v_amount := v_base_paid;

  -- Ücretli odada bahis havuzu ödülü
  if v_entry_fee > 0 then
    select case
      when min(rp.score) = max(rp.score) then null
      else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
    end
    into v_winner_id
    from public.room_players rp
    where rp.room_id = p_room_id;

    if v_winner_id = v_player_id then
      v_amount := v_amount + (v_entry_fee * 2);
    elsif v_winner_id is null then
      v_amount := v_amount + v_entry_fee;
    end if;
  end if;

  insert into public.room_reward_daily (player_id, reward_date, coins)
  values (v_player_id, v_today, v_base_paid)
  on conflict (player_id, reward_date) do update
    set coins = public.room_reward_daily.coins + excluded.coins;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_player_id, v_amount, v_reason);

  return jsonb_build_object(
    'amount', v_amount,
    'already_claimed', false,
    'daily_cap', v_daily_cap,
    'cap_reached', v_base_paid < v_base
  );
end;
$function$;


-- ---------------------------------------------------------------------
-- 5) Doğrulama (kusurluysa göç geri alınır)
-- ---------------------------------------------------------------------

do $$
declare
  v_fn text;
  v_def text;
  v_tbl text;
begin
  -- Tablolar: RLS açık, istemciye hiçbir doğrudan yetki yok.
  foreach v_tbl in array array['public.player_progress', 'public.solo_reward_claims'] loop
    if not (select relrowsecurity from pg_class where oid = v_tbl::regclass) then
      raise exception 'ilerleme_esitleme: % RLS kapalı', v_tbl;
    end if;
    if has_table_privilege('anon', v_tbl, 'select,insert,update,delete')
       or has_table_privilege('authenticated', v_tbl, 'select,insert,update,delete') then
      raise exception 'ilerleme_esitleme: % istemciye açık', v_tbl;
    end if;
  end loop;

  -- Hesap silme zinciri: profiles -> auth.users cascade + iki tablo -> profiles cascade.
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and contype = 'f' and confrelid = 'auth.users'::regclass
      and confdeltype = 'c'
  ) then
    raise exception 'ilerleme_esitleme: profiles -> auth.users cascade değil (hesap silme ilerlemeyi bırakır)';
  end if;
  foreach v_tbl in array array['public.player_progress', 'public.solo_reward_claims'] loop
    if not exists (
      select 1 from pg_constraint
      where conrelid = v_tbl::regclass
        and contype = 'f' and confrelid = 'public.profiles'::regclass
        and confdeltype = 'c'
    ) then
      raise exception 'ilerleme_esitleme: % -> profiles ON DELETE CASCADE değil', v_tbl;
    end if;
  end loop;

  -- RPC'ler: authenticated açık, anon kapalı.
  foreach v_fn in array array[
    'public.get_my_progress()',
    'public.save_my_progress(jsonb)',
    'public.claim_solo_reward(integer,integer,integer,uuid)',
    'public.claim_solo_reward(integer,integer,integer)'
  ] loop
    if not has_function_privilege('authenticated', v_fn::regprocedure, 'execute') then
      raise exception 'ilerleme_esitleme: % authenticated''a kapalı', v_fn;
    end if;
    if has_function_privilege('anon', v_fn::regprocedure, 'execute') then
      raise exception 'ilerleme_esitleme: % anon''a açık', v_fn;
    end if;
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if v_def not ilike '%security definer%' or v_def not like '%search_path%' then
      raise exception 'ilerleme_esitleme: % SECURITY DEFINER/search_path eksik', v_fn;
    end if;
  end loop;

  if has_function_privilege('anon', 'public.app_today()'::regprocedure, 'execute')
     or has_function_privilege('authenticated', 'public.app_today()'::regprocedure, 'execute') then
    raise exception 'ilerleme_esitleme: app_today istemciye açık';
  end if;

  -- 256 KB sınırı ve tekillik mantığı gövdede.
  if pg_get_functiondef('public.save_my_progress(jsonb)'::regprocedure) not like '%262144%' then
    raise exception 'ilerleme_esitleme: save_my_progress boyut sınırı yok';
  end if;
  v_def := pg_get_functiondef('public.claim_solo_reward(integer,integer,integer,uuid)'::regprocedure);
  if v_def not like '%solo_reward_claims%' or v_def not like '%already_claimed%' then
    raise exception 'ilerleme_esitleme: claim_solo_reward tekillik mantığı eksik';
  end if;

  -- Tek "bugün": beş fonksiyonda current_date kalmadı, app_today kullanılıyor.
  foreach v_fn in array array[
    'public.claim_solo_reward(integer,integer,integer,uuid)',
    'public.award_spin_coins()',
    'public.can_spin_today()',
    'public.claim_daily_spin()',
    'public.claim_quiz_reward(uuid,integer,integer,integer,integer)'
  ] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if v_def ilike '%current_date%' then
      raise exception 'ilerleme_esitleme: % hâlâ current_date kullanıyor', v_fn;
    end if;
    if v_def not like '%app_today%' then
      raise exception 'ilerleme_esitleme: % app_today kullanmıyor', v_fn;
    end if;
  end loop;

  -- İstanbul günü gerçekten UTC+3 takvim günü.
  if public.app_today() <> ((now() at time zone 'UTC') + interval '3 hours')::date then
    raise exception 'ilerleme_esitleme: app_today İstanbul gününe uymuyor';
  end if;
end $$;

commit;
