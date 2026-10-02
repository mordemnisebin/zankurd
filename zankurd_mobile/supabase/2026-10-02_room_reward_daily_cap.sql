-- 2026-10-02: oda/quiz coin ödülüne günlük tavan (güvenlik denetimi M3).
--
-- KUSUR: `claim_quiz_reward` oda başına ödülü (≈ 20 + 6 × doğru + puan/80,
-- 10 soruluk tam odada ~90–100 coin) idempotent veriyor ama GÜNLÜK tavanı
-- yok. `claim_solo_reward` günde 45 coin, `award_xp_delta` günde 20000 XP ile
-- sınırlı; oda yolu sınırsızdı. Anonim giriş açık olduğundan iki hesap
-- birbirleriyle hızlıca oda bitirip (cevaplar sunucuda kayıtlı ama zaman ve
-- doğruluk serbest) saatler içinde binlerce coin biriktirebilir.
--
-- DÜZELTME: oda ödülünün PERFORMANS kısmı (taban + doğru × 6 + puan/80)
-- oyuncu başına günlük 300 coin ile sınırlanır. Tavan `room_reward_daily`
-- tablosunda sayılır — `coin_transactions` toplamından DEĞİL, çünkü o satırda
-- ücretli odanın bahis iadesi/kazancı da var ve bahis oyuncunun kendi
-- parasıdır; tavan onu kesmemeli. Tavan altında ödül ESKİSİYLE AYNI.
-- Oda başına tek ödül kuralı (`quiz_complete:room=<id>` kaydı) aynen durur:
-- tavana takılan oda da "talep edildi" sayılır (0 satırı yazılır), sonradan
-- yeniden denenip başka gün alınamaz.
--
-- 300 SEÇİMİ: solo tavanı (45) ile XP tavanı (20000 XP ≈ 500 odalık
-- doyum) arasında; dürüst bir oyuncu için günde ~3 tam oda. Sabit
-- `v_daily_cap`; ayarlamak için fonksiyonu yeniden kur.
--
-- ESKİ İSTEMCİ UYUMU: imza (5 parametre, hepsi DEFAULT'lu) ve `amount`,
-- `already_claimed` anahtarları aynı. Yeni anahtarlar (`daily_cap`,
-- `cap_reached`) eski istemcide yok sayılır. Tavan dolduğunda `amount`
-- yalnız bahis payını taşır (çoğu odada 0).
--
-- ARTA KALAN RİSK: tavan HESAP başınadır; çok sayıda anonim/e-posta hesabı
-- açan biri hâlâ N × 300 üretebilir. Kapatmak için Dashboard'da kayıt hız
-- sınırı + CAPTCHA, ödülü doğrulanmış kimliğe bağlamak (referral'daki gibi)
-- ürün kararı.
--
-- GERİ ALMA: önceki gövde `2026-09-22_xp_and_coin_idempotency.sql` ve
-- baseline'daki `claim_quiz_reward`; `drop table public.room_reward_daily`.

begin;

create table if not exists public.room_reward_daily (
  player_id uuid not null references public.profiles (id) on delete cascade,
  reward_date date not null,
  coins integer not null default 0 check (coins >= 0),
  primary key (player_id, reward_date)
);

alter table public.room_reward_daily enable row level security;
revoke all on table public.room_reward_daily from public, anon, authenticated;

create or replace function public.claim_quiz_reward(
  p_room_id uuid default null,
  p_score integer default 0,
  p_correct_count integer default 0,
  p_best_streak integer default 0,
  p_total_questions integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
  v_today date := current_date;
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
$$;

revoke all on function public.claim_quiz_reward(uuid, integer, integer, integer, integer)
  from public, anon;
grant execute on function public.claim_quiz_reward(uuid, integer, integer, integer, integer)
  to authenticated;

do $$
begin
  if to_regclass('public.room_reward_daily') is null then
    raise exception 'room_reward_daily yok';
  end if;
  if has_table_privilege('authenticated', 'public.room_reward_daily', 'select')
     or has_table_privilege('authenticated', 'public.room_reward_daily', 'insert')
     or has_table_privilege('anon', 'public.room_reward_daily', 'select') then
    raise exception 'room_reward_daily istemciye açık';
  end if;
  if pg_get_functiondef(
       'public.claim_quiz_reward(uuid,integer,integer,integer,integer)'::regprocedure
     ) not like '%v_daily_cap constant integer := 300%' then
    raise exception 'claim_quiz_reward tavanı yok';
  end if;
  if has_function_privilege(
       'anon', 'public.claim_quiz_reward(uuid,integer,integer,integer,integer)', 'execute') then
    raise exception 'claim_quiz_reward anon''a açık';
  end if;
  if not has_function_privilege(
       'authenticated', 'public.claim_quiz_reward(uuid,integer,integer,integer,integer)', 'execute') then
    raise exception 'claim_quiz_reward authenticated''a kapalı';
  end if;
end $$;

commit;
