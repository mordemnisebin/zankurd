-- 2026-10-13: ARKADAŞA MEYDAN OKUMA — bağlantıyla ya da arkadaş seçerek
-- sırayla düello (async_duels.challenge_code).
--
-- NİÇİN: Sunucu verisi (2026-10-13): ilk haftadan sonra neredeyse kimse geri
-- gelmiyor, 436 hesabın 413'ü misafir. Ürünün rakipsiz yüzü, birbirini
-- tanıyan insanlar arasındaki Kürtçe bilgi yarışı. Sırayla düello bugün
-- yalnız RASTGELE rakiple eşleşiyor (`start_async_duel`); `invited_id`
-- sütunu v1.1 için ayrılmıştı ama hiçbir RPC doldurmuyordu. Hesabı olmayan
-- birine WhatsApp'tan gidebilen bir bağlantı hem büyüme hem dönüş döngüsüdür:
-- yaratıcı 7 soruyu oynar, bağlantıyı paylaşır, arkadaşı (misafir oturumla
-- bile) aynı 7 soruyu oynar, ikisi de bitince sonuç karşılaştırılır.
--
-- NE YAPAR:
--   1. `async_duels.challenge_code` (nullable, UNIQUE, biçim CHECK'li):
--      `D` + 8 karakter, alfabe `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (0/O,
--      1/I/L yok). Oda kodları `ZK-` ile başlar; `https://www.zankurd.com/
--      join/<kod>` bağlantısında iki biçim ne önekle, ne uzunlukla, ne de
--      alfabeyle çakışabilir (ayrıntı: lib/src/utils/join_deep_link.dart).
--   2. `generate_async_duel_challenge_code()` + `async_duel_questions_payload`
--      iç yardımcıları (istemciye KAPALI).
--   3. `create_async_duel_challenge(p_category, p_friend_id)`: start_async_duel
--      ile AYNI yetki/limit/soru seçimi/yanıt biçimi, ama ASLA bekleyen
--      rastgele düelloya eşleşmez; her seferinde yeni düello + yeni kod açar.
--      `p_friend_id` verilirse kabul edilmiş arkadaş olmalı ve iki yönde de
--      engelli olmamalı; `invited_id` o olur (2026-10-13_push_delivery.sql'deki
--      `trg_async_duel_invite_push` tetikleyicisi yaratıcının sonucu
--      yazılınca davetliye bildirim kuyruklar — burada yeniden yazılmaz).
--   4. `accept_async_duel_challenge(p_code)`: misafir dahil her oturumlu
--      kullanıcı; yaratıcı olmayan, engelsiz, süresi dolmamış, rakipsiz
--      düello. `invited_id` doluysa YALNIZ davetli, boşsa (bağlantı
--      meydan okuması) bağlantıyı elinde tutan herkes. Aynı kişi için
--      idempotent (yeniden açınca durumunu döndürür, hata vermez).
--   5. `start_async_duel` (blocking_enforcement'taki SON gövde birebir) +
--      tek fark: rastgele eşleşme `challenge_code`lu düelloları atlar.
--   6. `list_my_async_duels` (09-28'deki SON gövde birebir) + eklenen alanlar:
--      challenge_code, incoming_challenge, invited_name. Mevcut alanlar
--      aynen kalır (eski istemci yeni alanları yok sayar).
--   7. `expire_async_duels` DEĞİŞMEDİ ve kabul edilmemiş meydan okumaları
--      zaten kapsar (status='open' ve expires_at geçmiş); doğrulama bloğu bunu
--      denetler.
--
-- HATA SÖZLEŞMESİ (Dart tarafı: lib/src/models/async_duel.dart,
-- `AsyncDuelChallengeError`):
--   create: 'Not authenticated', 'No questions', 'Too many open duels',
--           'Not a friend' (arkadaş değil / engelli / kendisi — engel ifşa
--           edilmez).
--   accept: 'Not authenticated', 'Challenge not found' (bilinmeyen kod ya da
--           iki yönden biri engelli — engel ifşa edilmez), 'Own challenge',
--           'Challenge already taken', 'Challenge expired',
--           'Challenge not for you', 'Challenge not ready' (yaratıcı turunu
--           henüz bitirmedi).
--
-- ESKİ İSTEMCİ UYUMU: mevcut RPC imzaları ve dönüş anahtarları değişmedi;
-- yeni sütun nullable. İstemci yeni RPC'ler henüz yokken (PGRST202/42883) giriş
-- noktalarını gizler; yani uygulama göçten önce de sonra da yayınlanabilir.
--
-- TEKRAR: idempotent (add column if not exists, create or replace, if not
-- exists indeksler, CHECK yalnız yoksa eklenir). İkinci çalıştırma aynı
-- sonucu verir.
-- GERİ ALMA:
--   drop function if exists public.accept_async_duel_challenge(text);
--   drop function if exists public.create_async_duel_challenge(text, uuid);
--   drop function if exists public.async_duel_questions_payload(uuid[]);
--   drop function if exists public.generate_async_duel_challenge_code();
--   -- start_async_duel: 2026-10-02_blocking_enforcement.sql'i yeniden uygula
--   -- list_my_async_duels: 2026-09-28_async_duels.sql'deki gövdeyi yeniden uygula
--   alter table public.async_duels drop column if exists challenge_code;
-- Uygulama: supabase db query --linked -f supabase/2026-10-13_friend_challenge.sql
-- (Bu dosya canlıya UYGULANMADI; Docker olmadığından yerelde de çalıştırılmadı.
--  Bkz. supabase/applied.md.)

begin;

-- ---------------------------------------------------------------------
-- 1) Sütun, indeksler, biçim kısıtı
-- ---------------------------------------------------------------------

alter table public.async_duels
  add column if not exists challenge_code text;

-- UNIQUE: aynı kod iki düelloya gidemez. Null'lar çakışmaz (rastgele
-- düellolar kodsuzdur).
create unique index if not exists async_duels_challenge_code_key
  on public.async_duels (challenge_code);

-- list_my_async_duels'in "bana gelen meydan okuma" yarısı için.
create index if not exists async_duels_invited_open_idx
  on public.async_duels (invited_id)
  where invited_id is not null and status = 'open';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'async_duels_challenge_code_format'
      and conrelid = 'public.async_duels'::regclass
  ) then
    alter table public.async_duels
      add constraint async_duels_challenge_code_format
      check (challenge_code is null or challenge_code ~ '^D[2-9A-HJKMNP-Z]{8}$');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2) İç yardımcılar (istemciye kapalı)
-- ---------------------------------------------------------------------

-- 39,6 bit rastgelelik: gen_random_uuid() (CSPRNG) baytlarından, sürüm/varyant
-- baytları (6 ve 8) atlanarak. Alfabe 31 karakter; kod 'D' + 8 karakter.
create or replace function public.generate_async_duel_challenge_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  v_alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  v_bytes bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
  v_positions constant integer[] := array[0, 1, 2, 3, 4, 5, 7, 9];
  v_code text := 'D';
  v_pos integer;
begin
  foreach v_pos in array v_positions loop
    v_code := v_code
      || substr(v_alphabet, 1 + (get_byte(v_bytes, v_pos) % 31), 1);
  end loop;
  return v_code;
end;
$$;

revoke all on function public.generate_async_duel_challenge_code()
  from public, anon, authenticated;

-- start_async_duel'in soru JSON'unun BİREBİR aynısı (doğru şık YOK).
create or replace function public.async_duel_questions_payload(p_question_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_questions jsonb;
begin
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
  from unnest(p_question_ids) with ordinality as ord(question_id, idx)
  join public.questions q on q.id = ord.question_id
  left join public.categories c on c.id = q.category_id;

  return coalesce(v_questions, '[]'::jsonb);
end;
$$;

revoke all on function public.async_duel_questions_payload(uuid[])
  from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3) create_async_duel_challenge
-- ---------------------------------------------------------------------

create or replace function public.create_async_duel_challenge(
  p_category text default null,
  p_friend_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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

  select count(*) into v_open_count
  from public.async_duels
  where creator_id = v_uid
    and status = 'open';

  if v_open_count >= 5 then
    raise exception 'Too many open duels';
  end if;

  -- Soru seçimi start_async_duel'inkiyle BİREBİR aynı süzgeç (gerekçe orada:
  -- 2026-09-28_async_duels.sql). `rnd` bir kez hesaplanır; sıra =
  -- array_agg sırası = istemcideki index 0..6.
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
    'invited_name', v_invited_name
  );
end;
$$;

revoke all on function public.create_async_duel_challenge(text, uuid)
  from public, anon;
grant execute on function public.create_async_duel_challenge(text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------
-- 4) accept_async_duel_challenge
-- ---------------------------------------------------------------------

create or replace function public.accept_async_duel_challenge(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    'expires_at', v_expires_at,
    'questions', public.async_duel_questions_payload(v_duel.question_ids),
    'answered', 0,
    'finished', false
  );
end;
$$;

revoke all on function public.accept_async_duel_challenge(text)
  from public, anon;
grant execute on function public.accept_async_duel_challenge(text)
  to authenticated;

-- ---------------------------------------------------------------------
-- 5) start_async_duel — 2026-10-02_blocking_enforcement.sql'deki SON gövdenin
--    birebir kopyası; TEK fark: `and d.challenge_code is null` (rastgele
--    eşleşme bağlantı/arkadaş meydan okumalarını almaz; invited_id zaten
--    süzülüyordu).
-- ---------------------------------------------------------------------

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

revoke all on function public.start_async_duel(text) from public, anon;
grant execute on function public.start_async_duel(text) to authenticated;

-- ---------------------------------------------------------------------
-- 6) list_my_async_duels — 2026-09-28_async_duels.sql'deki SON gövde + yeni
--    alanlar (mevcut alanlar aynen):
--      challenge_code     : yalnız (a) benim açtığım meydan okuma ya da
--                           (b) bana gelen kabul edilmemiş meydan okuma için
--                           dolu — başkasının kodu ASLA dönmez.
--      incoming_challenge : bana gelen, henüz kabul etmediğim, süresi
--                           dolmamış, yaratıcının turunu bitirdiği ARKADAŞ
--                           meydan okuması ("Sıra sende").
--      invited_name       : benim davet ettiğim arkadaşın adı (yalnız ben
--                           yaratıcıysam).
-- ---------------------------------------------------------------------

create or replace function public.list_my_async_duels()
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.list_my_async_duels() from public, anon;
grant execute on function public.list_my_async_duels() to authenticated;

-- ---------------------------------------------------------------------
-- Doğrulama: biri tutmazsa bütün göç geri alınır.
-- ---------------------------------------------------------------------

do $$
declare
  v_def text;
  v_fn text;
  v_code text;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'async_duels'
      and column_name = 'challenge_code'
  ) then
    raise exception 'friend_challenge: challenge_code sütunu yok';
  end if;
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public' and tablename = 'async_duels'
      and indexname = 'async_duels_challenge_code_key'
      and indexdef ilike '%unique%'
  ) then
    raise exception 'friend_challenge: challenge_code UNIQUE indeksi yok';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'async_duels_challenge_code_format'
  ) then
    raise exception 'friend_challenge: kod biçim kısıtı yok';
  end if;

  -- Üretilen kod kendi kısıtına uyar (alfabe ve uzunluk).
  for i in 1..200 loop
    v_code := public.generate_async_duel_challenge_code();
    if v_code !~ '^D[2-9A-HJKMNP-Z]{8}$' then
      raise exception 'friend_challenge: üretilen kod biçime uymuyor: %', v_code;
    end if;
  end loop;

  -- İstemciye açık RPC'ler: authenticated evet, anon hayır.
  foreach v_fn in array array[
    'public.create_async_duel_challenge(text,uuid)',
    'public.accept_async_duel_challenge(text)',
    'public.start_async_duel(text)',
    'public.list_my_async_duels()'
  ] loop
    if has_function_privilege('anon', v_fn::regprocedure, 'execute') then
      raise exception 'friend_challenge: % anon''a açık', v_fn;
    end if;
    if not has_function_privilege('authenticated', v_fn::regprocedure, 'execute') then
      raise exception 'friend_challenge: % authenticated''a kapalı', v_fn;
    end if;
  end loop;

  -- İç yardımcılar istemciye kapalı.
  foreach v_fn in array array[
    'public.generate_async_duel_challenge_code()',
    'public.async_duel_questions_payload(uuid[])'
  ] loop
    if has_function_privilege('anon', v_fn::regprocedure, 'execute')
       or has_function_privilege('authenticated', v_fn::regprocedure, 'execute') then
      raise exception 'friend_challenge: % istemciye açık', v_fn;
    end if;
  end loop;

  -- Rastgele eşleşme meydan okumaları atlar VE engel süzgecini korur.
  v_def := pg_get_functiondef('public.start_async_duel(text)'::regprocedure);
  if v_def not like '%challenge_code is null%' then
    raise exception 'friend_challenge: start_async_duel meydan okumaları atlamıyor';
  end if;
  if v_def not like '%blocked_users%' or v_def not like '%invited_id is null%' then
    raise exception 'friend_challenge: start_async_duel önceki süzgeçleri kaybetmiş';
  end if;

  v_def := pg_get_functiondef('public.list_my_async_duels()'::regprocedure);
  if v_def not like '%incoming_challenge%' or v_def not like '%challenge_code%' then
    raise exception 'friend_challenge: list_my_async_duels yeni alanları taşımıyor';
  end if;

  v_def := pg_get_functiondef('public.create_async_duel_challenge(text,uuid)'::regprocedure);
  if v_def not like '%blocked_users%' or v_def not like '%public.friends%' then
    raise exception 'friend_challenge: create arkadaş/engel denetimi taşımıyor';
  end if;

  v_def := pg_get_functiondef('public.accept_async_duel_challenge(text)'::regprocedure);
  if v_def not like '%blocked_users%' or v_def not like '%invited_id%' then
    raise exception 'friend_challenge: accept engel/davetli denetimi taşımıyor';
  end if;

  -- Süresi dolan kabul edilmemiş meydan okumalar mevcut cron fonksiyonuyla
  -- kapanır: 'open' durumunu kapsamalı.
  v_def := pg_get_functiondef('public.expire_async_duels()'::regprocedure);
  if v_def not like '%''open''%' or v_def not like '%expires_at <= now()%' then
    raise exception 'friend_challenge: expire_async_duels açık düelloları kapsamıyor';
  end if;

  -- Davetli bildirim tetikleyicisi (push_delivery) yerinde olmalı; yoksa
  -- yalnız uyar (o göç ayrı sırada uygulanabilir).
  if not exists (
    select 1 from pg_trigger
    where tgname = 'trg_async_duel_invite_push' and not tgisinternal
  ) then
    raise notice 'friend_challenge: trg_async_duel_invite_push yok (2026-10-13_push_delivery.sql uygulanınca arkadaş meydan okumasında bildirim gider)';
  end if;
end $$;

commit;
