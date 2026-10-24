-- GERİ ALMA: 2026-10-24_duello_inceleme_rovans.sql
--
-- create_async_duel_challenge'ın göç ÖNCESİ CANLI gövdesini (2026-10-24,
-- `pg_get_functiondef` çıktısı, arkadaş olmayana rövanş istisnası YOK,
-- search_path yalnız 'public') geri yükler; get_async_duel_review ve
-- async_duel_recent_pair'i düşürür. Sonra istemci inceleme bölümünü ve
-- rövanş düğmesini gizler (RPC yok => null), arkadaş olmayana davet
-- 'Not a friend' olur.
--   supabase db query --linked -f supabase/geri_al/2026-10-24_duello_inceleme_rovans_geri.sql
begin;

create or replace function public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
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
    if p_friend_id = v_uid
       or not exists (
         select 1 from public.friends f
         where f.user_id = v_uid and f.friend_id = p_friend_id
       )
       or exists (
         select 1 from public.blocked_users b
         where (b.blocker_id = v_uid and b.blocked_id = p_friend_id)
            or (b.blocker_id = p_friend_id and b.blocked_id = v_uid)
       ) then
      raise exception 'Not a friend';
    end if;

    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = p_friend_id;
  end if;

  -- start_async_duel ile AYNI advisory kilit: ikisinin açık-düello sayımı
  -- aynı oyuncu için sıraya girer (çift dokunuş / iki RPC yarışı 5 sınırını
  -- aşamasın).
  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

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
$function$;

revoke all on function public.create_async_duel_challenge(text, uuid)
  from public, anon;
grant execute on function public.create_async_duel_challenge(text, uuid)
  to authenticated;

drop function if exists public.get_async_duel_review(uuid);
drop function if exists public.async_duel_recent_pair(uuid, uuid);

commit;
