-- 2026-10-24: DÜELLO İNCELEME + RÖVANŞ — `get_async_duel_review(p_duel_id)`.
--
-- Ürün sahibi onaylı QuizClash / Trivia Crack düzeni: biten bir düelloda
-- oyuncu 7 sorunun her birini yan yana görür — soru, doğru cevap, benim
-- cevabım (✓/✗, süre) ve rakibin cevabı (✓/✗, süre). Sonuç ekranındaki
-- "Rövanş" düğmesi aynı rakibe arkadaş meydan okuması açar
-- (`create_async_duel_challenge`, DEĞİŞMEZ); düğmenin açık olup olmadığını
-- bu RPC'nin `can_rematch` alanı söyler.
--
-- NEDEN SUNUCU: `async_duel_answers` / `async_duels` istemciye tamamen
-- kapalı (RLS + REVOKE); `questions.correct_option` ham dönmez. Bu RPC yeni
-- bir SELECT yolu açar, bu yüzden üç kapı vardır:
--   1) KATILIMCI: yalnız yaratıcı ya da eşleşmiş rakip ('Not a duel player').
--      Kabul edilmemiş davetli ya da yabancı okuyamaz.
--   2) BİTMİŞ: yalnız status 'completed' / 'expired' ('Duel not finished').
--      Süren düelloda rakibin cevapları ve doğru şıklar ASLA dönmez — oyuncu
--      rakibin cevabından ya da doğru şıktan kopya çekemez (oyun içi gizli
--      cevap ilkesi: bkz. 2026-09-28_async_duels.sql başlığı).
--   3) ENGEL: aramızda iki yönde engel varsa rakibin adı, kimliği VE
--      cevapları dönmez (`opponent_blocked` true); kendi incelemem yine
--      açılır. Engelli rakip için rövanş kapalıdır.
--
-- `can_rematch`: rakip var (profil silinmemiş), engel yok VE (rakip kabul
-- edilmiş arkadaşım YA DA son 7 günde birlikte bitmiş bir düello oynadık).
-- Rastgele rakiple de rövanş olsun diye `create_async_duel_challenge` aynı
-- istisnayı tanır (koordinatör kararı 2026-10-24): CANLI gövde
-- `pg_get_functiondef` ile okunup kopyalandı; değişen yalnız (1) arkadaş
-- olmayan davetlide `async_duel_recent_pair` istisnası, (2) o yolda aynı
-- kişiye 24 saatte en çok 3 davet ('Too many invites'), (3) search_path'e
-- 'pg_temp'. Engel, açık düello sınırı (5), soru seçimi aynen.
-- (Sunucuda bot rakibi yoktur: sırayla düello yalnız gerçek profillerle
-- eşleşir; "bot/bilinmeyen" = rakip kimliği boş.)
--
-- Yanıt:
--   { duel_id, status, forfeit, opponent_id, opponent_name,
--     opponent_blocked, opponent_is_friend, can_rematch,
--     questions: [ { index, prompt, option_a..option_d, question_type,
--                    correct_option,
--                    my:  { choice, correct, ms } | null,
--                    opp: { choice, correct, ms } | null } ... ] }
--   `choice`: 'A'..'D' ya da 'TIMEOUT' (süre doldu, her zaman yanlış).
--   `my`/`opp` null = o soruyu hiç cevaplamadı (hükmen kaybeden) ya da
--   (opp için) engel nedeniyle gizli.
--
-- Hata metinleri: 'Not authenticated', 'Duel not found', 'Not a duel
-- player', 'Duel not finished'.
--
-- Yeni fonksiyon (mevcut gövdelere dokunulmaz): canlı gövde kopyalamaya gerek
-- yok. İdempotent. Uygulama:
--   supabase db query --linked -f supabase/2026-10-24_duello_inceleme_rovans.sql
-- Kanıt (göçten önce ve sonra, kalıcı yazmaz):
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_inceleme_rovans_kanit.sql
-- Geri alma: `drop function public.get_async_duel_review(uuid);` (istemci
-- RPC yoksa bölümü gizler; başka hiçbir şey bağlı değil).

begin;

