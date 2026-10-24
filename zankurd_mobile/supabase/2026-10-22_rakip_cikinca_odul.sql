-- 2026-10-22: rakibi oyun ortasında çıkan oyuncuya performans ödülü.
--
-- Kusur: 1v1'de rakip çıkınca (ended_reason='forfeit') ya da kalabalık
-- odada son kalan olunca (crowd_room_member_leave → 'completed', indeks
-- ilerlemez) claim_quiz_reward 0 dönüyordu. Oyuncu "Kazandın" görüp hiç
-- jeton almıyordu (iki simülatör turu, 2026-10-22).
--
-- Düzeltme: yalnız claim_quiz_reward değişir. Kalan oyuncu verdiği
-- cevapların performans payını alır (doğru × 6 + puan / 80); bitirme primi
-- ve bahis havuzu verilmez, günlük tavan (300) aynıdır, aynı reason anahtarı
-- ile tek seferliktir. Ayrılan oyuncu (left_at / forfeited_by) bu daldan
-- yararlanamaz. Tam oyun yolu değişmez.

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
  v_crowd boolean := false;
  v_left boolean := false;
  v_pool integer := 0;
  v_distributed integer := 0;
  v_my_share integer := 0;
  v_remainder_owner uuid;
  v_forfeited_by uuid;
  v_early_win boolean := false;
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

  select r.status, r.ended_reason, r.current_question_index, coalesce(r.entry_fee, 0),
    (r.is_custom and r.max_players > 2), rp.left_at is not null, r.forfeited_by
  into v_room_status, v_room_ended_reason, v_current_question_index, v_entry_fee,
    v_crowd, v_left, v_forfeited_by
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

  select count(*)::integer into v_total_questions
  from public.room_questions rq
  where rq.room_id = p_room_id;

  -- 2026-10-22: rakibi oyun ortasında çıkan oyuncu (1v1 hükmen ya da
  -- kalabalık odada son kalan) eskiden 0 jeton alıyordu. Artık verdiği
  -- cevapların performans payını alır: doğru başına 6 + puan/80. Bitirme
  -- primi (20/8) ve bahis havuzu YOK (giriş ücreti çıkışta iade edildi).
  -- Anlaşmalı kötüye kullanım tam oyundan fazlasını getiremez; günlük
  -- tavan aynıdır. Ayrılanın kendisi bu daldan yararlanamaz.
  v_early_win := not v_left and (
    (v_room_ended_reason = 'forfeit'
      and v_forfeited_by is not null
      and v_forfeited_by <> v_player_id)
    or (v_room_ended_reason = 'completed'
      and coalesce(v_current_question_index, -1) < v_total_questions)
  );

  if v_early_win then
    v_reason := 'quiz_complete:room=' || p_room_id::text;
    select max(coin_tx.amount)::integer
    into v_amount
    from public.coin_transactions coin_tx
    where coin_tx.player_id = v_player_id
      and coin_tx.reason = v_reason;
    if v_amount is not null then
      return jsonb_build_object(
        'amount', v_amount,
        'already_claimed', true,
        'ended_early', true
      );
    end if;

    select
      count(*) filter (where pa.is_correct)::integer,
      coalesce(sum(pa.points_awarded), 0)::integer
    into v_correct_count, v_room_score
    from public.player_answers pa
    where pa.room_id = p_room_id
      and pa.player_id = v_player_id;

    v_base := (v_correct_count * 6) + (v_room_score / 80);
    if v_base <= 0 then
      -- Hiç doğru yok: istemcinin bildiği kalıcı sıfır.
      return jsonb_build_object(
        'amount', 0,
        'room_not_completed', true,
        'ended_reason', v_room_ended_reason
      );
    end if;

    select rd.coins into v_earned_today
    from public.room_reward_daily rd
    where rd.player_id = v_player_id
      and rd.reward_date = v_today;

    v_base_paid := least(
      v_base,
      greatest(v_daily_cap - coalesce(v_earned_today, 0), 0)
    );

    insert into public.room_reward_daily (player_id, reward_date, coins)
    values (v_player_id, v_today, v_base_paid)
    on conflict (player_id, reward_date) do update
      set coins = public.room_reward_daily.coins + excluded.coins;

    insert into public.coin_transactions (player_id, amount, reason)
    values (v_player_id, v_base_paid, v_reason);

    return jsonb_build_object(
      'amount', v_base_paid,
      'already_claimed', false,
      'ended_early', true,
      'daily_cap', v_daily_cap,
      'cap_reached', v_base_paid < v_base
    );
  end if;

  if v_room_ended_reason is distinct from 'completed' then
    return jsonb_build_object(
      'amount', 0,
      'room_not_completed', true,
      'ended_reason', v_room_ended_reason
    );
  end if;

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
  if v_entry_fee > 0 and v_crowd then
    -- Kalabalık oda havuzu (2026-10-16): ücret x katılan herkes (ayrılanlar
    -- dahil); yalnız oyunda kalanlar sıralanır, ilk üç sıra %50/%30/%20.
    -- Eşit puanlılar kapladıkları sıraların payını bölüşür; aşağı yuvarlama
    -- artığı ve boş kalan sıraların payı birincilerin en küçük kimliğine.
    -- Ayrılan oyuncu havuzdan pay almaz.
    if not v_left then
      select count(*)::integer * v_entry_fee into v_pool
      from public.room_players rp
      where rp.room_id = p_room_id;

      with ranked as (
        select rp.player_id,
          rank() over (order by rp.score desc) as rnk,
          count(*) over (partition by rp.score) as grp
        from public.room_players rp
        where rp.room_id = p_room_id
          and rp.left_at is null
      ), shares as (
        select ranked.player_id, ranked.rnk,
          ((v_pool::bigint * (
            select coalesce(sum(p.pct), 0)
            from (values (1, 50), (2, 30), (3, 20)) as p(pos, pct)
            where p.pos >= ranked.rnk and p.pos < ranked.rnk + ranked.grp
          )) / 100 / ranked.grp)::integer as share
        from ranked
      )
      select
        coalesce(sum(shares.share), 0)::integer,
        coalesce(max(shares.share) filter (where shares.player_id = v_player_id), 0),
        (select s2.player_id from shares s2 where s2.rnk = 1 order by s2.player_id limit 1)
      into v_distributed, v_my_share, v_remainder_owner
      from shares;

      v_amount := v_amount + v_my_share;
      if v_remainder_owner = v_player_id then
        v_amount := v_amount + greatest(v_pool - v_distributed, 0);
      end if;
    end if;
  elsif v_entry_fee > 0 then
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
