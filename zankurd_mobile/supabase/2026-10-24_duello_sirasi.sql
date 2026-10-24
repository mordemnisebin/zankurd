-- 2026-10-24: SIRAYLA DÜELLO — 24 saat, hükmen sonuç, hatırlatma, soru sunumu.
--
-- Ürün sahibi onaylı Trivia-Crack benzeri düzen. Beş değişiklik, tek göç:
--   1) PENCERE 24 SAAT (48'di): yaratma (sütun varsayılanı), rastgele
--      eşleşmeye katılma ve arkadaş meydan okumasını kabul etme.
--   2) HÜKMEN: süresi dolan düelloda turunu BİTİREN taraf kazanır, diğeri
--      kaybeder. Kalıcı iz: `async_duels.forfeit_loser_id`. Durum yine
--      'expired' kalır (yeni durum değeri yok: CHECK ve eski istemci bozulmaz);
--      kazanan normal galibiyetin XP'sini SUNUCUDA alır: expire_async_duels
--      sonuç satırının `xp_awarded` işaretiyle tek seferlik verir (istemci
--      claim_async_duel_xp'yi sonradan çağırırsa çift vermez; 2.1.0 istemcisi
--      'expired'i kayıpsız kapanış sanıp claim etmese de XP kaybolmaz).
--      Yalnız düelloya GİRMİŞ rakip kaybeder; kabul edilmemiş arkadaş daveti
--      hükmen sayılmaz.
--      Rakibi hiç çıkmayan rastgele düello ve kimsenin almadığı bağlantı
--      meydan okuması eskisi gibi kayıpsız 'expired' kalır.
--   3) list_my_async_duels `expires_at`, `forfeit` döndürür; `outcome`
--      hükmen sonuçta win/loss olur. Yeni anahtarlar eklemedir: eski
--      istemci yok sayar.
--   4) Bildirim: (a) süreye ≤ 4 saat kala turunu bitirmemiş oyuncuya TEK
--      hatırlatma (`async_duel_turn`), (b) hükmen sonuç her iki oyuncuya
--      (`async_duel_result`). Metin iki dilli "KU · TR" (sunucu alıcının
--      dilini bilmiyor; 2026-10-23_arkadaslik_bildirimleri.sql ile aynı biçim).
--   5) SORU SUNUMU (devam adaleti + süre hilesi kapatma): yeni RPC
--      `present_async_duel_question` oyuncunun SIRADAKİ soruyu ekrana koyduğu
--      anı ilk çağrıda kaydeder (`async_duel_question_starts`; tekrar çağrıda
--      değişmez). answer_async_duel o indeks için kayıt VARSA süreyi
--      clock_timestamp() - started_at ile ölçer; 20 sn + 5 sn ağ payını
--      aşan cevap YANLIŞ sayılır. Kayıt yoksa (2.1.0 istemcisi) eski ölçüm
--      (önceki cevaptan itibaren, 20 sn tavan) aynen sürer. "Devam"
--      (resume) artık saati sıfırlamaz: yarıda bırakılmış soru dönüşte
--      süresi geçmişse yanlış sayılır, sonraki sorular sunulduklarında temiz
--      başlar.
--   Ek sertleştirme: answer_async_duel kilitten SONRA duvar saatiyle
--   (clock_timestamp) durum+süreyi doğrular; hükmen/hatırlatma bildirimleri
--   engelli çiftlere gitmez; hatırlatma yalnız gerçekten işaretlenen
--   satırlardan üretilir (eşzamanlı cron koşusunda tek); değişen bütün
--   SECURITY DEFINER gövdelerinde `search_path = public, pg_temp`.
--
-- Her gövde CANLI tanımdan (2026-10-24, `pg_get_functiondef`) alındı; yalnız
-- işaretli satırlar ve search_path farklıdır. İzinler (create or replace ile)
-- korunur. İstemci imzaları DEĞİŞMEDİ.
--
-- Cron: expire_async_duels artık 10 dakikada bir koşar —
-- 2026-10-24_duello_sirasi_cron.sql (bu dosyadan SONRA uygula).
--
-- Mevcut açık düellolar: süreleri (48 saatlik) olduğu gibi kalır; yalnız yeni
-- pencereler 24 saattir.
-- İdempotent. Uygulama: `supabase db query --linked -f supabase/2026-10-24_duello_sirasi.sql`
-- Geri alma: önceki gövdeler `git log -p` ile 2026-09-28/10-02/10-13/10-16/
-- 10-21 göçlerinde; sütunlar zararsızdır (`drop column` gerekmez).

