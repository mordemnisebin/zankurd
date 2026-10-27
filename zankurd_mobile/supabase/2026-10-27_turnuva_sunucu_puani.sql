-- Turnuva maçı sunucuda puanlanır; şampiyon ödülü gerçekten ödenir
-- (2026-10-27).
--
-- KUSUR: lobi "Şampiyon ödülü 200 jeton" diyordu ama sunucu ödemiyordu.
-- `submit_tournament_match(p_match_id, p_score)` skoru İSTEMCİDEN alıyordu;
-- tavanı hızla gönderen her maçı kazanabildiği için
-- `2026-10-02_tournament_reward_server_validated.sql` ödülü
-- `scores_server_validated` bayrağına bağlamış, hiçbir kupa da o bayrakla
-- açılmamıştı. 4 simülatörlü turda şampiyon "Ödül henüz doğrulanmadı"
-- gördü.
--
-- DÜZELTME (o dosyanın "TURNUVA YENİDEN AÇILIRKEN" notundaki yol):
--   * Maçın soruları SUNUCUDA seçilir ve maça yazılır (iki oyuncuya aynı
--     sıra): `start_tournament_match`.
--   * Soru İÇERİĞİ yalnız sunumda, tek tek verilir
--     (`present_tournament_question`); başlangıç yanıtında sunulmamış
--     sorular boş yer tutucudur. Böylece sorular önceden çözülüp anında
--     cevaplanarak hız bonusu şişirilemez (dış inceleme: Codex GPT-6.1-Sol
--     + Gemini 3.8 Flash, ikisi de engelleyici).
--   * Cevap süresi sunum kaydından sunucu saatiyle ölçülür, doğruluk
--     sunucuda karar verilir (`answer_tournament_question`): sıra zorunlu,
--     20 sn + 5 sn ağ payını aşan cevap yanlış, sunum kaydı olmayan cevap
--     REDDEDİLİR (yalnız "süre doldu" kabul: yarıda çıkış 0 puanla kapanır).
--   * `advance_tournament` kupa satırını kilitler: iki yarı final aynı anda
--     biterse ikisi de ötekini bitmemiş görüp finali hiç kurmuyordu
--     (eski yolda da vardı; dış inceleme).
--   * Puan: doğru cevap başına 100 + hız bonusu (en çok 50; eski istemci
--     tavanıyla aynı ölçek, soru başına 150). Son cevapta skor maça yazılır;
--     iki oyuncu da bitirince kazanan (yüksek puan, eşitlikte az toplam
--     süre, o da eşitse önce bitiren) belirlenir ve tur ilerler.
--   * Yeni kupalar `scores_server_validated = true` açılır; böylece
--     `claim_tournament_reward` şampiyona 200 jeton öder.
--   * `submit_tournament_match` sunucu puanlı kupada istemci skorunu YAZMAZ;
--     'Update required' hatası döner (eski istemci "skor gönderilemedi"
--     uyarısını gösterir, sessizce hükmen kaybetmez).
--
-- Düello tablolarına dokunulmaz: turnuva cevapları kendi tablolarında durur,
-- düello gelen kutusu/geçmişi/hatırlatmaları etkilenmez.
--
-- GERİ ALMA: supabase/geri_al/2026-10-27_turnuva_sunucu_puani_geri.sql
begin;

-- Maçın soruları AYRI ve kapalı tabloda: `tournament_matches` herkese
-- okunur (şema için), soru kimlikleri orada dursaydı uygulama paketindeki
-- yerel bankayla eşlenip sunumdan önce çözülebilirdi (dış inceleme 2. tur).
create table if not exists public.tournament_match_questions (
  match_id uuid primary key references public.tournament_matches(id)
    on delete cascade,
  question_ids uuid[] not null
);

create table if not exists public.tournament_match_answers (
  match_id uuid not null references public.tournament_matches(id)
    on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  question_index integer not null,
  choice text not null,
  is_correct boolean not null,
  response_ms integer not null,
  points integer not null,
  answered_at timestamptz not null default now(),
  primary key (match_id, player_id, question_index)
);

create table if not exists public.tournament_match_question_starts (
  match_id uuid not null references public.tournament_matches(id)
    on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  question_index integer not null,
  started_at timestamptz not null default clock_timestamp(),
  primary key (match_id, player_id, question_index)
);

