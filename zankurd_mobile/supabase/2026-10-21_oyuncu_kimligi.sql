-- Sırayla düello: rakip ve davetli kimliği (2026-10-21).
--
-- Neden: kullanıcı "biriyle oynuyorsam her yerde onun adı ve fotoğrafı
-- görünsün" dedi. Gelen kutusu, düello kartı ve düello sonucu rakibi YALNIZ
-- ad olarak (`opponent_name`/`invited_name`) alıyordu; adı olmayan profilde
-- "Oyuncu" kalıyor, fotoğraf ve oyuncu kodu hiç gelmiyordu. Rakibin kimliği
-- (id) olmadan istemci `get_public_profiles` ile profili tamamlayamaz.
--
-- Ne değişir: beş düello RPC'sinin JSON yanıtına İKİ ALAN eklenir —
-- `opponent_id` ve `invited_id` (uuid | null). Başka hiçbir şey değişmez:
-- gövdeler 2026-10-21'de CANLI `pg_get_functiondef` çıktısından alındı ve
-- yalnız bu alanlar eklendi (imza, güvenlik, arama yolu, engel/süre/sayım
-- kuralları aynen). Eski istemciler bilmediği alanı yok sayar; yeni istemci
-- alan yoksa eski davranışa (baş harf, yer tutucu ad) düşer, yani SQL
-- uygulanmadan da çalışır.
--   list_my_async_duels          -> opponent_id, invited_id (yaratıcıysam)
--   resume_my_async_duel         -> opponent_id, invited_id (yaratıcıysam)
--   accept_async_duel_challenge  -> opponent_id (= yaratıcı), iki dönüşte
--   start_async_duel             -> opponent_id (rakip rolünde yaratıcı)
--   create_async_duel_challenge  -> invited_id (arkadaş seçildiyse)
-- Açığa çıkan veri: düelloda zaten karşılaştığın oyuncunun kimliği. Ad ve
-- fotoğraf ise zaten herkese açık `get_public_profiles` ile okunuyor.
--
-- ÖNCE DRY-RUN: aşağıdaki ilk blok ROLLBACK ile biter, kalıcı bir şey
-- yazmaz; fonksiyonlar derlenir ve alanların eklendiği doğrulanır. Temizse
-- ikinci bloğu çalıştır:
--   supabase db query --linked -f supabase/2026-10-21_oyuncu_kimligi.sql
-- (dosyanın tamamı iki blok da çalışır: önce dry-run geri alınır, sonra
-- uygulanır; yalnız dry-run için dosyayı 2. bloktan önce kesin.)

-- ===== 1) DRY-RUN (ROLLBACK) =====
begin;