-- Ortak ölçüt: iki oyuncu son 7 günde birlikte BİTMİŞ (completed/expired,
-- hükmen dahil) bir düello oynadı mı? Rakibi olmayan (opponent_id boş) düello
-- sayılmaz: düelloya girmiş iki taraf gerekir. İstemciye KAPALI yardımcı.
create or replace function public.async_duel_recent_pair(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  select exists (
    select 1 from public.async_duels d
    where d.status in ('completed', 'expired')
      and d.opponent_id is not null
      and ((d.creator_id = p_a and d.opponent_id = p_b)
        or (d.creator_id = p_b and d.opponent_id = p_a))
      and coalesce(d.completed_at, d.expires_at) >= now() - interval '7 days'
  );
$function$;

revoke all on function public.async_duel_recent_pair(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_category_input text;
  v_category_id uuid;
  v_open_count integer;
  v_question_ids uuid[];
  v_question_count integer;
  v_invited_name text := null;
  v_duel_id uuid;
  v_expires_at timestamptz;
  v_code text;
  v_attempt integer := 0;
  v_non_friend boolean := false;     -- 2026-10-24: son 7 günde birlikte oynadığımız arkadaş olmayan
  v_recent_invites integer;
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

  -- Davet edilecek kişi: KABUL EDİLMİŞ arkadaş (friends tablosunda iki
  -- satır tutulur, benim satırım yeter) ve iki yönde de engelsiz. Engel,
  -- 2026-10-02_blocking_enforcement.sql ile aynı ilkeyle ifşa edilmez:
  -- engelli de arkadaş değil gibi 'Not a friend' alır.
  if p_friend_id is not null then
    -- Engel (iki yön) HER ZAMAN 'Not a friend' (ifşa edilmez).
    if p_friend_id = v_uid
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = p_friend_id)
            or (b.blocker_id = p_friend_id and b.blocked_id = v_uid)
       ) then
      raise exception 'Not a friend';
    end if;

    -- 2026-10-24 rövanş istisnası: arkadaş değilse bile, son 7 günde ikimiz
    -- birlikte BİTMİŞ (completed / expired, hükmen dahil) bir düello
    -- oynadıysak davet geçer. Aksi 'Not a friend'. Günlük sınır kilitten
    -- sonra denetlenir (aşağıda).
    if not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = p_friend_id
       ) then
      if not public.async_duel_recent_pair(v_uid, p_friend_id) then
        raise exception 'Not a friend';
      end if;
      v_non_friend := true;
    end if;

    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = p_friend_id;
  end if;

  -- start_async_duel ile AYNI advisory kilit: ikisinin açık-düello sayımı
  -- aynı oyuncu için sıraya girer (çift dokunuş / iki RPC yarışı 5 sınırını
  -- aşamasın).
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Sahte "geçmiş düello" ile spam olmasın: arkadaş olmayan aynı kişiye
  -- son 24 saatte en çok 3 davet (arkadaşlar için yeni sınır YOK).
  if v_non_friend then
    select count(*) into v_recent_invites
    from public.async_duels d
    where d.creator_id = v_uid
      and d.invited_id = p_friend_id
      and d.created_at > now() - interval '24 hours';
    if v_recent_invites >= 3 then
      raise exception 'Too many invites';
    end if;
  end if;

  -- Süresi dolmuş ama henüz süpürülmemiş düellolar sayılmaz (2026-10-15).
  select count(*) into v_open_count
  from public.async_duels
  where creator_id = v_uid
    and status = 'open'
    and expires_at > now();

  if v_open_count >= 5 then
    raise exception 'Too many open duels';
  end if;

  -- Soru seçimi start_async_duel'inkiyle BİREBİR aynı süzgeç (gerekçe orada:
  -- 2026-09-28_async_duels.sql). `rnd` bir kez hesaplanır; sıra =
  -- array_agg sırası = istemcideki index 0..6.
  select public.weighted_question_pick(
    (select array_agg(cand.id) from (
    select q.id
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
    ) cand),
    '{}'::uuid[],
    7
  ) into v_question_ids;

  v_question_count := coalesce(array_length(v_question_ids, 1), 0);
  if v_question_count < 7 then
    raise exception 'No questions';
  end if;

  -- Kod çakışması (UNIQUE) 31^8'de pratikte yok; yine de birkaç kez dener.
  loop
    v_attempt := v_attempt + 1;
    v_code := public.generate_async_duel_challenge_code();
    begin
      insert into public.async_duels (
        category_id, question_ids, creator_id, invited_id, challenge_code, status
      ) values (
        v_category_id, v_question_ids, v_uid, p_friend_id, v_code, 'open'
      )
      returning id, expires_at into v_duel_id, v_expires_at;
      exit;
    exception
      when unique_violation then
        if v_attempt >= 8 then
          raise;
        end if;
    end;
  end loop;

  return jsonb_build_object(
    'duel_id', v_duel_id,
    'role', 'creator',
    'opponent_name', null,
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_question_ids),
    'challenge_code', v_code,
    'invited_name', v_invited_name,
    'invited_id', case when v_invited_name is not null then p_friend_id
                       else null end
  );