begin;

-- ═════════════════════════════════════════════════════════════════════════
-- 1) Şema
-- ═════════════════════════════════════════════════════════════════════════
-- 24 saatlik pencere: create_async_duel_challenge ve start_async_duel yeni
-- satırı varsayılanla açar (gövdeleri expires_at'e dokunmaz).
alter table public.async_duels
  alter column expires_at set default (now() + interval '24 hours');

-- Hükmen kaybeden oyuncu (boşsa hükmen yok). Kullanıcı silinirse iz boşalır.
alter table public.async_duels
  add column if not exists forfeit_loser_id uuid
    references auth.users(id) on delete set null;

-- Hatırlatma gönderilmiş oyuncular: oyuncu başına düello başına TEK hatırlatma.
alter table public.async_duels
  add column if not exists reminder_sent_for uuid[] not null default '{}';

-- Soru sunum kaydı: oyuncu bir soruyu ekrana koyduğunda ilk çağrıda yazılır,
-- sonra DEĞİŞMEZ (PK üçlü; `on conflict do nothing`). İstemciye kapalı tablo.
create table if not exists public.async_duel_question_starts (
  duel_id uuid not null references public.async_duels(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  question_index integer not null check (question_index >= 0),
  started_at timestamptz not null default clock_timestamp(),
  primary key (duel_id, player_id, question_index)
);
alter table public.async_duel_question_starts enable row level security;
revoke all on table public.async_duel_question_starts
  from public, anon, authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 2) present_async_duel_question — soru sunum anı (Trivia Crack modeli)
-- ═════════════════════════════════════════════════════════════════════════
-- İstemci soruyu ekrana koyarken çağırır. Yalnız oyuncunun SIRADAKİ beklenen
-- sorusu (önceki cevap sayısı) sunulabilir; sıra dışı indeks 'Invalid index'.
-- İlk çağrı başlangıcı kaydeder, sonrakiler AYNI başlangıcı döndürür:
-- uygulamayı kapatıp açmak ya da "devam"ı tekrarlamak saati sıfırlamaz.
-- Dönüş: started_at, elapsed_ms (sunumdan bu yana), limit_ms (20000).
create or replace function public.present_async_duel_question(
  p_duel_id uuid,
  p_question_index integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_total integer;
  v_answered integer;
  v_started timestamptz;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found';
  end if;

  if v_uid <> v_duel.creator_id
     and v_uid is distinct from v_duel.opponent_id then
    raise exception 'Not a duel player';
  end if;

  if v_duel.status = 'expired'
     or (v_duel.status <> 'completed'
         and v_duel.expires_at <= clock_timestamp()) then
    raise exception 'Duel expired';
  end if;

  v_total := coalesce(array_length(v_duel.question_ids, 1), 0);
  select count(*)::integer into v_answered
  from public.async_duel_answers a
  where a.duel_id = p_duel_id and a.player_id = v_uid;

  if p_question_index is null
     or p_question_index <> v_answered
     or p_question_index >= v_total then
    raise exception 'Invalid index';
  end if;

  insert into public.async_duel_question_starts (
    duel_id, player_id, question_index, started_at
  ) values (
    p_duel_id, v_uid, p_question_index, clock_timestamp()
  )
  on conflict (duel_id, player_id, question_index) do nothing;

  select st.started_at into v_started
  from public.async_duel_question_starts st
  where st.duel_id = p_duel_id
    and st.player_id = v_uid
    and st.question_index = p_question_index;

  return jsonb_build_object(
    'started_at', v_started,
    'elapsed_ms', greatest(
      0,
      floor(extract(epoch from (clock_timestamp() - v_started)) * 1000)
    )::integer,
    'limit_ms', 20000
  );
end;
$function$;

revoke all on function public.present_async_duel_question(uuid, integer)
  from public, anon;
grant execute on function public.present_async_duel_question(uuid, integer)
  to authenticated;

-- ═════════════════════════════════════════════════════════════════════════
-- 3) İstemci RPC'leri (canlı gövde + işaretli farklar)
-- ═════════════════════════════════════════════════════════════════════════
-- Farklar: 48 → 24 saat (greatest YOK: eski 48 saatlik açık düello da en
-- fazla 24 saat verir); answer'da duvar saati doğrulaması + sunum süresi;
-- hükmen XP; liste.

CREATE OR REPLACE FUNCTION public.start_async_duel(p_category text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
    -- yarıda bırakan açanın düellosu eşleşmez, 24 saatte süresi dolar.
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
    -- Rakibe kendi 24 saati verilir: açık düellonun süresi açanın
    -- penceresiydi; 23. saatte eşleşen biri oynarken "Duel expired"
    -- alırdı.
    update public.async_duels
    set opponent_id = v_uid,
        status = 'matched',
        matched_at = now(),
        expires_at = now() + interval '24 hours'
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


CREATE OR REPLACE FUNCTION public.accept_async_duel_challenge(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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

  -- Rakibe kendi 24 saati verilir (start_async_duel ile aynı gerekçe).
  update public.async_duels
  set opponent_id = v_uid,
      status = 'matched',
      matched_at = now(),
      expires_at = now() + interval '24 hours'
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


CREATE OR REPLACE FUNCTION public.answer_async_duel(p_duel_id uuid, p_question_index integer, p_choice text, p_response_ms integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_id uuid;
  v_total integer;
  v_question_id uuid;
  v_correct_option text;
  v_is_correct boolean;
  v_response_ms integer;
  v_prev_at timestamptz;
  v_baseline timestamptz;
  v_prior_answers integer;
  v_started_at timestamptz;
  v_elapsed_ms integer;
  v_late boolean := false;
  v_server_ms integer;
  -- İstemcideki soru süresi (async_duel_play_screen `_questionSeconds` = 20).
  v_max_ms constant integer := 20000;
  v_answered integer;
  v_finished boolean := false;
  v_my_correct integer;
  v_my_ms integer;
  v_opp_correct integer;
  v_opp_ms integer;
  v_opponent_done boolean := false;
  v_completed_now boolean := false;
  v_outcome text;
  v_result jsonb := null;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id
  for update;

  if not found then
    raise exception 'Duel not found';
  end if;

  if v_uid = v_duel.creator_id then
    v_other_id := v_duel.opponent_id;
  elsif v_uid = v_duel.opponent_id then
    v_other_id := v_duel.creator_id;
  else
    raise exception 'Not a duel player';
  end if;

  -- Duvar saatiyle (clock_timestamp: işlem başlangıcı DEĞİL) ve kilitten
  -- SONRA: süresi dolan ya da hükmen kapanan düelloya cevap yazılamaz. (Tam
  -- cevaplanmış 'completed' düello 'Already answered' yoluna düşer: istemci
  -- yeniden gönderimi buna güvenir.)
  if v_duel.status = 'expired'
     or (v_duel.status <> 'completed'
         and v_duel.expires_at <= clock_timestamp()) then
    raise exception 'Duel expired';
  end if;

  v_total := coalesce(array_length(v_duel.question_ids, 1), 0);
  if p_question_index is null
     or p_question_index < 0
     or p_question_index >= v_total then
    raise exception 'Invalid index';
  end if;

  -- SIRA ZORUNLULUĞU (2026-10-24): cevap, oyuncunun beklenen sıradaki
  -- indeksine (mevcut cevap sayısı) gelmeli; atlayarak cevap 'Invalid
  -- index'. Zaten cevaplanmış bir indekse tekrar cevap eski 'Already
  -- answered' yoluna düşer (istemci yeniden gönderimi buna güvenir). 2.1.0
  -- istemcisi sırayla cevapladığı için uyumludur.
  select count(*)::integer into v_prior_answers
  from public.async_duel_answers pa
  where pa.duel_id = p_duel_id and pa.player_id = v_uid;

  if p_question_index <> v_prior_answers
     and not exists (
       select 1 from public.async_duel_answers pa
       where pa.duel_id = p_duel_id
         and pa.player_id = v_uid
         and pa.question_index = p_question_index
     ) then
    raise exception 'Invalid index';
  end if;

  if p_choice is null or p_choice not in ('A', 'B', 'C', 'D', 'TIMEOUT') then
    raise exception 'Invalid choice';
  end if;

  v_question_id := v_duel.question_ids[p_question_index + 1];
  select q.correct_option into v_correct_option
  from public.questions q
  where q.id = v_question_id;

  -- correct_option beklenmedik biçimde NULL gelirse (bozuk veri) bile
  -- NOT NULL is_correct sütununa NULL yazmayı önler.
  v_is_correct := coalesce(v_correct_option = p_choice, false);
  -- SÜRE SUNUCUDA ÖLÇÜLÜR. `p_response_ms` artık kullanılmaz: eşitlik
  -- bozucu ve +30 XP kazanan bonusu bu süreye bağlı, istemci değeri ise
  -- değiştirilmiş bir istemciyle 1 ms yazılabiliyordu. Soru "sunuldu" anı:
  --   * oyuncunun bu düellodaki önceki cevabının zamanı, yoksa
  --   * ilk soruda: yaratıcıda düellonun açılışı (`created_at`), rakipte
  --     eşleşme anı (`matched_at`) — sorular start_async_duel yanıtıyla
  --     o anda iletilir.
  -- Ölçülen süre [0, 20000] ms'e kırpılır (soru süresi; uygulamayı arka
  -- plana atıp saatler sonra dönen oyuncu en çok TIMEOUT kadar kaybeder).
  -- Dürüst istemcinin kendi kronometresi hiçbir zaman sunucu aralığından
  -- uzun olamaz (ağ + cevap gösterim bekleme süresi sunucu tarafında
  -- sayılır, iki oyuncu için de aynı sabit pay), bu yüzden sıralama adil
  -- kalır. Eski istemcinin 4 parametreli çağrısı aynen çalışır.
  select max(a.answered_at) into v_prev_at
  from public.async_duel_answers a
  where a.duel_id = p_duel_id
    and a.player_id = v_uid;

  v_baseline := coalesce(
    v_prev_at,
    case
      when v_uid = v_duel.creator_id then v_duel.created_at
      else coalesce(v_duel.matched_at, v_duel.created_at)
    end
  );

  v_server_ms := greatest(
    0,
    least(
      floor(extract(epoch from (now() - v_baseline)) * 1000),
      v_max_ms
    )
  )::integer;

  -- SUNUM KAYDI (2026-10-24): istemci soruyu ekrana koyarken
  -- present_async_duel_question çağırdıysa süre sunumdan ölçülür (resume
  -- saati sıfırlayamaz). 20 sn + 5 sn ağ payını aşan cevap YANLIŞtır.
  -- Kayıt yoksa (2.1.0 istemcisi) yukarıdaki eski ölçüm aynen geçerli.
  select st.started_at into v_started_at
  from public.async_duel_question_starts st
  where st.duel_id = p_duel_id
    and st.player_id = v_uid
    and st.question_index = p_question_index;

  if found then
    v_elapsed_ms := greatest(
      0,
      floor(extract(epoch from (clock_timestamp() - v_started_at)) * 1000)
    )::integer;
    v_server_ms := least(v_elapsed_ms, v_max_ms);
    if v_elapsed_ms > v_max_ms + 5000 then
      v_late := true;
      v_is_correct := false;
    end if;
  end if;

  v_response_ms := case
    when p_choice = 'TIMEOUT' or v_late then v_max_ms
    else v_server_ms
  end;

  begin
    insert into public.async_duel_answers (
      duel_id, player_id, question_index, choice, is_correct, response_ms
    ) values (
      p_duel_id, v_uid, p_question_index, p_choice, v_is_correct, v_response_ms
    );
  exception
    when unique_violation then
      raise exception 'Already answered';
  end;

  select count(*) into v_answered
  from public.async_duel_answers
  where duel_id = p_duel_id
    and player_id = v_uid;

  if v_answered >= v_total then
    v_finished := true;

    select
      count(*) filter (where is_correct)::integer,
      coalesce(sum(response_ms), 0)::integer
    into v_my_correct, v_my_ms
    from public.async_duel_answers
    where duel_id = p_duel_id
      and player_id = v_uid;

    insert into public.async_duel_results (
      duel_id, player_id, correct_count, total_ms
    ) values (
      p_duel_id, v_uid, v_my_correct, v_my_ms
    )
    on conflict (duel_id, player_id) do update
      set correct_count = excluded.correct_count,
          total_ms = excluded.total_ms
    returning correct_count, total_ms into v_my_correct, v_my_ms;

    if v_other_id is not null then
      select correct_count, total_ms into v_opp_correct, v_opp_ms
      from public.async_duel_results
      where duel_id = p_duel_id
        and player_id = v_other_id;

      v_opponent_done := found;
    end if;

    if v_opponent_done then
      update public.async_duels
      set status = 'completed',
          completed_at = now()
      where id = p_duel_id
        and status <> 'completed';

      v_completed_now := found;

      v_outcome := case
        when v_my_correct > v_opp_correct then 'win'
        when v_my_correct < v_opp_correct then 'loss'
        when v_my_ms < v_opp_ms then 'win'
        when v_my_ms > v_opp_ms then 'loss'
        else 'draw'
      end;

      v_result := jsonb_build_object(
        'status', 'completed',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'opponent_correct', v_opp_correct,
        'opponent_ms', v_opp_ms,
        'outcome', v_outcome
      );

      -- Sonucu az önce TAMAMLAYAN bu çağrı olduğunda, bekleyen diğer
      -- oyuncuya tek seferlik bildirim kuyruklanır (enqueue_friend_request_push
      -- ile aynı desen: bkz. 2026-08-26_fcm_token.sql).
      if v_completed_now then
        -- Engelli çifte (iki yönde) bildirim gitmez (2026-10-24).
        insert into public.push_outbox (to_user_id, kind, title, body)
        select
          v_other_id,
          'async_duel_result',
          'ZanKurd',
          -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
          'Pêşbirka te qediya — encamê bibîne · Düellon bitti — sonucu gör'
        where not exists (
          select 1 from public.blocked_users b
          where (b.blocker_id = v_uid and b.blocked_id = v_other_id)
             or (b.blocker_id = v_other_id and b.blocked_id = v_uid)
        );
      end if;
    else
      v_result := jsonb_build_object(
        'status', 'waiting',
        'my_correct', v_my_correct,
        'my_ms', v_my_ms,
        'opponent_correct', null,
        'opponent_ms', null,
        'outcome', null
      );
    end if;
  end if;

  return jsonb_build_object(
    'correct', v_is_correct,
    'correct_option', v_correct_option,
    'answered', v_answered,
    'total', v_total,
    'finished', v_finished,
    'result', v_result
  );
end;
$function$;


CREATE OR REPLACE FUNCTION public.claim_async_duel_xp(p_duel_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_result public.async_duel_results%rowtype;
  v_opponent_id uuid;
  v_opponent_correct integer;
  v_opponent_ms integer;
  v_delta integer;
  v_total integer;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_duel
  from public.async_duels
  where id = p_duel_id;

  if not found then
    raise exception 'Duel not found';
  end if;

  if v_uid <> v_duel.creator_id and v_uid <> v_duel.opponent_id then
    raise exception 'Not a duel player';
  end if;

  if v_duel.status not in ('completed', 'expired') then
    raise exception 'Duel not finished';
  end if;

  select * into v_result
  from public.async_duel_results
  where duel_id = p_duel_id
    and player_id = v_uid
  for update;

  if not found then
    -- Düello completed/expired ama BEN kendi 7 sorumu hiç bitirmemişim:
    -- benim açımdan da "henüz bitmemiş" — sözleşmedeki aynı hata metni.
    raise exception 'Duel not finished';
  end if;

  if v_result.xp_awarded then
    select coalesce(xp, 0) into v_total from public.profiles where id = v_uid;
    return coalesce(v_total, 0);
  end if;

  v_delta := v_result.correct_count * 20;

  v_opponent_id := case
    when v_duel.creator_id = v_uid then v_duel.opponent_id
    else v_duel.creator_id
  end;

  if v_duel.forfeit_loser_id is not null
     and v_duel.forfeit_loser_id <> v_uid then
    -- Hükmen galibiyet (2026-10-24): rakip 24 saatte oynamadı. Normal
    -- galibiyetle AYNI +30 bonus; rakibin sonuç satırı olmadığı için aşağıdaki
    -- karşılaştırma bunu hiç vermezdi.
    v_delta := v_delta + 30;
  elsif v_opponent_id is not null then
    select correct_count, total_ms into v_opponent_correct, v_opponent_ms
    from public.async_duel_results
    where duel_id = p_duel_id
      and player_id = v_opponent_id;

    if found then
      if v_result.correct_count > v_opponent_correct
         or (
           v_result.correct_count = v_opponent_correct
           and v_result.total_ms < v_opponent_ms
         ) then
        v_delta := v_delta + 30;
      end if;
    end if;
  end if;

  update public.async_duel_results
  set xp_awarded = true
  where duel_id = p_duel_id
    and player_id = v_uid;

  if v_delta <= 0 then
    select coalesce(xp, 0) into v_total from public.profiles where id = v_uid;
    return coalesce(v_total, 0);
  end if;

  return public.award_xp_delta(v_delta);
end;
$function$;


CREATE OR REPLACE FUNCTION public.list_my_async_duels()
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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
      when mine.duel_id is not null
           or d.forfeit_loser_id = v_uid then theirs.correct_count
      else null
    end,
    'outcome', case
      -- Hükmen sonuç (2026-10-24): kaybeden 24 saatte turunu bitirmedi,
      -- bitiren kazanır. Normal karşılaştırmanın önüne geçer.
      when d.forfeit_loser_id is not null then
        case when d.forfeit_loser_id = v_uid then 'loss' else 'win' end
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
    'forfeit', (d.forfeit_loser_id is not null),
    'expires_at', d.expires_at,
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


-- ═════════════════════════════════════════════════════════════════════════
-- 4) expire_async_duels — hükmen + hatırlatma + kapatma (cron, 10 dk)
-- ═════════════════════════════════════════════════════════════════════════
-- Dönüş: bu çalışmada kapatılan düello sayısı (eski sözleşme).
--
-- HÜKMEN KURALI (süresi geçmiş 'open'/'matched' düello):
--   * "Öteki taraf" = EŞLEŞMİŞ/KABUL ETMİŞ rakip (`opponent_id`). Kabul
--     edilmemiş arkadaş daveti (opponent_id boş, yalnız invited_id dolu)
--     düelloya HİÇ GİRMEMİŞTİR: hükmen sayılmaz, kimse kaybetmez (karar:
--     koordinatör, 2026-10-24).
--   * Yaratıcı turunu BİTİRDİ, rakip GİRDİ ve bitirmedi → rakip KAYBEDER.
--   * Yaratıcı bitirmedi, öteki bitirdi → yaratıcı kaybeder (normalde
--     eşleşme için yaratıcının turu şarttır; savunma amaçlı).
--   * Rakip yok (rakipsiz rastgele düello, kimsenin almadığı bağlantı,
--     KABUL EDİLMEMİŞ arkadaş daveti) ya da kimse bitirmedi → kayıpsız
--     'expired'; yaratıcı "Rakip çıkmadı" doğru başına XP'sini alır.
--   * Kazanan +30'lu tam XP'yi (doğru × 20 + 30) SUNUCUDA alır (her koşuda
--     son 7 günün ödenmemiş hükmenleri yeniden denenir): sonuç
--     satırının `xp_awarded` işareti claim_async_duel_xp ile ORTAKTIR, yani
--     istemci sonradan claim ederse çift verilmez. award_xp_delta
--     auth.uid() okuduğu için kimlik işlem içinde taklit edilir.
--   * Hükmen sonuç bildirimi engelli çifte gitmez (XP yine verilir).
create or replace function public.expire_async_duels()
returns integer
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_count integer := 0;
  v_cc integer;
  rec record;
begin
  -- (a) Süresi dolanları kapat; hükmen kaybedeni işle; iki tarafa sonuç
  -- bildirimi kuyrukla.
  with due as (
    select
      d.id,
      d.creator_id,
      -- Yalnız düelloya GİRMİŞ rakip; davetli (invited_id) hükmen dışı.
      d.opponent_id as other_id,
      exists (
        select 1 from public.async_duel_results r
        where r.duel_id = d.id and r.player_id = d.creator_id
      ) as creator_done,
      exists (
        select 1 from public.async_duel_results r
        where r.duel_id = d.id
          and r.player_id = d.opponent_id
      ) as other_done,
      exists (
        select 1 from public.blocked_users b
        where d.opponent_id is not null
          and ((b.blocker_id = d.creator_id and b.blocked_id = d.opponent_id)
            or (b.blocker_id = d.opponent_id and b.blocked_id = d.creator_id))
      ) as blocked
    from public.async_duels d
    where d.status in ('open', 'matched')
      and d.expires_at <= now()
    for update of d
  ),
  decided as (
    select
      due.id,
      due.creator_id,
      due.other_id,
      due.blocked,
      case
        when due.creator_done
             and due.other_id is not null
             and not due.other_done then due.other_id
        when not due.creator_done
             and due.other_done then due.creator_id
        else null
      end as loser_id
    from due
  ),
  closed as (
    update public.async_duels d
    set status = 'expired',
        forfeit_loser_id = decided.loser_id
    from decided
    where d.id = decided.id
    returning d.id, decided.creator_id, decided.other_id, decided.loser_id,
              decided.blocked
  ),
  pushed as (
    insert into public.push_outbox (to_user_id, kind, title, body)
    select
      p.uid,
      'async_duel_result',
      'ZanKurd',
      p.body
    from closed c
    cross join lateral (
      values
        (
          case when c.loser_id = c.creator_id then c.other_id
               else c.creator_id end,
          -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
          'Hevrikê te di 24 saetan de nelîst; tu bi hukmî bi ser ketî · '
            || 'Rakibin 24 saatte oynamadı; düelloyu hükmen kazandın'
        ),
        (
          c.loser_id,
          'Te di 24 saetan de nelîst; te bi hukmî winda kir · '
            || '24 saatte oynamadın; düelloyu hükmen kaybettin'
        )
    ) as p(uid, body)
    where c.loser_id is not null
      and p.uid is not null
      and not c.blocked
    returning 1
  )
  select count(*)::integer into v_count from closed c;

  -- (a2) Hükmen kazananın XP'si sunucuda, tek seferlik (xp_awarded). Bu
  -- koşuda kapananlar DEĞİL, son 7 günün hükmen kapanmış bütün düelloları
  -- taranır: ödeme hatası bir sonraki koşuda yeniden denenir (idempotent:
  -- yalnız kazananın xp_awarded'ı false olanlar).
  for rec in
    select
      d.id as duel_id,
      case when d.forfeit_loser_id = d.creator_id then d.opponent_id
           else d.creator_id end as winner_id
    from public.async_duels d
    where d.status = 'expired'
      and d.forfeit_loser_id is not null
      and d.expires_at >= now() - interval '7 days'
  loop
    begin
      update public.async_duel_results r
      set xp_awarded = true
      where r.duel_id = rec.duel_id
        and r.player_id = rec.winner_id
        and r.xp_awarded = false
      returning r.correct_count into v_cc;

      if found then
        perform set_config(
          'request.jwt.claims',
          json_build_object('sub', rec.winner_id)::text,
          true
        );
        perform public.award_xp_delta(v_cc * 20 + 30);
      end if;
    exception when others then
      -- Alt blok geri alınır: xp_awarded İŞARETLENMEZ, sonraki koşu yeniden
      -- dener. Hata sunucu günlüğünde görünür ama cron durmaz.
      raise notice 'duello hukmen xp hatasi: % (duel %, kazanan %)',
        sqlerrm, rec.duel_id, rec.winner_id;
    end;
  end loop;
  perform set_config('request.jwt.claims', '{}', true);

  -- (b) Hatırlatma: süreye ≤ 4 saat kala turunu bitirmemiş oyuncuya, düello
  -- ve oyuncu başına TEK kez (`reminder_sent_for`).
  --   * Yaratıcı: turunu bitirdiyse hatırlatılmaz.
  --   * Öteki taraf (rakip ya da kabul etmemiş davetli): yalnız yaratıcı
  --     turunu bitirdiyse ve kendisi bitirmediyse.
  --   * Engelli çifte (yaratıcı ↔ rakip/davetli) hatırlatma gitmez.
  -- YARIŞ KORUMASI: adaylar `for update of d skip locked` ile kilitlenir
  -- (eşzamanlı ikinci koşu bu satırları atlar) ve push YALNIZ gerçekten
  -- işaretlenen düellolar için üretilir (`marked` ile birleşim).
  with cand as (
    select d.id, p.uid, d.expires_at
    from public.async_duels d
    cross join lateral (
      values
        (d.creator_id, true),
        (coalesce(d.opponent_id, d.invited_id), false)
    ) as p(uid, is_creator)
    where d.status in ('open', 'matched')
      and d.expires_at > now()
      and d.expires_at <= now() + interval '4 hours'
      and p.uid is not null
      and not (p.uid = any (d.reminder_sent_for))
      and not exists (
        select 1 from public.async_duel_results r
        where r.duel_id = d.id and r.player_id = p.uid
      )
      and (
        p.is_creator
        or exists (
          select 1 from public.async_duel_results r
          where r.duel_id = d.id and r.player_id = d.creator_id
        )
      )
      and not exists (
        select 1 from public.blocked_users b
        where coalesce(d.opponent_id, d.invited_id) is not null
          and ((b.blocker_id = d.creator_id
                and b.blocked_id = coalesce(d.opponent_id, d.invited_id))
            or (b.blocker_id = coalesce(d.opponent_id, d.invited_id)
                and b.blocked_id = d.creator_id))
      )
    for update of d skip locked
  ),
  marked as (
    update public.async_duels d
    set reminder_sent_for = d.reminder_sent_for || m.uids
    from (
      select c.id, array_agg(c.uid) as uids
      from cand c
      group by c.id
    ) m
    where d.id = m.id
    returning d.id
  )
  insert into public.push_outbox (to_user_id, kind, title, body)
  select
    c.uid,
    'async_duel_turn',
    'ZanKurd',
    -- Kalan saat yukarı yuvarlanır (en az 1): "≤ 4 saat" doğru kalır.
    'Dora te ye: ' || greatest(1, ceil(extract(epoch from (c.expires_at - now())) / 3600))::integer
      || ' saet mane · Sıra sende: '
      || greatest(1, ceil(extract(epoch from (c.expires_at - now())) / 3600))::integer
      || ' saat kaldı'
  from cand c
  join marked mk on mk.id = c.id;

  return coalesce(v_count, 0);
end;
$function$;

-- create or replace izinleri korur; yine de açıkça: yalnız cron/service_role.
revoke all on function public.expire_async_duels()
  from public, anon, authenticated;
grant execute on function public.expire_async_duels() to service_role;

-- ═════════════════════════════════════════════════════════════════════════
-- 5) Doğrulama — tutmazsa göç GERİ ALINIR
-- ═════════════════════════════════════════════════════════════════════════
do $verify$
declare
  v_default text;
begin
  select pg_get_expr(ad.adbin, ad.adrelid) into v_default
  from pg_attrdef ad
  join pg_attribute a on a.attrelid = ad.adrelid and a.attnum = ad.adnum
  where ad.adrelid = 'public.async_duels'::regclass
    and a.attname = 'expires_at';
  if v_default is null or v_default not like '%24:00:00%' then
    raise exception 'expires_at varsayılanı 24 saat değil: %', v_default;
  end if;

  if (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'async_duels'
        and column_name in ('forfeit_loser_id', 'reminder_sent_for')) <> 2 then
    raise exception 'async_duels yeni sütunları eksik';
  end if;

  if to_regclass('public.async_duel_question_starts') is null then
    raise exception 'async_duel_question_starts yok';
  end if;

  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('start_async_duel', 'accept_async_duel_challenge')
      and pg_get_functiondef(p.oid) like '%48 hours%'
  ) then
    raise exception 'start/accept hâlâ 48 saat veriyor';
  end if;

  if has_function_privilege(
       'anon', 'public.present_async_duel_question(uuid, integer)', 'execute')
     or not has_function_privilege(
       'authenticated', 'public.present_async_duel_question(uuid, integer)',
       'execute') then
    raise exception 'present_async_duel_question izinleri yanlış';
  end if;

  if pg_get_functiondef('public.list_my_async_duels()'::regprocedure)
       not like '%''expires_at''%'
     or pg_get_functiondef('public.list_my_async_duels()'::regprocedure)
       not like '%''forfeit''%' then
    raise exception 'list_my_async_duels expires_at/forfeit döndürmüyor';
  end if;

  if pg_get_functiondef('public.expire_async_duels()'::regprocedure)
       not like '%forfeit_loser_id%' then
    raise exception 'expire_async_duels hükmen işlemiyor';
  end if;

  if pg_get_functiondef('public.answer_async_duel(uuid, integer, text, integer)'::regprocedure)
       not like '%clock_timestamp()%' then
    raise exception 'answer_async_duel duvar saatiyle doğrulamıyor';
  end if;
end;
$verify$;

commit;