CREATE OR REPLACE FUNCTION public.list_my_async_duels()
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select jsonb_build_object(
    'duel_id', d.id,
    'status', d.status,
    'role', case when d.creator_id = v_uid then 'creator' else 'opponent' end,
    'opponent_name', opponent_profile.display_name,
    'opponent_id', opponent_profile.id,
    'category_name', cat.name,
    'my_correct', mine.correct_count,
    'opponent_correct', case
      when mine.duel_id is not null then theirs.correct_count
      else null
    end,
    'outcome', case
      when mine.duel_id is not null and theirs.duel_id is not null then
        case
          when mine.correct_count > theirs.correct_count then 'win'
          when mine.correct_count < theirs.correct_count then 'loss'
          when mine.total_ms < theirs.total_ms then 'win'
          when mine.total_ms > theirs.total_ms then 'loss'
          else 'draw'
        end
      else null
    end,
    'created_at', d.created_at,
    'completed_at', d.completed_at,
    'seen', (mine.duel_id is null or mine.seen_at is not null),
    'challenge_code', case
      when d.challenge_code is not null
           and (
             d.creator_id = v_uid
             or (d.invited_id = v_uid and d.opponent_id is null)
           )
        then d.challenge_code
      else null
    end,
    'incoming_challenge', (
      d.creator_id <> v_uid
      and d.invited_id = v_uid
      and d.opponent_id is null
    ),
    'invited_name', case
      when d.creator_id = v_uid then invited_profile.display_name
      else null
    end,
    'invited_id', case
      when d.creator_id = v_uid then d.invited_id
      else null
    end
  )
  from public.async_duels d
  left join public.categories cat
    on cat.id = d.category_id
  left join public.async_duel_results mine
    on mine.duel_id = d.id and mine.player_id = v_uid
  left join public.async_duel_results theirs
    on theirs.duel_id = d.id
    and theirs.player_id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles opponent_profile
    on opponent_profile.id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles invited_profile
    on invited_profile.id = d.invited_id
  where (
      d.creator_id = v_uid
      or d.opponent_id = v_uid
      -- Bana gelen meydan okuma: davetliyim, kabul etmedim (rakip boş),
      -- süresi dolmadı, yaratıcı turunu bitirdi ve aramızda engel yok.
      or (
        d.invited_id = v_uid
        and d.opponent_id is null
        and d.status = 'open'
        and d.expires_at > now()
        and exists (
          select 1 from public.async_duel_results r
          where r.duel_id = d.id and r.player_id = d.creator_id
        )
        and not exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
             or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
        )
      )
    )
    and d.created_at >= now() - interval '30 days'
  order by d.created_at desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.resume_my_async_duel(p_duel_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_name text;
  v_invited_name text;
  v_answered integer;
  v_finished boolean;
  v_is_creator boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id;

  if not found or (v_duel.creator_id <> v_uid
                   and v_duel.opponent_id is distinct from v_uid) then
    raise exception 'Duel not found';
  end if;

  if v_duel.status = 'expired'
     or (v_duel.status <> 'completed' and now() > v_duel.expires_at) then
    raise exception 'Duel expired';
  end if;

  v_is_creator := (v_duel.creator_id = v_uid);

  select p.display_name into v_other_name
  from public.profiles p
  where p.id = case when v_is_creator then v_duel.opponent_id
                    else v_duel.creator_id end;

  if v_is_creator and v_duel.invited_id is not null then
    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = v_duel.invited_id;
  end if;

  select count(*)::integer into v_answered
  from public.async_duel_answers a
  where a.duel_id = v_duel.id and a.player_id = v_uid;

  select exists (
    select 1 from public.async_duel_results r
    where r.duel_id = v_duel.id and r.player_id = v_uid
  ) into v_finished;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'role', case when v_is_creator then 'creator' else 'opponent' end,
    'opponent_name', v_other_name,
    'opponent_id', case when v_is_creator then v_duel.opponent_id
                        else v_duel.creator_id end,
    'expires_at', v_duel.expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', v_answered,
    'finished', v_finished,
    'challenge_code', case when v_is_creator then v_duel.challenge_code
                           else null end,
    'invited_name', v_invited_name,
    'invited_id', case when v_is_creator then v_duel.invited_id
                       else null end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.accept_async_duel_challenge(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_duel public.async_duels%rowtype;
  v_expires_at timestamptz;
  v_creator_name text;
  v_answered integer;
  v_finished boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if v_code = '' then
    raise exception 'Challenge not found';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Satır kilidi: iki kişi aynı bağlantıyı aynı anda açarsa biri bekler,
  -- ikincisi 'Challenge already taken' görür.
  select * into v_duel
  from public.async_duels
  where challenge_code = v_code
  for update;

  if not found then
    raise exception 'Challenge not found';
  end if;

  if v_duel.creator_id = v_uid then
    raise exception 'Own challenge';
  end if;

  -- Engel iki yönde de geçerli ve ifşa edilmez: 'bulunamadı' ile aynı.
  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_uid and b.blocked_id = v_duel.creator_id)
       or (b.blocker_id = v_duel.creator_id and b.blocked_id = v_uid)
  ) then
    raise exception 'Challenge not found';
  end if;

  select p.display_name into v_creator_name
  from public.profiles p
  where p.id = v_duel.creator_id;

  -- Aynı kişi yeniden açıyor: durumunu döndür (hata yok). Süresi dolmuş ve
  -- tamamlanmamış düello yine de 'expired'dır.
  if v_duel.opponent_id = v_uid then
    if v_duel.status = 'expired'
       or (v_duel.status <> 'completed' and now() > v_duel.expires_at) then
      raise exception 'Challenge expired';
    end if;

    select count(*)::integer into v_answered
    from public.async_duel_answers a
    where a.duel_id = v_duel.id and a.player_id = v_uid;

    select exists (
      select 1 from public.async_duel_results r
      where r.duel_id = v_duel.id and r.player_id = v_uid
    ) into v_finished;

    return jsonb_build_object(
      'duel_id', v_duel.id,
      'role', 'opponent',
      'opponent_name', v_creator_name,
      'opponent_id', v_duel.creator_id,
      'expires_at', v_duel.expires_at,
      'questions', public.async_duel_questions_payload(v_duel.question_ids),
      'answered', v_answered,
      'finished', v_finished
    );
  end if;

  if v_duel.opponent_id is not null then
    raise exception 'Challenge already taken';
  end if;

  if v_duel.status <> 'open' or v_duel.expires_at <= now() then
    raise exception 'Challenge expired';
  end if;

  -- Arkadaş meydan okuması yalnız davetliye açıktır; bağlantı
  -- meydan okuması (invited_id boş) bağlantıyı tutan herkese.
  if v_duel.invited_id is not null and v_duel.invited_id <> v_uid then
    raise exception 'Challenge not for you';
  end if;

  -- start_async_duel ile aynı kural: yalnız yaratıcının kendi turunu
  -- BİTİRDİĞİ düello oynanır (aksi hâlde kabul eden sonuç yerine
  -- 'bekleniyor' görürdü). Paylaş düğmesi turdan sonra çıktığı için normalde
  -- tutar; yaratıcı çıkış yaptıysa kalan sorular TIMEOUT olarak gönderilir.
  if not exists (
    select 1 from public.async_duel_results r
    where r.duel_id = v_duel.id and r.player_id = v_duel.creator_id
  ) then
    raise exception 'Challenge not ready';
  end if;

  -- Rakibe kendi 48 saati verilir (start_async_duel ile aynı gerekçe).
  update public.async_duels
  set opponent_id = v_uid,
      status = 'matched',
      matched_at = now(),
      expires_at = greatest(expires_at, now() + interval '48 hours')
  where id = v_duel.id
  returning expires_at into v_expires_at;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'role', 'opponent',
    'opponent_name', v_creator_name,
    'opponent_id', v_duel.creator_id,
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', 0,
    'finished', false
  );