end;
$function$
;

revoke all on function public.create_async_duel_challenge(text, uuid)
  from public, anon;
grant execute on function public.create_async_duel_challenge(text, uuid)
  to authenticated;

create or replace function public.get_async_duel_review(p_duel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other uuid;
  v_blocked boolean := false;
  v_friend boolean := false;
  v_recent boolean := false;
  v_other_name text := null;
  v_show_other uuid := null;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select d.* into v_duel
  from public.async_duels d
  where d.id = p_duel_id;

  if not found then
    raise exception 'Duel not found';
  end if;

  -- Kapı 1: yalnız düelloyu oynayan iki taraf.
  if v_uid is distinct from v_duel.creator_id
     and v_uid is distinct from v_duel.opponent_id then
    raise exception 'Not a duel player';
  end if;

  -- Kapı 2: yalnız bitmiş düello. Süresi geçmiş ama henüz süpürülmemiş
  -- ('matched' kalmış) düello da BİTMİŞ sayılmaz: süpürme (10 dk) sonucu ve
  -- hükmeni kesinleştirir, ondan önce hiçbir cevap açılmaz.
  if v_duel.status not in ('completed', 'expired') then
    raise exception 'Duel not finished';
  end if;

  v_other := case
    when v_duel.creator_id = v_uid then v_duel.opponent_id
    else v_duel.creator_id
  end;

  if v_other is not null then
    -- Kapı 3: iki yönlü engel.
    select exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = v_other)
         or (b.blocker_id = v_other and b.blocked_id = v_uid)
    ) into v_blocked;

    if not v_blocked then
      v_show_other := v_other;
      select p.display_name into v_other_name
      from public.profiles p
      where p.id = v_other;

      select exists (
        select 1 from public.friends f
        where f.user_id = v_uid and f.friend_id = v_other
      ) into v_friend;

      v_recent := public.async_duel_recent_pair(v_uid, v_other);
    end if;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'index', o.idx - 1,
      'prompt', q.prompt,
      'option_a', q.option_a,
      'option_b', q.option_b,
      'option_c', q.option_c,
      'option_d', q.option_d,
      'question_type', q.question_type,
      'correct_option', q.correct_option,
      'my', case
        when mine.duel_id is null then null
        else jsonb_build_object(
          'choice', mine.choice,
          'correct', mine.is_correct,
          'ms', mine.response_ms
        )
      end,
      'opp', case
        when theirs.duel_id is null then null
        else jsonb_build_object(
          'choice', theirs.choice,
          'correct', theirs.is_correct,
          'ms', theirs.response_ms
        )
      end
    ) order by o.idx
  ), '[]'::jsonb)
  into v_questions
  from unnest(v_duel.question_ids) with ordinality as o(question_id, idx)
  join public.questions q on q.id = o.question_id
  left join public.async_duel_answers mine
    on mine.duel_id = v_duel.id
    and mine.player_id = v_uid
    and mine.question_index = o.idx - 1
  -- v_show_other engelde / rakipsizlikte NULL: eşleşme olmaz, cevaplar gizli.
  left join public.async_duel_answers theirs
    on theirs.duel_id = v_duel.id
    and theirs.player_id = v_show_other
    and theirs.question_index = o.idx - 1;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'status', v_duel.status,
    'forfeit', (v_duel.forfeit_loser_id is not null),
    'opponent_id', v_show_other,
    'opponent_name', v_other_name,
    'opponent_blocked', v_blocked,
    'opponent_is_friend', v_friend,
    'can_rematch', (v_show_other is not null and (v_friend or v_recent)),
    'questions', v_questions
  );
end;
$function$;

revoke all on function public.get_async_duel_review(uuid)
  from public, anon;
grant execute on function public.get_async_duel_review(uuid)
  to authenticated;

commit;