-- Yalnız SECURITY DEFINER fonksiyonlar okur/yazar: istemciye doğrudan
-- tablo erişimi yok (doğru şık sızmasın, cevap elle yazılamasın).
alter table public.tournament_match_questions enable row level security;
alter table public.tournament_match_answers enable row level security;
alter table public.tournament_match_question_starts enable row level security;
revoke all on public.tournament_match_questions
  from public, anon, authenticated;
revoke all on public.tournament_match_answers from public, anon, authenticated;
revoke all on public.tournament_match_question_starts
  from public, anon, authenticated;

-- Yeni kupalar sunucu puanlı. Henüz maçı kurulmamış açık kupa da öyle
-- (kurulmuş maçı olan eski kupa istemci skoruyla bitsin, ödülsüz).
alter table public.tournaments
  alter column scores_server_validated set default true;
update public.tournaments t
   set scores_server_validated = true
 where t.status = 'open'
   and not exists (
     select 1 from public.tournament_matches m where m.tournament_id = t.id
   );

-- ─── Maçı başlat / kaldığı yerden sürdür ──────────────────────────────────
create or replace function public.start_tournament_match(p_match_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.tournament_matches%rowtype;
  v_tournament public.tournaments%rowtype;
  v_other uuid;
  v_other_name text;
  v_count integer;
  v_ids uuid[];
  v_used uuid[];
  v_answered integer;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_match
  from public.tournament_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_uid = v_match.player_one then
    v_other := v_match.player_two;
  elsif v_uid = v_match.player_two then
    v_other := v_match.player_one;
  else
    raise exception 'Not a match player';
  end if;

  if v_other is null then
    raise exception 'Match not found';
  end if;

  select * into v_tournament
  from public.tournaments
  where id = v_match.tournament_id;

  -- İstemci bu yanıtla eski (istemci skorlu) yola düşer.
  if not coalesce(v_tournament.scores_server_validated, false) then
    raise exception 'Not server scored';
  end if;

  select count(*)::integer into v_answered
  from public.tournament_match_answers a
  where a.match_id = p_match_id and a.player_id = v_uid;

  if v_match.status <> 'completed'
     and v_match.deadline is not null
     and v_match.deadline <= clock_timestamp() then
    raise exception 'Match expired';
  end if;

  v_count := greatest(coalesce(v_tournament.questions_per_match, 4), 1);

  select tq.question_ids into v_ids
  from public.tournament_match_questions tq
  where tq.match_id = p_match_id;

  -- Kapanmış (hükmen/süre dolumu) ve hiç oynanmamış maça soru seçilmez.
  if v_ids is null and v_match.status = 'completed' then
    return jsonb_build_object(
      'duel_id', v_match.id,
      'role', case when v_uid = v_match.player_one then 'creator'
                   else 'opponent' end,
      'opponent_name', null,
      'opponent_id', v_other,
      'expires_at', coalesce(v_match.deadline, now()),
      'questions', '[]'::jsonb,
      'answered', 0,
      'finished', true
    );
  end if;

  -- Sorular ilk açılışta BİR KEZ seçilir; ikinci oyuncu aynı sırayı alır.
  -- Süzgeç `start_async_duel` ile aynı (metin soru, eksiksiz şık, geçerli
  -- doğru şık, etkin kategori); konu turnuvanın dil konusudur
  -- (`TournamentConfig.tournamentCategory`). Bu kupanın önceki maçlarında
  -- çıkan sorular dışlanır: yarı finalde cevabı görülen soru finalde
  -- gelmesin (dış inceleme 2. tur).
  if v_ids is null then
    select coalesce(array_agg(x.qid), '{}'::uuid[]) into v_used
    from public.tournament_match_questions tq
    join public.tournament_matches m2 on m2.id = tq.match_id
    cross join lateral unnest(tq.question_ids) as x(qid)
    where m2.tournament_id = v_match.tournament_id;

    select public.weighted_question_pick(
      (select coalesce(array_agg(cand.id), '{}'::uuid[]) from (
        select q.id
        from public.questions q
        join public.categories c on c.id = q.category_id
        where q.is_approved = true
          and c.is_active = true
          and c.name = 'Ziman'
          and btrim(coalesce(q.prompt, '')) <> ''
          and q.image_url is null
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
      ) cand),
      v_used,
      v_count
    ) into v_ids;

    if coalesce(array_length(v_ids, 1), 0) < v_count then
      raise exception 'No questions';
    end if;

    insert into public.tournament_match_questions (match_id, question_ids)
    values (p_match_id, v_ids);
  end if;

  select e.display_name into v_other_name
  from public.tournament_entries e
  where e.tournament_id = v_match.tournament_id
    and e.player_id = v_other;

  -- İçerik yalnız bu oyuncuya SUNULMUŞ sorularda; ötekiler yer tutucu
  -- (istemci sunumda gelen içerikle değiştirir, yer tutucuyu göstermez).
  select coalesce(jsonb_agg(
    case
      when exists (
        select 1 from public.tournament_match_question_starts st
        where st.match_id = p_match_id
          and st.player_id = v_uid
          and st.question_index = ord.idx - 1
      )
      then (public.async_duel_questions_payload(array[ord.qid]) -> 0)
        || jsonb_build_object('index', ord.idx - 1)
      else jsonb_build_object(
        'index', ord.idx - 1,
        'id', 'pending-' || (ord.idx - 1),
        'category_name', 'Ziman',
        'prompt', '',
        'option_a', '',
        'option_b', '',
        'option_c', null,
        'option_d', null,
        'question_type', 'multiple_choice',
        'image_url', null,
        'difficulty', 2
      )
    end
    order by ord.idx
  ), '[]'::jsonb)
  into v_questions
  from unnest(v_ids) with ordinality as ord(qid, idx);

  -- Sırayla düellonun başlangıç yanıtıyla AYNI biçim (istemci aynı oyun
  -- ekranını kullanır): `duel_id` burada maçın kimliğidir.
  return jsonb_build_object(
    'duel_id', v_match.id,
    'role', case when v_uid = v_match.player_one then 'creator'
                 else 'opponent' end,
    'opponent_name', v_other_name,
    'opponent_id', v_other,
    'expires_at', coalesce(v_match.deadline, now() + interval '24 hours'),
    'questions', v_questions,
    'answered', v_answered,
    'finished', v_answered >= coalesce(array_length(v_ids, 1), 0)
      or v_match.status = 'completed'
  );
end;
$$;

-- ─── Soru sunumu (süre sunucuda bu andan ölçülür) ─────────────────────────
create or replace function public.present_tournament_question(
  p_match_id uuid,
  p_question_index integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.tournament_matches%rowtype;
  v_total integer;
  v_answered integer;
  v_started timestamptz;
  v_ids uuid[];
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_match
  from public.tournament_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_uid is distinct from v_match.player_one
     and v_uid is distinct from v_match.player_two then
    raise exception 'Not a match player';
  end if;

  if v_match.status = 'completed'
     or (v_match.deadline is not null
         and v_match.deadline <= clock_timestamp()) then
    raise exception 'Match expired';
  end if;

  select tq.question_ids into v_ids
  from public.tournament_match_questions tq
  where tq.match_id = p_match_id;

  v_total := coalesce(array_length(v_ids, 1), 0);
  select count(*)::integer into v_answered
  from public.tournament_match_answers a
  where a.match_id = p_match_id and a.player_id = v_uid;

  if p_question_index is null
     or p_question_index <> v_answered
     or p_question_index >= v_total then
    raise exception 'Invalid index';
  end if;

  insert into public.tournament_match_question_starts (
    match_id, player_id, question_index, started_at
  ) values (
    p_match_id, v_uid, p_question_index, clock_timestamp()
  )
  on conflict (match_id, player_id, question_index) do nothing;

  select st.started_at into v_started
  from public.tournament_match_question_starts st
  where st.match_id = p_match_id
    and st.player_id = v_uid
    and st.question_index = p_question_index;

  return jsonb_build_object(
    'started_at', v_started,
    'elapsed_ms', greatest(
      0,
      floor(extract(epoch from (clock_timestamp() - v_started)) * 1000)
    )::integer,
    'limit_ms', 20000,
    -- Sorunun içeriği YALNIZ burada (doğru şık yok).
    'question', (public.async_duel_questions_payload(
        array[v_ids[p_question_index + 1]]
      ) -> 0) || jsonb_build_object('index', p_question_index)
  );
end;
$$;

-- ─── Cevap (doğruluk, süre ve puan sunucuda) ──────────────────────────────
create or replace function public.answer_tournament_question(
  p_match_id uuid,
  p_question_index integer,
  p_choice text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.tournament_matches%rowtype;
  v_other uuid;
  v_is_one boolean;
  v_total integer;
  v_prior integer;
  v_question_id uuid;
  v_correct_option text;
  v_is_correct boolean;
  v_started_at timestamptz;
  v_elapsed_ms integer;
  -- İstemcideki soru süresi (async_duel_play_screen `_questionSeconds`).
  v_max_ms constant integer := 20000;
  v_response_ms integer;
  v_points integer;
  v_answered integer;
  v_finished boolean := false;
  v_my_score integer;
  v_my_ms integer;
  v_my_correct integer;
  v_opp_score integer;
  v_opp_ms integer;
  v_opp_correct integer;
  v_opp_done boolean := false;
  v_winner uuid;
  v_result jsonb := null;
  v_ids uuid[];
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_match
  from public.tournament_matches
  where id = p_match_id
  for update;

  if not found then
    raise exception 'Match not found';
  end if;

  if v_uid = v_match.player_one then
    v_other := v_match.player_two;
    v_is_one := true;
  elsif v_uid = v_match.player_two then
    v_other := v_match.player_one;
    v_is_one := false;
  else
    raise exception 'Not a match player';
  end if;

  select tq.question_ids into v_ids
  from public.tournament_match_questions tq
  where tq.match_id = p_match_id;

  v_total := coalesce(array_length(v_ids, 1), 0);
  if p_question_index is null
     or p_question_index < 0
     or p_question_index >= v_total then
    raise exception 'Invalid index';
  end if;

  -- Aynı soruya yeniden gönderim (ağ kopması) 'Already answered' alır;
  -- istemci bunu "ulaşmıştı" diye okur. Bu kontrol süre dolumundan ÖNCE:
  -- son cevabın yanıtı kaybolup maç o arada bittiyse de doğru sonuç döner.
  if exists (
    select 1 from public.tournament_match_answers a
    where a.match_id = p_match_id
      and a.player_id = v_uid
      and a.question_index = p_question_index
  ) then
    raise exception 'Already answered';
  end if;

  if v_match.status = 'completed'
     or (v_match.deadline is not null
         and v_match.deadline <= clock_timestamp()) then
    raise exception 'Match expired';
  end if;

  select count(*)::integer into v_prior
  from public.tournament_match_answers a
  where a.match_id = p_match_id and a.player_id = v_uid;

  if p_question_index <> v_prior then
    raise exception 'Invalid index';
  end if;

  if p_choice is null or p_choice not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid choice';
  end if;

  v_question_id := v_ids[p_question_index + 1];
  select q.correct_option into v_correct_option
  from public.questions q
  where q.id = v_question_id;

  v_is_correct := coalesce(v_correct_option = p_choice, false);

  -- SÜRE SUNUCUDA: sunum kaydından bu yana. Sunulmamış soruya yalnız
  -- "süre doldu" gönderilebilir (yarıda çıkış; 0 puan): içeriği görmeden
  -- cevap verilemez, sunumu atlamak süre sınırını aşmanın yolu olmasın.
  select st.started_at into v_started_at
  from public.tournament_match_question_starts st
  where st.match_id = p_match_id
    and st.player_id = v_uid
    and st.question_index = p_question_index;

  if found then
    v_elapsed_ms := greatest(
      0,
      floor(extract(epoch from (clock_timestamp() - v_started_at)) * 1000)
    )::integer;
    if v_elapsed_ms > v_max_ms + 5000 then
      v_is_correct := false;
    end if;
    v_response_ms := least(v_elapsed_ms, v_max_ms);
  elsif p_choice = 'TIMEOUT' then
    v_response_ms := v_max_ms;
  else
    raise exception 'Not presented';
  end if;

  if p_choice = 'TIMEOUT' then
    v_response_ms := v_max_ms;
  end if;

  v_points := case
    when v_is_correct
      then 100 + floor(50.0 * (v_max_ms - v_response_ms) / v_max_ms)::integer
    else 0
  end;

  insert into public.tournament_match_answers (
    match_id, player_id, question_index, choice, is_correct, response_ms,
    points
  ) values (
    p_match_id, v_uid, p_question_index, p_choice, v_is_correct,
    v_response_ms, v_points
  );

  v_answered := v_prior + 1;

  if v_answered >= v_total then
    v_finished := true;

    select coalesce(sum(points), 0)::integer,
           coalesce(sum(response_ms), 0)::integer,
           (count(*) filter (where is_correct))::integer
      into v_my_score, v_my_ms, v_my_correct
    from public.tournament_match_answers
    where match_id = p_match_id and player_id = v_uid;

    if v_is_one then
      update public.tournament_matches
         set score_one = v_my_score, submitted_one = clock_timestamp()
       where id = p_match_id and submitted_one is null;
    else
      update public.tournament_matches
         set score_two = v_my_score, submitted_two = clock_timestamp()
       where id = p_match_id and submitted_two is null;
    end if;

    select * into v_match
    from public.tournament_matches
    where id = p_match_id;

    v_opp_done := v_match.submitted_one is not null
      and v_match.submitted_two is not null;

    if v_opp_done then
      select coalesce(sum(points), 0)::integer,
             coalesce(sum(response_ms), 0)::integer,
             (count(*) filter (where is_correct))::integer
        into v_opp_score, v_opp_ms, v_opp_correct
      from public.tournament_match_answers
      where match_id = p_match_id and player_id = v_other;

      v_winner := case
        when v_my_score > v_opp_score then v_uid
        when v_my_score < v_opp_score then v_other
        when v_my_ms < v_opp_ms then v_uid
        when v_my_ms > v_opp_ms then v_other
        when (case when v_is_one then v_match.submitted_one
                   else v_match.submitted_two end)
             <= (case when v_is_one then v_match.submitted_two
                      else v_match.submitted_one end)
          then v_uid
        else v_other
      end;

      update public.tournament_matches
         set status = 'completed', winner_id = v_winner
       where id = p_match_id and status <> 'completed';

      perform public.advance_tournament(v_match.tournament_id);

      v_result := jsonb_build_object(
        'status', 'completed',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'my_score', v_my_score,
        'opponent_correct', v_opp_correct,
        'opponent_ms', v_opp_ms,
        'opponent_score', v_opp_score,
        'outcome', case when v_winner = v_uid then 'win' else 'loss' end
      );
    else
      v_result := jsonb_build_object(
        'status', 'waiting',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'my_score', v_my_score,
        'opponent_correct', null,
        'opponent_ms', null,
        'opponent_score', null,
        'outcome', null
      );
    end if;
  end if;

  return jsonb_build_object(
    'correct', v_is_correct,
    'correct_option', coalesce(v_correct_option, 'A'),
    'points', v_points,
    'answered', v_answered,
    'total', v_total,
    'finished', v_finished,
    'result', v_result
  );
end;
$$;

-- ─── Eski istemci: sunucu puanlı kupada istemci skoru yazılmaz ────────────
create or replace function public.submit_tournament_match(
  p_match_id uuid,
  p_score integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_match public.tournament_matches;
  v_winner uuid;
  v_score int := greatest(coalesce(p_score, 0), 0);
  v_max_score int;
  v_server_scored boolean;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  select * into v_match from public.tournament_matches
   where id = p_match_id for update;
  if not found then
    raise exception 'Match not found';
  end if;
  if v_user not in (coalesce(v_match.player_one, '00000000-0000-0000-0000-000000000000'::uuid),
                    coalesce(v_match.player_two, '00000000-0000-0000-0000-000000000000'::uuid)) then
    raise exception 'Player is not in this match';
  end if;
  if v_match.status = 'completed' then
    return jsonb_build_object('status', 'completed',
                              'winner_id', v_match.winner_id);
  end if;

  -- 2026-10-27: sunucu puanlı kupada skoru `answer_tournament_question`
  -- yazar; istemcinin bildirdiği sayı YAZILMAZ. Eski istemci bu hatayla
  -- "skor gönderilemedi" uyarısını gösterir (sessizce hükmen kaybetmez).
  select coalesce(t.scores_server_validated, false)
    into v_server_scored
    from public.tournaments t
   where t.id = v_match.tournament_id;
  if v_server_scored then
    raise exception 'Update required';
  end if;

  -- Skor tavanı: oyunun puanlamasının izin verdiği en yüksek değer.
  -- Soru başına 150 (100 taban + 50 seri bonusu tavanı).
  select coalesce(t.questions_per_match, 4) * 150
    into v_max_score
    from public.tournaments t
   where t.id = v_match.tournament_id;

  v_score := least(v_score, coalesce(v_max_score, 600));

  -- Skor tek sefer kabul edilir: ikinci gönderim sessizce yok sayılır,
  -- yoksa oyuncu turu tekrar oynayıp skorunu yükseltebilirdi.
  if v_user = v_match.player_one and v_match.submitted_one is null then
    update public.tournament_matches
       set score_one = v_score, submitted_one = now()
     where id = p_match_id;
  elsif v_user = v_match.player_two and v_match.submitted_two is null then
    update public.tournament_matches
       set score_two = v_score, submitted_two = now()
     where id = p_match_id;
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;

  if v_match.submitted_one is not null and v_match.submitted_two is not null
  then
    -- Eşitlikte daha erken bitiren geçer: aynı skoru önce tamamlamak
    -- ölçülebilir bir üstünlüktür ve yazı-tura atmaktan yeğdir.
    if coalesce(v_match.score_one, 0) > coalesce(v_match.score_two, 0) then
      v_winner := v_match.player_one;
    elsif coalesce(v_match.score_two, 0) > coalesce(v_match.score_one, 0) then
      v_winner := v_match.player_two;
    elsif v_match.submitted_one <= v_match.submitted_two then
      v_winner := v_match.player_one;
    else
      v_winner := v_match.player_two;
    end if;

    update public.tournament_matches
       set status = 'completed', winner_id = v_winner
     where id = p_match_id;

    perform public.advance_tournament(v_match.tournament_id);
  end if;

  select * into v_match from public.tournament_matches where id = p_match_id;
  return jsonb_build_object('status', v_match.status,
                            'winner_id', v_match.winner_id);
end;
$$;

-- Tur ilerletmesi kupa kilidiyle (gövde canlıdan; tek fark kilit satırı).
CREATE OR REPLACE FUNCTION public.advance_tournament(p_tournament_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_round int;
  v_pending int;
  v_winners uuid[];
  v_i int;
  v_slot int := 0;
  v_hours int;
begin
  -- 2026-10-27: kupa satırı kilitlenir. İki yarı final aynı anda bitince
  -- her işlem ötekinin maçını henüz bitmemiş görüp dönüyor, final hiç
  -- kurulmuyordu; kilitle ikinci işlem birincinin sonucunu görür ve finali
  -- bir kez kurar.
  perform 1 from public.tournaments where id = p_tournament_id for update;

  -- Bitmiş turnuva değiştirilmez (şampiyon ve finished_at sabit kalır).
  if exists (
    select 1 from public.tournaments
    where id = p_tournament_id and status = 'finished'
  ) then
    return;
  end if;

  select round_hours into v_hours from public.tournaments
   where id = p_tournament_id;

  select max(round) into v_round from public.tournament_matches
   where tournament_id = p_tournament_id;
  if v_round is null then return; end if;

  select count(*) into v_pending from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and status <> 'completed';
  if v_pending > 0 then return; end if;

  select array_agg(winner_id order by slot) into v_winners
    from public.tournament_matches
   where tournament_id = p_tournament_id
     and round = v_round
     and winner_id is not null;

  if v_winners is null or array_length(v_winners, 1) <= 1 then
    update public.tournaments
       set status = 'finished',
           finished_at = now(),
           champion_id = case
             when v_winners is null then null else v_winners[1] end
     where id = p_tournament_id;
    return;
  end if;

  v_i := 1;
  while v_i <= array_length(v_winners, 1) loop
    insert into public.tournament_matches (
      tournament_id, round, slot, player_one, player_two, deadline
    ) values (
      p_tournament_id, v_round + 1, v_slot,
      v_winners[v_i], v_winners[v_i + 1],
      now() + make_interval(hours => coalesce(v_hours, 24))
    );
    v_slot := v_slot + 1;
    v_i := v_i + 2;
  end loop;

  update public.tournament_matches
     set status = 'completed', winner_id = player_one
   where tournament_id = p_tournament_id
     and round = v_round + 1
     and player_two is null;
end;
$function$;

-- Şema yanıtına sunucu puanı bayrağı (gövde canlıdan; tek fark son alan).
CREATE OR REPLACE FUNCTION public.get_tournament_bracket()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_user uuid := auth.uid();
  v_tournament public.tournaments;
  v_rounds jsonb;
  v_current_round int;
  v_max_round int;
  v_eliminated boolean;
  v_status text;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  -- Ekran her açıldığında zamanı gelmiş işler yürütülür: süresi dolan
  -- maçlar hükmen kapanır, dolmayı bekleyen turnuvalar eldeki oyuncularla
  -- başlar. Ayrı bir zamanlayıcı gerekmez.
  perform public.resolve_expired_tournament_matches();
  perform public.start_due_tournaments();

  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
   order by t.opened_at desc
   limit 1;

  if not found then
    return null;
  end if;

  select jsonb_agg(r order by r_round)
    into v_rounds
    from (
      select m.round as r_round,
             jsonb_build_object(
               'round', m.round,
               'matches', jsonb_agg(
                 jsonb_build_object(
                   'id', m.id,
                   'playerOneId', coalesce(m.player_one::text, ''),
                   'playerOneName', coalesce(e1.display_name, '—'),
                   'playerTwoId', coalesce(m.player_two::text, ''),
                   'playerTwoName', coalesce(e2.display_name, '—'),
                   'playerOneScore', coalesce(m.score_one, 0),
                   'playerTwoScore', coalesce(m.score_two, 0),
                   'status', m.status,
                   'winnerId', coalesce(m.winner_id::text, ''),
                   'deadline', m.deadline
                 ) order by m.slot
               )
             ) as r
        from public.tournament_matches m
        left join public.tournament_entries e1
               on e1.tournament_id = m.tournament_id
              and e1.player_id = m.player_one
        left join public.tournament_entries e2
               on e2.tournament_id = m.tournament_id
              and e2.player_id = m.player_two
       where m.tournament_id = v_tournament.id
       group by m.round
    ) rounds;

  -- `currentRound` istemcinin "benim maçım hangi turda" sorusunu yanıtlar
  -- ve tur adını (Son 16 / Çeyrek / Yarı / Final) seçer. Gönderilmezse 0'a
  -- düşer: ikinci turdaki oyuncu birinci turda aranır, maçı hiç bulunamaz
  -- ve ekran yanlış tur adını yazar. Sıfır tabanlıdır — istemci onu dizin
  -- olarak kullanır.
  select min(m.round) - 1
    into v_current_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id
     and m.status <> 'completed'
     and v_user in (m.player_one, m.player_two);

  select max(m.round) into v_max_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id;

  -- Açık maçı yoksa: ya elendi ya da kupa bitti. Elenmeyi turnuvanın
  -- bitmesine bağlamak yanlıştı — birinci turda kaybeden oyuncu, kupa
  -- sürerken hâlâ "maçın var" görüyordu.
  v_eliminated := v_current_round is null and exists (
    select 1 from public.tournament_matches m
     where m.tournament_id = v_tournament.id
       and m.status = 'completed'
       and v_user in (m.player_one, m.player_two)
       and coalesce(m.winner_id, '00000000-0000-0000-0000-000000000000'::uuid)
           <> v_user
  );

  if v_tournament.champion_id = v_user then
    v_status := 'won';
  elsif v_eliminated then
    v_status := 'eliminated';
  elsif v_tournament.status = 'finished' then
    v_status := 'eliminated';
  else
    v_status := 'active';
  end if;

  return jsonb_build_object(
    'tournamentId', v_tournament.id,
    'userId', v_user,
    'currentRound', coalesce(v_current_round,
                             greatest(coalesce(v_max_round, 1) - 1, 0)),
    'status', v_status,
    'createdAt', v_tournament.opened_at,
    'completedAt', v_tournament.finished_at,
    'rounds', coalesce(v_rounds, '[]'::jsonb),
    -- 2026-10-27: bekleme ekranı "1/4 oyuncu katıldı" diyebilsin. Yalnız
    -- sayı; kimin beklediği (ad) açık turnuvada paylaşılmaz.
    'entryCount', (select count(*) from public.tournament_entries e
                    where e.tournament_id = v_tournament.id),
    'size', v_tournament.size,
    -- 2026-10-27: maç sunucuda puanlanıyor mu (istemci oyun yolunu seçer).
    'serverScored', coalesce(v_tournament.scores_server_validated, false)
  );
end;
$function$;

-- Şampiyon ödülü (2026-10-27 yeniden yazım):
--   * yalnız sunucu puanlı kupada ve kupada en az bir SUNULMUŞ soruyu
--     cevaplamış şampiyona (hiç görmeden "süre doldu" göndermek ya da bay
--     geçip rakibin gelmemesi ödül getirmez — dış inceleme 2. ve 3. tur);
--   * ödenmiş kupa için `already_claimed: true` ve ödenen miktar döner:
--     eski gövdede ikinci açılış `already_claimed: false, amount: 0` alıyor,
--     ekran şampiyona "Ödül henüz doğrulanmadı" yazıyordu (3. tur).
create or replace function public.claim_tournament_reward()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_tournament uuid;
  v_reason text;
  v_paid integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  -- Uygun ve henüz ödenmemiş en son şampiyonluk.
  select t.id into v_tournament
  from public.tournaments t
  where t.status = 'finished'
    and t.champion_id = v_uid
    and t.scores_server_validated
    and exists (
      select 1
      from public.tournament_match_answers a
      join public.tournament_matches m on m.id = a.match_id
      join public.tournament_match_question_starts st
        on st.match_id = a.match_id
       and st.player_id = a.player_id
       and st.question_index = a.question_index
      where m.tournament_id = t.id
        and a.player_id = v_uid
    )
    and not exists (
      select 1
      from public.coin_transactions ct
      where ct.player_id = v_uid
        and ct.reason = 'tournament_champion:' || t.id::text
    )
  order by t.finished_at desc
  limit 1;

  if v_tournament is null then
    -- Ödenecek yok: EN SON şampiyonluk zaten ödendiyse bunu söyle. Önce en
    -- son kupa seçilir, sonra yalnız onun ödemesine bakılır; geçmişte
    -- ödenmiş başka bir kupa yeni (ödülsüz) şampiyonluğu "ödendi"
    -- göstermesin (dış inceleme 4. tur).
    select ct.amount into v_paid
    from (
      select t.id
      from public.tournaments t
      where t.status = 'finished'
        and t.champion_id = v_uid
      order by t.finished_at desc
      limit 1
    ) latest_t
    join public.coin_transactions ct
      on ct.player_id = v_uid
     and ct.reason = 'tournament_champion:' || latest_t.id::text;

    if v_paid is not null then
      return jsonb_build_object(
        'amount', 0,
        'already_claimed', true,
        'paid_amount', v_paid
      );
    end if;
    return jsonb_build_object('amount', 0, 'already_claimed', false);
  end if;

  v_reason := 'tournament_champion:' || v_tournament::text;
  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, 200, v_reason);

  return jsonb_build_object('amount', 200, 'already_claimed', false);
end;
$$;

-- İç işler istemciye kapalı (canlıda zaten öyle; açıkça yazılır).
revoke execute on function public.start_tournament(uuid) from public, anon, authenticated;
revoke execute on function public.advance_tournament(uuid) from public, anon, authenticated;

revoke execute on function public.start_tournament_match(uuid)
  from public, anon;
revoke execute on function public.present_tournament_question(uuid, integer)
  from public, anon;
revoke execute on function public.answer_tournament_question(uuid, integer, text)
  from public, anon;
grant execute on function public.start_tournament_match(uuid) to authenticated;
grant execute on function public.present_tournament_question(uuid, integer)
  to authenticated;
grant execute on function public.answer_tournament_question(uuid, integer, text)
  to authenticated;

commit;