end;
$function$;

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
      'opponent_id', v_duel.creator_id,
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
    'opponent_id', case when v_role = 'opponent' then v_duel.creator_id
                        else null end,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
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


do $$
declare
  fn text;
  missing text[] := '{}';
begin
  foreach fn in array array['list_my_async_duels', 'resume_my_async_duel', 'accept_async_duel_challenge', 'start_async_duel', 'create_async_duel_challenge'] loop
    if position('opponent_id' in pg_get_functiondef(('public.' || fn)::regproc)) = 0
       and position('invited_id' in pg_get_functiondef(('public.' || fn)::regproc)) = 0 then
      missing := missing || fn;
    end if;
  end loop;
  if array_length(missing, 1) is not null then
    raise exception 'kimlik alani eklenmedi: %', missing;
  end if;
  raise notice 'tamam: 5 fonksiyon opponent_id/invited_id dondurur';
end $$;

rollback;

-- ===== 2) UYGULA (dry-run temizse) =====
begin;

CREATE OR REPLACE FUNCTION public.list_my_async_duels()
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  return query
  select jsonb_build_object(
    'duel_id', d.id,
    'status', d.status,
    'role', case when d.creator_id = v_uid then 'creator' else 'opponent' end,
    'opponent_name', opponent_profile.display_name,
    'opponent_id', opponent_profile.id,
    'category_name', cat.name,
    'my_correct', mine.correct_count,
    'opponent_correct', case
      when mine.duel_id is not null then theirs.correct_count
      else null
    end,
    'outcome', case
      when mine.duel_id is not null and theirs.duel_id is not null then
        case
          when mine.correct_count > theirs.correct_count then 'win'
          when mine.correct_count < theirs.correct_count then 'loss'
          when mine.total_ms < theirs.total_ms then 'win'
          when mine.total_ms > theirs.total_ms then 'loss'
          else 'draw'
        end
      else null
    end,
    'created_at', d.created_at,
    'completed_at', d.completed_at,
    'seen', (mine.duel_id is null or mine.seen_at is not null),
    'challenge_code', case
      when d.challenge_code is not null
           and (
             d.creator_id = v_uid
             or (d.invited_id = v_uid and d.opponent_id is null)
           )
        then d.challenge_code
      else null
    end,
    'incoming_challenge', (
      d.creator_id <> v_uid
      and d.invited_id = v_uid
      and d.opponent_id is null
    ),
    'invited_name', case
      when d.creator_id = v_uid then invited_profile.display_name
      else null
    end,
    'invited_id', case
      when d.creator_id = v_uid then d.invited_id
      else null
    end
  )
  from public.async_duels d
  left join public.categories cat
    on cat.id = d.category_id
  left join public.async_duel_results mine
    on mine.duel_id = d.id and mine.player_id = v_uid
  left join public.async_duel_results theirs
    on theirs.duel_id = d.id
    and theirs.player_id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles opponent_profile
    on opponent_profile.id = case
      when d.creator_id = v_uid then d.opponent_id
      else d.creator_id
    end
  left join public.profiles invited_profile
    on invited_profile.id = d.invited_id
  where (
      d.creator_id = v_uid
      or d.opponent_id = v_uid
      -- Bana gelen meydan okuma: davetliyim, kabul etmedim (rakip boş),
      -- süresi dolmadı, yaratıcı turunu bitirdi ve aramızda engel yok.
      or (
        d.invited_id = v_uid
        and d.opponent_id is null
        and d.status = 'open'
        and d.expires_at > now()
        and exists (
          select 1 from public.async_duel_results r
          where r.duel_id = d.id and r.player_id = d.creator_id
        )
        and not exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = v_uid and b.blocked_id = d.creator_id)
             or (b.blocker_id = d.creator_id and b.blocked_id = v_uid)
        )
      )
    )
    and d.created_at >= now() - interval '30 days'
  order by d.created_at desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.resume_my_async_duel(p_duel_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_name text;
  v_invited_name text;
  v_answered integer;
  v_finished boolean;
  v_is_creator boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id;

  if not found or (v_duel.creator_id <> v_uid
                   and v_duel.opponent_id is distinct from v_uid) then
    raise exception 'Duel not found';
  end if;

  if v_duel.status = 'expired'
     or (v_duel.status <> 'completed' and now() > v_duel.expires_at) then
    raise exception 'Duel expired';
  end if;

  v_is_creator := (v_duel.creator_id = v_uid);

  select p.display_name into v_other_name
  from public.profiles p
  where p.id = case when v_is_creator then v_duel.opponent_id
                    else v_duel.creator_id end;

  if v_is_creator and v_duel.invited_id is not null then
    select p.display_name into v_invited_name
    from public.profiles p
    where p.id = v_duel.invited_id;
  end if;

  select count(*)::integer into v_answered
  from public.async_duel_answers a
  where a.duel_id = v_duel.id and a.player_id = v_uid;

  select exists (
    select 1 from public.async_duel_results r
    where r.duel_id = v_duel.id and r.player_id = v_uid
  ) into v_finished;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'role', case when v_is_creator then 'creator' else 'opponent' end,
    'opponent_name', v_other_name,
    'opponent_id', case when v_is_creator then v_duel.opponent_id
                        else v_duel.creator_id end,
    'expires_at', v_duel.expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', v_answered,
    'finished', v_finished,
    'challenge_code', case when v_is_creator then v_duel.challenge_code
                           else null end,
    'invited_name', v_invited_name,
    'invited_id', case when v_is_creator then v_duel.invited_id
                       else null end
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.accept_async_duel_challenge(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_duel public.async_duels%rowtype;
  v_expires_at timestamptz;
  v_creator_name text;
  v_answered integer;
  v_finished boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if v_code = '' then
    raise exception 'Challenge not found';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('async-duel:' || v_uid::text, 0));

  -- Satır kilidi: iki kişi aynı bağlantıyı aynı anda açarsa biri bekler,
  -- ikincisi 'Challenge already taken' görür.
  select * into v_duel
  from public.async_duels
  where challenge_code = v_code
  for update;

  if not found then
    raise exception 'Challenge not found';
  end if;

  if v_duel.creator_id = v_uid then
    raise exception 'Own challenge';
  end if;

  -- Engel iki yönde de geçerli ve ifşa edilmez: 'bulunamadı' ile aynı.
  if exists (
    select 1 from public.blocked_users b
    where (b.blocker_id = v_uid and b.blocked_id = v_duel.creator_id)
       or (b.blocker_id = v_duel.creator_id and b.blocked_id = v_uid)
  ) then
    raise exception 'Challenge not found';
  end if;

  select p.display_name into v_creator_name
  from public.profiles p
  where p.id = v_duel.creator_id;

  -- Aynı kişi yeniden açıyor: durumunu döndür (hata yok). Süresi dolmuş ve
  -- tamamlanmamış düello yine de 'expired'dır.
  if v_duel.opponent_id = v_uid then
    if v_duel.status = 'expired'
       or (v_duel.status <> 'completed' and now() > v_duel.expires_at) then
      raise exception 'Challenge expired';
    end if;

    select count(*)::integer into v_answered
    from public.async_duel_answers a
    where a.duel_id = v_duel.id and a.player_id = v_uid;

    select exists (
      select 1 from public.async_duel_results r
      where r.duel_id = v_duel.id and r.player_id = v_uid
    ) into v_finished;

    return jsonb_build_object(
      'duel_id', v_duel.id,
      'role', 'opponent',
      'opponent_name', v_creator_name,
      'opponent_id', v_duel.creator_id,
      'expires_at', v_duel.expires_at,
      'questions', public.async_duel_questions_payload(v_duel.question_ids),
      'answered', v_answered,
      'finished', v_finished
    );
  end if;

  if v_duel.opponent_id is not null then
    raise exception 'Challenge already taken';
  end if;

  if v_duel.status <> 'open' or v_duel.expires_at <= now() then
    raise exception 'Challenge expired';
  end if;

  -- Arkadaş meydan okuması yalnız davetliye açıktır; bağlantı
  -- meydan okuması (invited_id boş) bağlantıyı tutan herkese.
  if v_duel.invited_id is not null and v_duel.invited_id <> v_uid then
    raise exception 'Challenge not for you';
  end if;

  -- start_async_duel ile aynı kural: yalnız yaratıcının kendi turunu
  -- BİTİRDİĞİ düello oynanır (aksi hâlde kabul eden sonuç yerine
  -- 'bekleniyor' görürdü). Paylaş düğmesi turdan sonra çıktığı için normalde
  -- tutar; yaratıcı çıkış yaptıysa kalan sorular TIMEOUT olarak gönderilir.
  if not exists (
    select 1 from public.async_duel_results r
    where r.duel_id = v_duel.id and r.player_id = v_duel.creator_id
  ) then
    raise exception 'Challenge not ready';
  end if;

  -- Rakibe kendi 48 saati verilir (start_async_duel ile aynı gerekçe).
  update public.async_duels
  set opponent_id = v_uid,
      status = 'matched',
      matched_at = now(),
      expires_at = greatest(expires_at, now() + interval '48 hours')
  where id = v_duel.id
  returning expires_at into v_expires_at;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'role', 'opponent',
    'opponent_name', v_creator_name,
    'opponent_id', v_duel.creator_id,
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', 0,
    'finished', false
  );
end;
$function$;

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
      'opponent_id', v_duel.creator_id,
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
    'opponent_id', case when v_role = 'opponent' then v_duel.creator_id
                        else null end,
    'expires_at', v_expires_at,
    'questions', coalesce(v_questions, '[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_async_duel_challenge(p_category text DEFAULT NULL::text, p_friend_id uuid DEFAULT NULL::uuid)
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


do $$
declare
  fn text;
  missing text[] := '{}';
begin
  foreach fn in array array['list_my_async_duels', 'resume_my_async_duel', 'accept_async_duel_challenge', 'start_async_duel', 'create_async_duel_challenge'] loop
    if position('opponent_id' in pg_get_functiondef(('public.' || fn)::regproc)) = 0
       and position('invited_id' in pg_get_functiondef(('public.' || fn)::regproc)) = 0 then
      missing := missing || fn;
    end if;
  end loop;
  if array_length(missing, 1) is not null then
    raise exception 'kimlik alani eklenmedi: %', missing;
  end if;
  raise notice 'tamam: 5 fonksiyon opponent_id/invited_id dondurur';
end $$;

commit;
