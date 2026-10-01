-- 2026-10-02: engelleme (blocked_users) tüm etkileşim yollarında uygulanır
-- (güvenlik denetimi M5).
--
-- KUSUR: `block_player` yalnız bir satır yazıyordu; engeli yalnız
-- `join_matchmaking` okuyordu (hızlı eşleşme). Engellenen kişi yine de
-- `join_room_by_code` ile engelleyenin odasına girebiliyor, `add_friend` ile
-- istek yağdırabiliyor, `accept_friend_request` ile (engelden ÖNCE gelmiş)
-- isteği kabul ettirebiliyor, `search_profiles` ile aranabiliyor,
-- `get_leaderboard`da görünüyor ve `start_async_duel` ile açık düellosuna
-- eşleşebiliyordu. Apple 1.2 "engelle" maddesi kullanıcı gözünde tüm bu
-- yolları kapsar.
--
-- DÜZELTME (her fonksiyon canlı gövdenin kopyası + tek bir engel süzgeci):
--   * join_room_by_code  : oda sahibi/odadaki biriyle HER İKİ YÖNDE engel
--                          varsa 'Room not found or already started'
--                          (istemci `notFound`a eşler; engelli olduğunu
--                          ifşa etmez, yeni metin gerekmez).
--   * add_friend         : (false, 'Friend request blocked') — istemci
--                          `success=false` ile mevcut başarısızlık metnini
--                          gösterir (yeni metin gerekmez).
--   * accept_friend_request: aynı (false, 'Friend request blocked').
--   * search_profiles    : iki yönde engelli profiller sonuçta yok.
--   * get_leaderboard / get_my_leaderboard_rank: ENGELLEDİKLERİM çağıranın
--                          listesinde yok (tek yön; sıra numaraları iki
--                          fonksiyonda tutarlı).
--   * start_async_duel   : engelli yaratıcının açık düellosuna eşleşmez
--                          (hata yok, sıradakine bakılır).
-- Engel bilgisi hiçbir yanıtta ayrıca ifşa edilmez.
--
-- ESKİ İSTEMCİ UYUMU: imzalar ve dönüş şekilleri DEĞİŞMEDİ; yeni yollar
-- yalnız mevcut hata/başarısızlık biçimlerini kullanır.
--
-- GERİ ALMA: her fonksiyonun önceki gövdesi `2026-09-30_*` (get_leaderboard,
-- get_my_leaderboard_rank, async_duel_all_categories) ve baseline /
-- `2026-08-06_friend_identity_and_resend.sql` dosyalarındadır.

begin;

