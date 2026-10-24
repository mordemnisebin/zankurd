-- 2026-10-16: SON BOŞLUKLAR — beş sessiz sunucu kusuru, tek göç.
--   1) Çevrimiçi maçta kaydedilen favoriler hiç görünmüyordu
--      (get_my_favorite_questions).
--   2) Odadan ayrılan oyuncu, biten kalabalık odanın sonucunu göremiyordu.
--   3) start_async_duel yarım kalmış rastgele düelloyu sahipsiz bırakıyordu.
--   4) Altı fonksiyonda kalan UTC "bugün" -> public.app_today() (İstanbul).
--   5) Sıralamada oyuncu başına günlük puan tavanı yoktu (çoklu hesap
--      çiftliği).
--
-- Her gövde CANLI tanımdan (2026-10-16 sabahı, bugünkü göçler sonrası)
-- üretildi; yalnız aşağıda belirtilen satırlar farklıdır. SECURITY DEFINER,
-- search_path ve izinler (create or replace ile) korunur; yeni fonksiyonun
-- izni açıkça verilir. Bu dosya İSTEMCİ imzalarını değiştirmez: eski sürüm
-- uygulama çalışmaya devam eder.
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-16_son_bosluklar.sql`
-- Geri alma: önceki canlı gövdeler `git log -p` ile bu dosyadan önceki
-- göçlerde ve `pg_get_functiondef` çıktılarında; get_my_favorite_questions
-- için `drop function public.get_my_favorite_questions(uuid[]);`

begin;

-- ═════════════════════════════════════════════════════════════════════════
-- 1) get_my_favorite_questions(uuid[]) — çevrimiçi maçta kaydedilen favoriler
-- ═════════════════════════════════════════════════════════════════════════
-- NİÇİN: Oda maçında kaydedilen favoriler gerçek `questions.id` uuid'sini
-- tutar; paketli bankada karşılığı yoktur. İstemci `questions` tablosunu
-- okuyamaz (SELECT yok) ve eski `quiz_public_questions` görünümü yalnız
-- "permission denied" verdiği için 2026-10-15'te düşürüldü: bu favoriler
-- "Kaydedilen Sorular"da HİÇ görünmüyordu ve hata yutulduğu için fark
-- edilmiyordu.
-- NE YAPAR: yalnız ÇAĞIRANIN `favorite_questions` satırlarında olan ve onaylı
-- soruların gösterim verisini döndürür; `correct_option` ve açıklamalar
-- DÖNMEZ (istemci `hasHiddenAnswer` ile işaretler, yeniden oynatma bu
-- soruları dışarıda bırakır). Tek çağrıda en çok 200 kimlik; fazlası hata.
-- `favorite_questions.question_id` metindir, bu yüzden uuid metne çevrilip
-- eşlenir. Dönüş satırı `get_room_questions` ile aynı şekildedir.
create or replace function public.get_my_favorite_questions(p_ids uuid[])
returns setof jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_ids is null or coalesce(cardinality(p_ids), 0) = 0 then
    return;
  end if;

  if cardinality(p_ids) > 200 then
    raise exception 'Too many ids';
  end if;

  return query
  select jsonb_build_object(
    'id', q.id,
    'category_name', coalesce(c.name, 'Ziman'),
    'prompt', q.prompt,
    'option_a', q.option_a,
    'option_b', q.option_b,
    'option_c', q.option_c,
    'option_d', q.option_d,
    'question_type', q.question_type,
    'image_url', q.image_url,
    'difficulty', q.difficulty,
    'language_code', q.language_code
  )
  from unnest(p_ids) with ordinality as wanted(question_id, ord)
  join public.questions q on q.id = wanted.question_id
  join public.favorite_questions f
    on f.player_id = auth.uid()
   and f.question_id = q.id::text
  left join public.categories c on c.id = q.category_id
  where q.is_approved = true
  order by wanted.ord;
end;
$function$;

revoke all on function public.get_my_favorite_questions(uuid[]) from public, anon;
grant execute on function public.get_my_favorite_questions(uuid[]) to authenticated, service_role;

-- ═════════════════════════════════════════════════════════════════════════
-- 2) Odadan ayrılan oyuncu, biten kalabalık odanın sonucunu görsün
-- ═════════════════════════════════════════════════════════════════════════
-- NİÇİN: get_room_result_payload kalabalık odada `left_at is null` istiyordu;
-- oyunu bırakan (ya da hazır süresi dolup düşen) oyuncu, oda sonradan
-- bittiğinde kendi sonucunu ve son sıralamayı HİÇ göremiyordu: ana ekranda
-- bekleyen sonuç çıkmıyor, `get_my_room_result` null dönüyordu.
-- NE YAPAR: `mine.left_at is null` şartı kalkar (get_my_room_result ve
-- get_my_pending_room_result bu fonksiyona yaslanır, ayrı değişiklik
-- gerekmez); ayrılan, `left: true` satırıyla listede görünür. Hiç cevabı
-- olmayan oyuncuda `answers` NULL yerine [] döner. Eski (1v1/2 kişilik) oda
-- koşulu AYNEN kalır. acknowledge_room_result kalabalık odada ayrılanı da
-- kabul eder (yalnız `rp.left_at is null` şartı kalkar).

CREATE OR REPLACE FUNCTION public.get_room_result_payload(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_players jsonb;
  v_question_ids jsonb;
  v_answers jsonb;
  v_winner_id uuid;
  v_crowd boolean := false;
  v_saved_result record;
  v_saved_found boolean := false;
  v_live_found boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select
    saved_result.room_id,
    saved_result.payload,
    saved_result.finished_at,
    saved_result.room_created_at
  into v_saved_result
  from public.room_result_snapshots saved_result
  join public.room_players saved_member
    on saved_member.room_id = saved_result.room_id
    and saved_member.player_id = saved_result.player_id
  where saved_result.player_id = v_uid
    and (p_room_id is null or saved_result.room_id = p_room_id)
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = saved_result.room_id
        and receipt.player_id = v_uid
    )
  order by
    saved_result.finished_at desc,
    saved_result.room_created_at desc,
    saved_result.room_id desc
  limit 1;
  v_saved_found := found;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 30) as seconds_per_question,
    r.current_question_index,
    r.ended_reason,
    r.forfeited_by,
    r.finished_at,
    r.created_at,
    r.is_custom,
    r.max_players,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  join public.room_players mine
    on mine.room_id = r.id and mine.player_id = v_uid
  left join public.categories c on c.id = r.category_id
  where r.status = 'finished'
    and (p_room_id is null or r.id = p_room_id)
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and not exists (
      select 1
      from public.room_result_receipts receipt
      where receipt.room_id = r.id
        and receipt.player_id = v_uid
    )
    and (
      (
        r.is_custom and r.max_players > 2
        -- Ayrılan/düşen oyuncu da biten odanın sonucunu görür (2026-10-16):
        -- `left: true`, sırasız ve havuz payı olmadan gelir. Makbuz
        -- (acknowledge_room_result) bir kez verildikten sonra bekleyen
        -- sonuç olarak tekrar sunulmaz.
        and public.crowd_room_result_complete(r.id)
      )
      or (
    not (r.is_custom and r.max_players > 2)
    and coalesce(r.current_question_index, -1) = r.question_count
    and exists (
      select 1
      from public.room_players exact_players
      where exact_players.room_id = r.id
      having count(*) = 2
    )
    and exists (
      select 1
      from public.room_questions rq
      where rq.room_id = r.id
      having count(*) = r.question_count
        and count(distinct rq.question_index) = r.question_count
        and min(rq.question_index) = 0
        and max(rq.question_index) = r.question_count - 1
        and bool_and(rq.revealed_at is not null)
    )
    and exists (
      select 1
      from public.player_answers pa
      join public.room_questions answered_question
        on answered_question.room_id = pa.room_id
        and answered_question.question_id = pa.question_id
      join public.room_players answering_player
        on answering_player.room_id = pa.room_id
        and answering_player.player_id = pa.player_id
      where pa.room_id = r.id
      having count(*) = r.question_count * 2
    )
    and not exists (
      select 1
      from public.room_players member
      where member.room_id = r.id
        and (
          select count(*)
          from public.player_answers own_answer
          join public.room_questions own_question
            on own_question.room_id = own_answer.room_id
            and own_question.question_id = own_answer.question_id
          where own_answer.room_id = member.room_id
            and own_answer.player_id = member.player_id
        ) <> r.question_count
    )
    and not exists (
      select 1
      from public.room_players scored_player
      where scored_player.room_id = r.id
        and scored_player.score <> (
          select coalesce(sum(scored_answer.points_awarded), 0)::integer
          from public.player_answers scored_answer
          where scored_answer.room_id = scored_player.room_id
            and scored_answer.player_id = scored_player.player_id
        )
    )
      )
    )
  order by r.finished_at desc, r.created_at desc, r.id desc
  limit 1
  for share of r;
  v_live_found := found;

  if not v_live_found and not v_saved_found then
    return null;
  end if;

  if v_saved_found and (
    not v_live_found
    or row(
      v_saved_result.finished_at,
      v_saved_result.room_created_at,
      v_saved_result.room_id
    ) > row(v_room.finished_at, v_room.created_at, v_room.id)
  ) then
    return v_saved_result.payload;
  end if;

  v_crowd := v_room.is_custom and v_room.max_players > 2;

  if v_crowd then
    -- Kalabalık oda: skora göre sıralı, eşitlikte aynı rank'lı oyuncu listesi.
    v_players := public.room_result_players(v_room.id, null);
  else
  select jsonb_agg(
    jsonb_build_object(
      'player_id', rp.player_id,
      'display_name', coalesce(nullif(trim(p.display_name), ''), 'Hevrik'),
      'final_score', rp.score,
      'final_streak', rp.streak
    ) order by rp.joined_at, rp.player_id
  )
  into v_players
  from public.room_players rp
  join public.profiles p on p.id = rp.player_id
  where rp.room_id = v_room.id;
  end if;

  select jsonb_agg(rq.question_id order by rq.question_index)
  into v_question_ids
  from public.room_questions rq
  where rq.room_id = v_room.id;

  select jsonb_agg(
    jsonb_build_object(
      'question_id', rq.question_id,
      'question_index', rq.question_index,
      'selected_option', pa.selected_option,
      'correct_option', q.correct_option,
      'is_correct', pa.is_correct,
      'points_awarded', pa.points_awarded,
      'response_ms', pa.response_ms,
      'explanation', q.explanation,
      'explanation_ku', q.explanation_ku,
      'explanation_tr', q.explanation_tr
    ) order by rq.question_index
  )
  into v_answers
  from public.player_answers pa
  join public.room_questions rq
    on rq.room_id = pa.room_id and rq.question_id = pa.question_id
  join public.questions q on q.id = pa.question_id
  where pa.room_id = v_room.id
    and pa.player_id = v_uid;

  if v_crowd then
    v_winner_id := public.room_result_winner(v_room.id, null);
  else
  select case
    when min(rp.score) = max(rp.score) then null
    else (array_agg(rp.player_id order by rp.score desc, rp.player_id))[1]
  end
  into v_winner_id
  from public.room_players rp
  where rp.room_id = v_room.id;
  end if;

  return json_build_object(
    'room', json_build_object(
      'id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'category_name', v_room.category_name,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'status', 'finished',
      'current_question_index', v_room.current_question_index,
      'is_custom', v_room.is_custom,
      'max_players', v_room.max_players
    ),
    'own_player_id', v_uid,
    'players', v_players,
    'question_ids', v_question_ids,
    'answers', coalesce(v_answers, '[]'::jsonb),
    'winner_id', v_winner_id,
    'ended_reason', v_room.ended_reason,
    'forfeited_by', v_room.forfeited_by,
    'finished_at', v_room.finished_at
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.acknowledge_room_result(p_room_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_question_count integer;
  v_crowd boolean := false;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- İlk çağrı commit olup ağ yanıtı kaybolmuş olabilir. Makbuz zaten varsa
  -- kanıt satırları daha sonra anonimleştirilmiş/silinmiş olsa bile aynı
  -- başarılı sonucu döndür; idempotent retry yeniden tamlık aramamalıdır.
  if exists (
    select 1
    from public.room_result_receipts receipt
    where receipt.room_id = p_room_id
      and receipt.player_id = v_uid
  ) then
    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  -- Hesap silme öncesi güvenilir fonksiyonun ürettiği immutable snapshot,
  -- silinen rakibin kişisel satırları artık bulunmasa da aynı tamlık kanıtıdır.
  if exists (
    select 1
    from public.room_result_snapshots saved_result
    join public.room_players saved_member
      on saved_member.room_id = saved_result.room_id
      and saved_member.player_id = saved_result.player_id
    join public.rooms saved_room on saved_room.id = saved_result.room_id
    where saved_result.room_id = p_room_id
      and saved_result.player_id = v_uid
      and saved_room.status = 'finished'
      and saved_room.ended_reason = 'completed'
      and saved_result.payload ->> 'own_player_id' = v_uid::text
      and saved_result.payload ->> 'ended_reason' = 'completed'
      and saved_result.payload -> 'room' ->> 'id' = p_room_id::text
      and saved_result.payload -> 'room' ->> 'status' = 'finished'
      and jsonb_array_length(saved_result.payload -> 'question_ids') = (
        saved_result.payload -> 'room' ->> 'question_count'
      )::integer
      and (
        (
          -- Kalabalık oda anlık görüntüsü: oyuncu sayısı değişken, erken
          -- biten odada indeks/cevap sayısı soru sayısından küçük olabilir.
          saved_room.is_custom
          and saved_room.max_players > 2
          and jsonb_array_length(saved_result.payload -> 'players') >= 1
        )
        or (
          not (saved_room.is_custom and saved_room.max_players > 2)
          and (
            saved_result.payload -> 'room' ->> 'current_question_index'
          )::integer = (
            saved_result.payload -> 'room' ->> 'question_count'
          )::integer
          and jsonb_array_length(saved_result.payload -> 'players') = 2
          and jsonb_array_length(saved_result.payload -> 'answers') = (
            saved_result.payload -> 'room' ->> 'question_count'
          )::integer
        )
      )
  ) then
    insert into public.room_result_receipts (room_id, player_id)
    values (p_room_id, v_uid)
    on conflict (room_id, player_id) do nothing;

    return json_build_object('acknowledged', true, 'room_id', p_room_id);
  end if;

  select r.question_count, (r.is_custom and r.max_players > 2)
  into v_question_count, v_crowd
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where r.id = p_room_id
    and rp.player_id = v_uid
    and r.status = 'finished'
    and r.ended_reason = 'completed'
    and r.forfeited_by is null
    and r.finished_at is not null
    and r.question_count > 0
    and (
      coalesce(r.current_question_index, -1) = r.question_count
      -- Kalabalık oda erken bitebilir (kalan aktif < 2): indeks < soru sayısı.
      -- Ayrılan oyuncu da onaylayabilir (2026-10-16): sonucu görmüştür.
      or (r.is_custom and r.max_players > 2)
    )
  for share of r;

  if not found then
    raise exception 'Completed room result is unavailable';
  end if;

  if v_crowd then
    if not public.crowd_room_result_complete(p_room_id) then
      raise exception 'Completed room result is incomplete';
    end if;
  elsif not exists (
    select 1
    from public.room_players exact_players
    where exact_players.room_id = p_room_id
    having count(*) = 2
  ) or not exists (
    select 1
    from public.room_questions rq
    where rq.room_id = p_room_id
    having count(*) = v_question_count
      and count(distinct rq.question_index) = v_question_count
      and min(rq.question_index) = 0
      and max(rq.question_index) = v_question_count - 1
      and bool_and(rq.revealed_at is not null)
  ) or not exists (
    select 1
    from public.player_answers pa
    join public.room_questions answered_question
      on answered_question.room_id = pa.room_id
      and answered_question.question_id = pa.question_id
    join public.room_players answering_player
      on answering_player.room_id = pa.room_id
      and answering_player.player_id = pa.player_id
    where pa.room_id = p_room_id
    having count(*) = v_question_count * 2
  ) or exists (
    select 1
    from public.room_players member
    where member.room_id = p_room_id
      and (
        select count(*)
        from public.player_answers own_answer
        join public.room_questions own_question
          on own_question.room_id = own_answer.room_id
          and own_question.question_id = own_answer.question_id
        where own_answer.room_id = member.room_id
          and own_answer.player_id = member.player_id
      ) <> v_question_count
  ) or exists (
    select 1
    from public.room_players scored_player
    where scored_player.room_id = p_room_id
      and scored_player.score <> (
        select coalesce(sum(scored_answer.points_awarded), 0)::integer
        from public.player_answers scored_answer
        where scored_answer.room_id = scored_player.room_id
          and scored_answer.player_id = scored_player.player_id
      )
  ) then
    raise exception 'Completed room result is incomplete';
  end if;

  insert into public.room_result_receipts (room_id, player_id)
  values (p_room_id, v_uid)
  on conflict (room_id, player_id) do nothing;

  return json_build_object('acknowledged', true, 'room_id', p_room_id);
end;
$function$;

-- ═════════════════════════════════════════════════════════════════════════
-- 3) start_async_duel: yarım kalmış rastgele düelloyu yeniden ver
-- ═════════════════════════════════════════════════════════════════════════
-- NİÇİN: Çağıran, rakip olarak eşleşmiş ama bitirmediği bir düelloya sahipken
-- start_async_duel yine yeni bir düello açıyor ya da başka düelloya
-- eşleşiyordu; ilk düello sahipsiz kalıyordu (açan 48 saat boşuna bekliyor).
-- NE YAPAR: advisory kilidinden hemen sonra, çağıranın rakip olduğu,
-- sonucu olmayan, süresi dolmamış rastgele (invited_id/challenge_code boş)
-- `matched` düelloyu döndürür; bu dal hiçbir şey yazmaz. Kalan gövde AYNEN
-- canlıdan.

CREATE OR REPLACE FUNCTION public.start_async_duel(p_category text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_duel public.async_duels%rowtype;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_role text;
  v_opponent_name text;
  v_questions jsonb;
  v_duel_id uuid;
  v_expires_at timestamptz;
  v_answered integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  v_category_input := nullif(btrim(coalesce(p_category, '')), '');
  if v_category_input is not null then
    select c.id into v_category_id
    from public.categories c
    where upper(c.name) = upper(v_category_input)
      and c.is_active = true
    limit 1;

    if v_category_id is null then
      raise exception 'No questions';
    end if;
  end if;

  -- Aynı oyuncunun ağ tekrarı/çift dokunuşunu sıraya koyar; iki farklı
  -- oyuncu arasındaki eşleşme satır kilidiyle (aşağıda FOR UPDATE SKIP
  -- LOCKED) zaten güvenli.
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Yarım kalmış rastgele düello (2026-10-16): rakip olarak eşleşip henüz
  -- bitirmediğim bir düello varsa YENİSİ açılmaz/eşleşilmez, aynı düello
  -- kaldığı sorudan döner. Aksi hâlde ağ tekrarı ya da uygulamayı yeniden
  -- açma, ilk düelloyu sahipsiz bırakıp ikincisine eşleştirirdi. Yanıt
  -- bu fonksiyonun kendi şeklidir (+ answered/finished: istemci
  -- AsyncDuelStart bu alanları zaten okur). Arkadaş/bağlantı meydan okumaları
  -- (invited_id/challenge_code dolu) kendi giriş yolundan sürer.
  select d.* into v_duel
  from public.async_duels d
  where d.status = 'matched'
    and d.opponent_id = v_uid
    and d.invited_id is null
    and d.challenge_code is null
    and d.expires_at > now()
    and not exists (
      select 1
      from public.async_duel_results r
      where r.duel_id = d.id
        and r.player_id = v_uid
    )
  order by d.matched_at desc nulls last, d.created_at desc
  limit 1;

  if found then
    select p.display_name into v_opponent_name
    from public.profiles p
    where p.id = v_duel.creator_id;

    select count(*)::integer into v_answered
    from public.async_duel_answers a
    where a.duel_id = v_duel.id
      and a.player_id = v_uid;

    return jsonb_build_object(
      'duel_id', v_duel.id,
      'role', 'opponent',
      'opponent_name', v_opponent_name,
      'expires_at', v_duel.expires_at,
      'questions', public.async_duel_questions_payload(v_duel.question_ids),
      'answered', v_answered,
      'finished', false
    );
  end if;

  select d.* into v_duel
  from public.async_duels d
  where d.status = 'open'
    and d.creator_id <> v_uid
    and d.invited_id is null
    -- Bağlantı/arkadaş meydan okumaları (2026-10-13_friend_challenge.sql)
    -- rastgele eşleşmeye ASLA girmez.
    and d.challenge_code is null
    and d.expires_at > now()
    -- Engelleme (2026-10-02 M5): aramızda iki yönden biri engelliyse bu
    -- düelloya eşleşmem (hata yok, sıradaki uygun düelloya bakılır;
    -- join_matchmaking ile aynı davranış).
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
         or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
    )
    and (v_category_id is null or d.category_id = v_category_id)
    -- Yalnız açanın kendi turunu BİTİRDİĞİ düellolar eşleşir. Aksi hâlde
    -- ikinci oyuncu 7 soruyu oynar ama sonuç yerine "bekleniyor" görürdü;
    -- tasarımın vaadi, ikinci oyuncunun sonucu hemen görmesidir. Turunu
    -- yarıda bırakan açanın düellosu eşleşmez, 48 saatte süresi dolar.
    and exists (
      select 1
      from public.async_duel_results r
      where r.duel_id = d.id
        and r.player_id = d.creator_id
    )
  order by d.created_at asc
  limit 1
  for update skip locked;

  if found then
    -- Rakibe kendi 48 saati verilir: açık düellonun süresi açanın
    -- penceresiydi; 47. saatte eşleşen biri oynarken "Duel expired"
    -- alırdı.
    update public.async_duels
    set opponent_id = v_uid,
        status = 'matched',
        matched_at = now(),
        expires_at = greatest(expires_at, now() + interval '48 hours')
    where id = v_duel.id
    returning expires_at into v_expires_at;

    v_duel_id := v_duel.id;
    v_question_ids := v_duel.question_ids;
    v_role := 'opponent';

    select p.display_name into v_opponent_name
    from public.profiles p
    where p.id = v_duel.creator_id;
  else
    -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
    select count(*) into v_open_count
    from public.async_duels
    where creator_id = v_uid
      and status = 'open'
      and expires_at > now();

    if v_open_count >= 5 then
      raise exception 'Too many open duels';
    end if;

    -- `rnd` bir kez hesaplanır (SELECT listesinde); ORDER BY onu yeniden
    -- ÇAĞIRMAZ, aynı değeri kullanır — seçilen 7 soru ile array_agg'in
    -- verdiği sıra böylece birebir aynı kalır (index 0..6 bu sırayla).
    --
    -- Düello sorusu istemcide ATLANAMAZ: 7 soru iki oyuncuya aynı sırayla
    -- gider, cevaplar index'le eşleşir. Oda akışında istemci oynanamaz bir
    -- soruyu listeden düşürebiliyor (QuestionContentPolicy
    -- .isPlayableWithHiddenAnswer); düelloda düşürse index kayardı. Aynı
    -- süzgeç bu yüzden burada, seçimden ÖNCE uygulanır:
    --   * gizli kategoriler: lib/src/config/category_visibility.dart
    --     `hiddenCategoryIds` ile birebir aynı liste (bekçi:
    --     test/async_duel_sql_contract_test.dart);
    --   * yalnız metin soruları: görsel soruda 20 saniyelik sayaç görsel
    --     yüklenirken işler, yavaş bağlantıdaki oyuncu haksız yere kaybeder;
    --   * şıkları eksiksiz sorular: istemci boş şıkkı listeden çıkarır,
    --     aradaki bir boşluk A-D harf eşlemesini kaydırırdı;
    --   * doğru şıkkı geçerli sorular: answer_async_duel correct_option'ı
    --     cevapla ham karşılaştırır; 'a' ya da NULL taşıyan soru kimseye
    --     doğru yazdırmazdı.
    select array_agg(picked.id order by picked.rnd) into v_question_ids
    from (
      select q.id, random() as rnd
      from public.questions q
      join public.categories c on c.id = q.category_id
      where q.is_approved = true
        and c.is_active = true
        and (v_category_id is null or q.category_id = v_category_id)
        and btrim(coalesce(q.prompt, '')) <> ''
        and btrim(coalesce(q.option_a, '')) not in ('', '-')
        and btrim(coalesce(q.option_b, '')) not in ('', '-')
        and (
          (
            coalesce(q.question_type, 'multiple_choice') = 'multiple_choice'
            and btrim(coalesce(q.option_c, '')) not in ('', '-')
            and btrim(coalesce(q.option_d, '')) not in ('', '-')
            and q.correct_option in ('A', 'B', 'C', 'D')
          )
          or (
            q.question_type = 'true_false'
            and btrim(coalesce(q.option_c, '')) in ('', '-')
            and btrim(coalesce(q.option_d, '')) in ('', '-')
            and q.correct_option in ('A', 'B')
          )
        )
      order by rnd
      limit 7
    ) picked;

    v_question_count := coalesce(array_length(v_question_ids, 1), 0);
    if v_question_count < 7 then
      raise exception 'No questions';
    end if;

    insert into public.async_duels (
      category_id, question_ids, creator_id, status
    ) values (
      v_category_id, v_question_ids, v_uid, 'open'
    )
    returning id, expires_at into v_duel_id, v_expires_at;

    v_role := 'creator';
    v_opponent_name := null;
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'index', ord.idx - 1,
      'id', q.id,
      'category_name', coalesce(c.name, 'Ziman'),
      'prompt', q.prompt,
      'option_a', q.option_a,
      'option_b', q.option_b,
      'option_c', q.option_c,
      'option_d', q.option_d,
      'question_type', q.question_type,
      'image_url', q.image_url,
      'difficulty', q.difficulty
    ) order by ord.idx
  )
  into v_questions
  from unnest(v_question_ids) with ordinality as ord(question_id, idx)
  join public.questions q on q.id = ord.question_id
  left join public.categories c on c.id = q.category_id;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', v_role,
    'opponent_name', v_opponent_name,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$function$;

-- ═════════════════════════════════════════════════════════════════════════
-- 4) Kalan UTC "bugün"ler -> public.app_today() (Europe/Istanbul)
-- ═════════════════════════════════════════════════════════════════════════
-- NİÇİN: 2026-10-15 göçü ilerleme/ödül yollarını İstanbul gününe aldı; bu
-- altı fonksiyon hâlâ UTC günü (current_date / date_trunc UTC) kullanıyordu.
-- İstanbul'da 00:00-03:00 arası "yeni gün" başlamış olduğu hâlde günlük XP
-- sınırı, görev kaydı, günün etkinliği ve turnuva ilerlemesi önceki güne
-- yazılıyordu.
-- GEÇİŞ GÜVENLİĞİ: anahtarlar (user_id, mission_key, completion_date),
-- contests.day_key ve (user_id, tournament_date) yalnız gün DEĞERİ değişir;
-- tarih tek yönde (UTC gününden bir gün ileriye, yalnız 21:00-24:00 UTC
-- arasında) kayar, bu yüzden mevcut satırlarla çakışma ya da boşluk doğmaz.
-- Haftalık lig: bkz. league_week_start / finalize_weekly_league altında.

CREATE OR REPLACE FUNCTION public.award_xp_delta(p_delta integer)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_delta integer;
  v_row public.profiles%rowtype;
  v_today_total integer;
  v_allowed integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_row from public.profiles where id = v_uid for update;
  if not found then
    raise exception 'Profile not found';
  end if;

  v_delta := greatest(0, coalesce(p_delta, 0));
  if v_delta = 0 then
    return coalesce(v_row.xp, 0);
  end if;

  v_delta := least(v_delta, 2000);

  if v_row.xp_daily_date is distinct from public.app_today() then
    v_today_total := 0;
  else
    v_today_total := coalesce(v_row.xp_daily_total, 0);
  end if;

  v_allowed := greatest(0, 20000 - v_today_total);
  v_delta := least(v_delta, v_allowed);

  if v_delta = 0 then
    update public.profiles
    set xp_daily_date = public.app_today(),
        xp_daily_total = v_today_total,
        updated_at = now()
    where id = v_uid;
    return coalesce(v_row.xp, 0);
  end if;

  update public.profiles
  set xp = coalesce(xp, 0) + v_delta,
      xp_daily_total = v_today_total + v_delta,
      xp_daily_date = public.app_today(),
      updated_at = now()
  where id = v_uid
  returning xp into v_today_total;

  return coalesce(v_today_total, 0);
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_mission_completion(p_mission_key text, p_coin_reward integer, p_xp_reward integer)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID;
  v_today DATE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  v_today := public.app_today();

  -- Insert mission completion
  INSERT INTO mission_completions (
    user_id, mission_key, completion_date, coin_reward, xp_reward
  )
  VALUES (v_user_id, p_mission_key, v_today, p_coin_reward, p_xp_reward)
  ON CONFLICT (user_id, mission_key, completion_date) DO NOTHING;

  RETURN QUERY SELECT TRUE, 'Mission completion synced'::TEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_today_contest()
 RETURNS TABLE(id uuid, day_key date, theme_name_ku text, theme_description_ku text, category text, difficulty_min integer, difficulty_max integer, participation_reward integer, rank1_reward integer, rank2_reward integer, rank3_reward integer, question_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
#variable_conflict use_column
-- RETURNS TABLE'ın OUT parametreleri (day_key dahil) fonksiyon gövdesinde
-- örtük plpgsql değişkenleri olur; hiçbiri burada değişken olarak
-- kullanılmıyor (hepsi son SELECT'te c.* takma adıyla dönüyor), bu yüzden
-- `on conflict (day_key)` içindeki bare identifier ile OUT parametresi
-- arasındaki "ambiguous" hatasını önlemek için sütun her zaman kazanır.
declare
  -- Yedi günlük sabit bir tema rotasyonu: ayrı bir "contest_themes" tablosu
  -- kurmak bu ölçekte gereksiz soyutlama olurdu, sabit dizi yeterli.
  v_themes text[][] := array[
    array['Paradîgmayên Kurdî', 'Zanîna gelemperî û pirsên paradîgmayê', 'Paradigma'],
    array['Dîroka Me', 'Bûyer û kesayetiyên dîrokî', 'Dîrok'],
    array['Ziman û Edebiyat', 'Rêziman, biwêj û berhemên edebî', 'Ziman'],
    array['Cografyaya Cîhanê', 'Welat, bajar û taybetiyên cografî', 'Cografya'],
    array['Çand û Kevneşopî', 'Çand, adet û kevneşopiyên gelêrî', 'Çand'],
    array['Muzîk û Huner', 'Stranbêj, huner û hunermendên navdar', 'Muzîk'],
    array['Siyaset û Civak', 'Bûyerên siyasî û civakî yên rojane', 'Siyaset']
  ];
  v_idx int;
begin
  v_idx := 1 + (extract(doy from public.app_today())::int % array_length(v_themes, 1));

  insert into public.contests (
    day_key, theme_name_ku, theme_description_ku, category,
    difficulty_min, difficulty_max, participation_reward,
    rank1_reward, rank2_reward, rank3_reward, question_count
  )
  values (
    public.app_today(),
    v_themes[v_idx][1],
    v_themes[v_idx][2],
    v_themes[v_idx][3],
    1, 5, 10, 500, 300, 100, 10
  )
  on conflict (day_key) do nothing;

  return query
  select
    c.id, c.day_key, c.theme_name_ku, c.theme_description_ku, c.category,
    c.difficulty_min, c.difficulty_max, c.participation_reward,
    c.rank1_reward, c.rank2_reward, c.rank3_reward, c.question_count
  from public.contests c
  where c.day_key = public.app_today()
  limit 1;
end;
$function$;

CREATE OR REPLACE FUNCTION public.save_tournament_progress(p_stage text, p_user_score integer, p_opponent_score integer, p_bot_winners text[])
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_today DATE := public.app_today();
  v_current_stage TEXT;
  v_current_rank INT := 0;
  v_requested_rank INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Authenticated user required'::TEXT;
    RETURN;
  END IF;

  IF p_stage NOT IN ('lobby', 'quarter', 'semi', 'final', 'won', 'lost') THEN
    RETURN QUERY SELECT FALSE, 'Invalid tournament stage'::TEXT;
    RETURN;
  END IF;

  SELECT stage
    INTO v_current_stage
    FROM public.tournament_progress
   WHERE user_id = v_user_id
     AND tournament_date = v_today
   FOR UPDATE;

  v_current_rank := CASE v_current_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE 0
  END;

  v_requested_rank := CASE p_stage
    WHEN 'lobby' THEN 0
    WHEN 'quarter' THEN 1
    WHEN 'semi' THEN 2
    WHEN 'final' THEN 3
    WHEN 'won' THEN 4
    WHEN 'lost' THEN 4
    ELSE -1
  END;

  IF p_stage <> 'lost'
     AND v_current_stage IS NOT NULL
     AND v_requested_rank > v_current_rank + 1 THEN
    RETURN QUERY SELECT FALSE, 'Tournament stage jump rejected'::TEXT;
    RETURN;
  END IF;

  IF p_stage = 'won'
     AND (v_current_stage IS NULL OR v_current_stage <> 'final') THEN
    RETURN QUERY SELECT FALSE, 'Tournament champion must complete final'::TEXT;
    RETURN;
  END IF;

  INSERT INTO public.tournament_progress (
    user_id, tournament_date, stage, user_score, opponent_score, bot_winners
  )
  VALUES (v_user_id, v_today, p_stage, p_user_score, p_opponent_score, p_bot_winners)
  ON CONFLICT (user_id, tournament_date) DO UPDATE SET
    stage = EXCLUDED.stage,
    user_score = EXCLUDED.user_score,
    opponent_score = EXCLUDED.opponent_score,
    bot_winners = EXCLUDED.bot_winners,
    updated_at = now();

  RETURN QUERY SELECT TRUE, 'Tournament progress saved'::TEXT;
END;
$function$;

-- Haftalık lig: hafta İstanbul'da PAZARTESİ 00:00'da başlar. Cron
-- (`5 0 * * 1`, UTC) pazartesi 00:05 UTC = 03:05 İstanbul'da çalışır; hafta
-- çoktan kapanmıştır. Önceki hafta (2026-10-05) UTC sınırıyla kesinleşmişti;
-- yalnız hafta sınırının 3 saat öncesine (pazar 21:00-24:00 UTC) düşen
-- oyunlar o haftanın puanında kalır, kesinleşmiş satırlara dokunulmaz.
-- Devam eden hafta (2026-10-12) henüz kesinleşmedi: satırı yoktur, yeni sınırla
-- hesaplanır. league_memberships (week_start, player_id) anahtarı aynı tarih
-- değerini (pazartesi) üretmeye devam eder. Fonksiyon IMMUTABLE kalır
-- (sabit saat dilimi).

CREATE OR REPLACE FUNCTION public.league_week_start(ts timestamp with time zone DEFAULT now())
 RETURNS date
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select (date_trunc('week', ts at time zone 'Europe/Istanbul')::date);
$function$;

CREATE OR REPLACE FUNCTION public.finalize_weekly_league(p_week date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_week date := coalesce(p_week, public.league_week_start(now() - interval '1 day'));
  v_from timestamptz := (v_week::timestamp at time zone 'Europe/Istanbul');
  v_to   timestamptz := ((v_week + 7)::timestamp at time zone 'Europe/Istanbul');
  v_count int := 0;
begin
  insert into public.league_weeks (week_start, status)
  values (v_week, 'finalizing')
  on conflict (week_start) do update set status = 'finalizing';

  -- Önceki hafta kademesi (yoksa bronz)
  create temporary table if not exists _prev_tier on commit drop as
  select player_id, tier
  from public.league_memberships
  where week_start = (v_week - 7);

  -- Bu haftanın skorları
  create temporary table if not exists _week_scores on commit drop as
  select
    rp.player_id,
    coalesce(sum(rp.score), 0)::bigint as weekly_score
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  where r.status = 'finished'
    and r.finished_at >= v_from
    and r.finished_at < v_to
    and rp.player_id is not null
  group by rp.player_id;

  -- Sıralama + kademe yaz
  delete from public.league_memberships where week_start = v_week;

  insert into public.league_memberships (
    week_start, player_id, tier, weekly_score, weekly_rank,
    previous_tier, promoted, relegated
  )
  select
    v_week,
    s.player_id,
    public.league_tier_for_rank(s.rnk::int),
    s.weekly_score,
    s.rnk::int,
    coalesce(p.tier, 'bronz'),
    public.league_tier_for_rank(s.rnk::int) = 'zer' and coalesce(p.tier, 'bronz') <> 'zer'
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'bronz',
    public.league_tier_for_rank(s.rnk::int) = 'bronz' and coalesce(p.tier, 'bronz') in ('zer', 'ziv')
      or public.league_tier_for_rank(s.rnk::int) = 'ziv' and coalesce(p.tier, 'bronz') = 'zer'
  from (
    select
      player_id,
      weekly_score,
      rank() over (order by weekly_score desc, player_id) as rnk
    from _week_scores
  ) s
  left join _prev_tier p on p.player_id = s.player_id;

  get diagnostics v_count = row_count;

  update public.league_weeks
  set status = 'closed', finalized_at = now()
  where week_start = v_week;

  return jsonb_build_object(
    'week_start', v_week,
    'players', v_count,
    'status', 'closed'
  );
end;
$function$;

-- ═════════════════════════════════════════════════════════════════════════
-- 5) Sıralama: oyuncu başına GÜNLÜK puan tavanı (5000)
-- ═════════════════════════════════════════════════════════════════════════
-- NİÇİN: get_leaderboard / get_my_leaderboard_rank oda puanlarını tavansız
-- topluyordu; birkaç anonim hesabı olan biri (aralarında oda kurup oynayarak)
-- sınırsız puan biriktirip listenin tepesine çıkabiliyordu.
-- NE YAPAR: puan önce (oyuncu, odanın İstanbul bitiş günü) başına toplanır ve
-- günlük 5000'de kesilir, sonra günler toplanır. 5000: bir oda en çok
-- ~2300 puan veriyor (canlı en yüksek 2325, %95'i 1562); yani dürüst oyuncu
-- günde ~2 tam puanlı oda ya da çok daha fazla orta puanlı oda oynayarak
-- tavana varır, ama günde yüzlerce odayla çiftlik yapan biri tepeye
-- yürüyemez. Tavan YALNIZ sayılan puanı sınırlar: rooms_played tüm odaları,
-- best_streak en iyi seriyi saymaya devam eder. Bugün eklenen sıralama
-- (puan, seri, oda sayısı, kimlik) ve engel/ended_reason süzgeçleri aynen.
-- İki fonksiyon aynı hesabı yapar, sıra numaraları tutarlı kalır.

create or replace function public.get_leaderboard(p_days integer default -1, p_limit integer default 10)
returns table(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      least(coalesce(sum(rp.score), 0), 5000)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      -- Yalnız normal biten odalar (2026-10-15); NULL = sütundan önceki odalar.
      and coalesce(r.ended_reason, 'completed') = 'completed'
      -- Engelleme (2026-10-02 M5): engellediğim oyuncular MENİM listemde yok.
      -- Yalnız çağıranın engelleri uygulanır (tek yön); liste kişiye göre
      -- değişir ama başkasının engel bilgisi sızmaz.
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  )
  select
    pd.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(pd.day_score), 0)::bigint,
    coalesce(max(pd.day_streak), 0)::bigint,
    coalesce(sum(pd.day_rooms), 0)::bigint,
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from per_day pd
  left join public.profiles p on p.id = pd.player_id
  group by
    pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(pd.day_score), 0) > 0
  order by coalesce(sum(pd.day_score), 0) desc,
    coalesce(max(pd.day_streak), 0) desc,
    coalesce(sum(pd.day_rooms), 0) desc,
    pd.player_id asc
  limit least(greatest(p_limit, 1), 100);
$function$;

create or replace function public.get_my_leaderboard_rank(p_days integer default -1)
returns table(rank bigint, player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with per_day as (
    select
      rp.player_id,
      (r.finished_at at time zone 'Europe/Istanbul')::date as score_day,
      least(coalesce(sum(rp.score), 0), 5000)::bigint as day_score,
      coalesce(max(rp.streak), 0)::bigint as day_streak,
      count(distinct rp.room_id)::bigint as day_rooms
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    where r.status = 'finished'
      -- get_leaderboard ile aynı oda süzgeci, engel süzgeci ve günlük tavan
      -- (sıra numaraları tutarlı kalsın).
      and coalesce(r.ended_reason, 'completed') = 'completed'
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by rp.player_id, (r.finished_at at time zone 'Europe/Istanbul')::date
  ),
  board as (
    select
      pd.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(pd.day_score), 0)::bigint as total_score,
      coalesce(max(pd.day_streak), 0)::bigint as best_streak,
      coalesce(sum(pd.day_rooms), 0)::bigint as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from per_day pd
    left join public.profiles p on p.id = pd.player_id
    group by
      pd.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(pd.day_score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc,
          b.player_id asc
      ) as row_no
    from board b
  )
  select
    o.row_no as rank,
    o.player_id,
    o.display_name,
    o.total_score,
    o.best_streak,
    o.rooms_played,
    o.avatar_icon,
    o.avatar_color,
    o.avatar_url,
    o.avatar_frame,
    o.showcase_title
  from ordered o
  where o.player_id = auth.uid()
  limit 1;
$function$;

commit;