CREATE OR REPLACE FUNCTION public.join_room_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_room record;
  v_existing_room_id uuid;
  v_player_count integer;
  v_user_coins integer := 0;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('room-membership', 0));
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));

  select r.id into v_existing_room_id
  from public.rooms r
  join public.room_players rp on rp.room_id = r.id
  where rp.player_id = v_uid
    and r.status in ('lobby', 'active')
  order by r.created_at desc, r.id desc
  limit 1;

  select
    r.id,
    r.code,
    r.host_id,
    r.question_count,
    coalesce(r.seconds_per_question, 20) as seconds_per_question,
    coalesce(r.entry_fee, 0) as entry_fee,
    coalesce(c.name, 'Ziman') as category_name
  into v_room
  from public.rooms r
  left join public.categories c on c.id = r.category_id
  where upper(r.code) = upper(trim(p_code))
    and r.status = 'lobby'
  limit 1
  for update of r;

  if not found then
    raise exception 'Room not found or already started';
  end if;

  if v_existing_room_id is not null
     and v_existing_room_id <> v_room.id then
    raise exception 'Player is already in another live room';
  end if;

  -- Bakiye kontrolü (ücretli oda için)
  if v_room.entry_fee > 0 then
    select coalesce(sum(amount), 0)::integer
    into v_user_coins
    from public.coin_transactions
    where player_id = v_uid;

    if v_user_coins < v_room.entry_fee then
      raise exception 'Insufficient coins for room entry fee';
    end if;
  end if;

  if exists (
    select 1
    from public.room_players rp
    where rp.room_id = v_room.id
      and rp.player_id = v_uid
  ) then
    return json_build_object(
      'room_id', v_room.id,
      'code', v_room.code,
      'host_id', v_room.host_id,
      'question_count', v_room.question_count,
      'seconds_per_question', v_room.seconds_per_question,
      'entry_fee', v_room.entry_fee,
      'category_name', v_room.category_name
    );
  end if;

  -- Engelleme (2026-10-02 M5): oda sahibi ya da odadaki biriyle aramızda
  -- HER İKİ YÖNDE engel varsa katılım reddedilir. Mesaj bilerek mevcut
  -- "bulunamadı" mesajıdır: engelleyen kişinin odasını arayan bir kullanıcı
  -- engellendiğini öğrenmemeli; istemci bunu zaten `notFound`a eşler.
  if exists (
    select 1
    from public.blocked_users b
    where (b.blocker_id = v_uid
           and (b.blocked_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocked_id)))
       or (b.blocked_id = v_uid
           and (b.blocker_id = v_room.host_id
                or exists (select 1 from public.room_players m
                           where m.room_id = v_room.id
                             and m.player_id = b.blocker_id)))
  ) then
    raise exception 'Room not found or already started';
  end if;

  select count(*)::integer into v_player_count
  from public.room_players rp
  where rp.room_id = v_room.id;

  if v_player_count >= 2 then
    raise exception 'Room is full';
  end if;

  insert into public.room_players (room_id, player_id, is_ready)
  values (v_room.id, v_uid, false);

  -- Katılan oyuncunun ücreti de burada düşer; iki taraf da ödemezse havuz
  -- diye bir şey olmaz, yalnız ödül olur.
  if v_room.entry_fee > 0 then
    insert into public.coin_transactions (player_id, amount, reason)
    values (v_uid, -v_room.entry_fee, 'room_entry_fee');
  end if;

  return json_build_object(
    'room_id', v_room.id,
    'code', v_room.code,
    'host_id', v_room.host_id,
    'question_count', v_room.question_count,
    'seconds_per_question', v_room.seconds_per_question,
    'entry_fee', v_room.entry_fee,
    'category_name', v_room.category_name
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_friend(p_friend_id uuid, p_friend_name text)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid;
  v_display_name text;
  v_rows int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  if v_user_id = p_friend_id then
    return query select false, 'Cannot add yourself as friend'::text;
    return;
  end if;

  -- Engelleme (2026-10-02 M5): iki yönden biri engelliyse istek gitmez.
  -- Mesaj genel tutuldu; engellenen kişi engellendiğini anlamasın.
  if exists (
    select 1 from blocked_users b
    where (b.blocker_id = v_user_id and b.blocked_id = p_friend_id)
       or (b.blocker_id = p_friend_id and b.blocked_id = v_user_id)
  ) then
    return query select false, 'Friend request blocked'::text;
    return;
  end if;

  if exists (
    select 1 from friends
    where (user_id = v_user_id and friend_id = p_friend_id)
       or (user_id = p_friend_id and friend_id = v_user_id)
  ) then
    return query select false, 'Already friends'::text;
    return;
  end if;

  -- Kimlik yalnız sunucudan. `p_friend_name` bilerek kullanılmıyor:
  -- istemciden gelen ad başka birinin adı olabilir. İmza, çağıran
  -- istemciler kırılmasın diye korundu.
  select display_name into v_display_name from profiles where id = v_user_id;

  insert into friend_requests (from_user_id, from_user_name, to_user_id, status)
  values (
    v_user_id,
    coalesce(nullif(btrim(v_display_name), ''), 'Yarîzan'),
    p_friend_id,
    'pending'
  )
  on conflict (from_user_id, to_user_id) do update
     set status = 'pending',
         from_user_name = excluded.from_user_name,
         created_at = now()
   where friend_requests.status is distinct from 'pending';

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    -- Gerçekten hiçbir şey yazılmadı. Eskiden burada da TRUE dönülüyordu.
    return query select false, 'Friend request already pending'::text;
    return;
  end if;

  return query select true, 'Friend request sent'::text;
end;
$function$;

CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id uuid)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid;
  v_from_user_id uuid;
  v_from_name text;
  v_my_name text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  select from_user_id into v_from_user_id
  from friend_requests
  where id = p_request_id and to_user_id = v_user_id and status = 'pending';

  if v_from_user_id is null then
    return query select false, 'Friend request not found or already processed'::text;
    return;
  end if;

  -- Engelleme (2026-10-02 M5): istek geldikten SONRA bir taraf diğerini
  -- engellediyse kabul edilemez (engel, bekleyen isteği geçersiz kılar).
  if exists (
    select 1 from blocked_users b
    where (b.blocker_id = v_user_id and b.blocked_id = v_from_user_id)
       or (b.blocker_id = v_from_user_id and b.blocked_id = v_user_id)
  ) then
    return query select false, 'Friend request blocked'::text;
    return;
  end if;

  -- İki ad da profilden; istekteki kopya kimlik kaynağı değildir.
  select display_name into v_from_name from profiles where id = v_from_user_id;
  select display_name into v_my_name from profiles where id = v_user_id;

  insert into friends (user_id, friend_id, friend_name)
  values
    (v_user_id, v_from_user_id,
     coalesce(nullif(btrim(v_from_name), ''), 'Yarîzan')),
    (v_from_user_id, v_user_id,
     coalesce(nullif(btrim(v_my_name), ''), 'Yarîzan'))
  on conflict do nothing;

  update friend_requests set status = 'accepted' where id = p_request_id;

  return query select true, 'Friend request accepted'::text;
end;
$function$;

CREATE OR REPLACE FUNCTION public.search_profiles(p_query text)
 RETURNS TABLE(id uuid, display_name text, avatar_color text, player_tag text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := auth.uid();
  v_query text := trim(coalesce(p_query, ''));
  -- "ZK-4F7K", "zk-4f7k" ve "4F7K" aynı kodu arar — kod ekranda
  -- önekle görünüyor, elle yazarken önekin yazılmasını beklemek
  -- gereksiz sürtünme olurdu (2026-07-28 kararı, burada geri getirilir).
  v_tag text := upper(regexp_replace(v_query, '^[zZ][kK][-\s]*', ''));
  v_pattern text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if length(v_query) < 2 then
    return;
  end if;

  -- Ters bölü ÖNCE kaçırılır, yoksa kendisinden sonra eklenenleri bozar.
  v_pattern := '%' ||
    replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') ||
    '%';

  return query
  select p.id, p.display_name, p.avatar_color, p.player_tag
  from public.profiles p
  where p.id <> v_user_id
    -- Engelleme (2026-10-02 M5): iki yönde de aramada görünmez.
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_user_id and b.blocked_id = p.id)
         or (b.blocker_id = p.id and b.blocked_id = v_user_id)
    )
    and (p.player_tag = v_tag or p.display_name ilike v_pattern escape '\')
  -- Kod eşleşmesi başa: birebir arayan, aradığını ilk satırda görür.
  order by (p.player_tag = v_tag) desc, p.display_name
  limit 10;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_days integer DEFAULT '-1'::integer, p_limit integer DEFAULT 10)
 RETURNS TABLE(player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    rp.player_id,
    coalesce(p.display_name, 'Oyuncu'),
    coalesce(sum(rp.score), 0),
    coalesce(max(rp.streak), 0),
    count(distinct rp.room_id),
    p.avatar_icon,
    p.avatar_color,
    p.avatar_url,
    p.avatar_frame,
    p.showcase_title
  from public.room_players rp
  join public.rooms r on r.id = rp.room_id
  left join public.profiles p on p.id = rp.player_id
  where r.status = 'finished'
    -- Engelleme (2026-10-02 M5): engellediğim oyuncular MENİM listemde yok.
    -- Yalnız çağıranın engelleri uygulanır (tek yön); liste kişiye göre
    -- değişir ama başkasının engel bilgisi sızmaz.
    and not exists (
      select 1 from public.blocked_users b
      where b.blocker_id = auth.uid()
        and b.blocked_id = rp.player_id
    )
    and (p_days <= 0 or r.finished_at >= now() - make_interval(days => p_days))
  group by
    rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
    p.avatar_url, p.avatar_frame, p.showcase_title
  having coalesce(sum(rp.score), 0) > 0
  order by coalesce(sum(rp.score), 0) desc,
    coalesce(max(rp.streak), 0) desc,
    count(distinct rp.room_id) desc
  limit least(greatest(p_limit, 1), 100);
$function$;

CREATE OR REPLACE FUNCTION public.get_my_leaderboard_rank(p_days integer DEFAULT '-1'::integer)
 RETURNS TABLE(rank bigint, player_id uuid, display_name text, total_score bigint, best_streak bigint, rooms_played bigint, avatar_icon text, avatar_color text, avatar_url text, avatar_frame text, showcase_title text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with board as (
    select
      rp.player_id,
      coalesce(p.display_name, 'Oyuncu') as display_name,
      coalesce(sum(rp.score), 0) as total_score,
      coalesce(max(rp.streak), 0) as best_streak,
      count(distinct rp.room_id) as rooms_played,
      p.avatar_icon,
      p.avatar_color,
      p.avatar_url,
      p.avatar_frame,
      p.showcase_title
    from public.room_players rp
    join public.rooms r on r.id = rp.room_id
    left join public.profiles p on p.id = rp.player_id
    where r.status = 'finished'
      -- get_leaderboard ile aynı engel süzgeci (sıra numaraları tutarlı kalsın).
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid()
          and b.blocked_id = rp.player_id
      )
      and (p_days <= 0
        or r.finished_at >= now() - make_interval(days => p_days))
    group by
      rp.player_id, p.display_name, p.avatar_icon, p.avatar_color,
      p.avatar_url, p.avatar_frame, p.showcase_title
    having coalesce(sum(rp.score), 0) > 0
  ),
  ordered as (
    select
      b.*,
      row_number() over (
        order by
          b.total_score desc,
          b.best_streak desc,
          b.rooms_played desc
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

  select d.* into v_duel
  from public.async_duels d
  where d.status = 'open'
    and d.creator_id <> v_uid
    and d.invited_id is null
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
    select count(*) into v_open_count
    from public.async_duels
    where creator_id = v_uid
      and status = 'open';

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

-- ACL'ler `create or replace` ile korunur; yine de açıkça sabitle.
revoke all on function public.join_room_by_code(text) from public, anon;
grant execute on function public.join_room_by_code(text) to authenticated;
revoke all on function public.add_friend(uuid, text) from public, anon;
grant execute on function public.add_friend(uuid, text) to authenticated;
revoke all on function public.accept_friend_request(uuid) from public, anon;
grant execute on function public.accept_friend_request(uuid) to authenticated;
revoke all on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;
revoke all on function public.get_leaderboard(integer, integer) from public, anon;
grant execute on function public.get_leaderboard(integer, integer) to authenticated;
revoke all on function public.get_my_leaderboard_rank(integer) from public, anon;
grant execute on function public.get_my_leaderboard_rank(integer) to authenticated;
revoke all on function public.start_async_duel(text) from public, anon;
grant execute on function public.start_async_duel(text) to authenticated;

do $$
declare
  v_fn text;
begin
  foreach v_fn in array array[
    'public.join_room_by_code(text)',
    'public.add_friend(uuid,text)',
    'public.accept_friend_request(uuid)',
    'public.search_profiles(text)',
    'public.get_leaderboard(integer,integer)',
    'public.get_my_leaderboard_rank(integer)',
    'public.start_async_duel(text)'
  ] loop
    if pg_get_functiondef(v_fn::regprocedure) not like '%blocked_users%' then
      raise exception '% engel süzgeci taşımıyor', v_fn;
    end if;
    if has_function_privilege('anon', v_fn::regprocedure, 'execute') then
      raise exception '% anon''a açık', v_fn;
    end if;
    if not has_function_privilege('authenticated', v_fn::regprocedure, 'execute') then
      raise exception '% authenticated''a kapalı', v_fn;
    end if;
  end loop;
end $$;

commit;
