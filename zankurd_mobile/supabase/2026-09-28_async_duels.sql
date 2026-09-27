-- 2026-09-28: Sırayla düello (async 1v1).
--
-- Küçük kullanıcı kitlesinde canlı eşleştirme (join_matchmaking) çoğu zaman
-- boş kalıyor: rakip aynı anda çevrimiçi olmadığı için oyuncu botla ya da
-- hiç oynayamıyor. Bu göç, rakibin aynı anda çevrimiçi olmasını GEREKTİRMEYEN
-- bir 1v1 kurar (Quizduell / Trivia Crack modeli): oyuncu 7 soruyu hemen
-- oynar, rakip saatler sonra aynı 7 soruyu oynar, ikisi de bitince sonuç
-- karşılaştırılır. İstemci sözleşmesi (RPC imzaları, JSON anahtarları,
-- hata metinleri) bu dosyadaki fonksiyonlardır; Dart tarafı
-- lib/src/models/async_duel.dart bunlara birebir uyar.
--
-- Üç tablo (async_duels, async_duel_answers, async_duel_results) istemciye
-- TAMAMEN kapalı: RLS açık, istemci politikası yok, tüm tablo yetkileri
-- REVOKE edilmiş. Erişim yalnız aşağıdaki SECURITY DEFINER RPC'lerle;
-- `questions.correct_option` istemciye asla ham dönmez — yalnız cevap
-- sonrası sunucunun hesapladığı `correct_option` alanıyla, tek soru için,
-- cevaptan SONRA açığa çıkar (oda akışındaki "gizli cevap" deseniyle aynı
-- ilke: bkz. 2026-09-06_get_room_questions_revealed.sql).
--
-- Bu dosya canlıya UYGULANMAMIŞTIR. Bkz. supabase/applied.md — satır
-- "uygulanmadı / inceleme bekliyor" durumuyla eklenmiştir, ✅ değildir.

begin;

-- ---------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------

create table if not exists public.async_duels (
  id uuid primary key default gen_random_uuid(),
  category_id uuid null references public.categories(id),
  question_ids uuid[] not null,             -- sunucunun seçtiği 7 soru, sıralı
  creator_id uuid not null references auth.users(id) on delete cascade,
  opponent_id uuid null references auth.users(id) on delete set null,
  invited_id uuid null references auth.users(id) on delete set null, -- v1.1: arkadaşa meydan okuma
  status text not null default 'open'
    check (status in ('open', 'matched', 'completed', 'expired')),
  created_at timestamptz not null default now(),
  matched_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz not null default now() + interval '48 hours'
);

-- start_async_duel'in "eşleşecek en eski açık düello" araması için.
create index if not exists async_duels_open_idx
  on public.async_duels (status, created_at)
  where status = 'open';

-- Kişi başına en fazla 5 açık düello sayımı ve list_my_async_duels'in
-- "ben creator'ım" yarısı için.
create index if not exists async_duels_creator_status_idx
  on public.async_duels (creator_id, status);

-- list_my_async_duels'in "ben opponent'ım" yarısı için.
create index if not exists async_duels_opponent_idx
  on public.async_duels (opponent_id)
  where opponent_id is not null;

create table if not exists public.async_duel_answers (
  duel_id uuid not null references public.async_duels(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  question_index int not null check (question_index between 0 and 19),
  -- 'TIMEOUT': soru başına 20 sn dolduğunda istemcinin gönderdiği boş
  -- cevap; her zaman yanlış sayılır. Süresiz bir düelloda cevap
  -- internetten aranabilirdi.
  choice text not null check (choice in ('A', 'B', 'C', 'D', 'TIMEOUT')),
  is_correct boolean not null,   -- SUNUCU hesaplar; istemcinin dediği değil
  response_ms int not null check (response_ms between 0 and 120000),
  answered_at timestamptz not null default now(),
  primary key (duel_id, player_id, question_index)   -- ilk cevap kilitli
);

create table if not exists public.async_duel_results (
  duel_id uuid not null references public.async_duels(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  correct_count int not null,
  total_ms int not null,
  finished_at timestamptz not null default now(),
  xp_awarded boolean not null default false,
  seen_at timestamptz,           -- "sonuç hazır" rozeti için: null = okunmamış
  primary key (duel_id, player_id)
);

-- ---------------------------------------------------------------------
-- RLS: istemci politikası YOK. Üçü de yalnız aşağıdaki RPC'lerden geçer.
-- FORCE, tablo sahibi (fonksiyonların çalıştığı rol) için de RLS'yi
-- zorunlu kılar; REVOKE zaten doğrudan erişimi kapatır ama iki katman
-- birlikte 2026-08-02'deki room_result_receipts/room_result_snapshots
-- deseniyle aynı savunma derinliğini verir.
-- ---------------------------------------------------------------------

alter table public.async_duels enable row level security;
alter table public.async_duels force row level security;
alter table public.async_duel_answers enable row level security;
alter table public.async_duel_answers force row level security;
alter table public.async_duel_results enable row level security;
alter table public.async_duel_results force row level security;

revoke all on table public.async_duels from public, anon, authenticated;
revoke all on table public.async_duel_answers from public, anon, authenticated;
revoke all on table public.async_duel_results from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- start_async_duel: bekleyen açık düello varsa eşleş, yoksa yeni aç.
--
-- Kategori adı bilinmiyor/aktif değilse ayrı bir hata metni İCAT ETMEYİZ:
-- sözleşme yalnız 'Not authenticated' / 'Too many open duels' /
-- 'No questions' tanımlar. Çözülemeyen kategoride ne bekleyen düello ne
-- de soru bulunabileceğinden, bu durum doğrudan 'No questions' ile aynı
-- anlama gelir — sözleşmeyi genişletmeden aynı sonuca varılır.
-- ---------------------------------------------------------------------

create or replace function public.start_async_duel(p_category text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    select array_agg(picked.id order by picked.rnd) into v_question_ids
    from (
      select q.id, random() as rnd
      from public.questions q
      where q.is_approved = true
        and (v_category_id is null or q.category_id = v_category_id)
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
$$;

revoke all on function public.start_async_duel(text) from public, anon;
grant execute on function public.start_async_duel(text) to authenticated;

-- ---------------------------------------------------------------------
-- answer_async_duel: tek cevap yazar; son soruda sonuç satırını da yazar.
--
-- Düello satırı EN BAŞTA `for update` ile kilitlenir ve fonksiyon boyunca
-- tutulur. Bu, iki oyuncunun 7. sorusunu neredeyse aynı anda cevaplaması
-- durumunda "rakip bitirdi mi" yarışını satır kilidi üzerinden sıralar:
-- ikinci biten, birincinin commit ettiği sonucu her zaman görür.
-- ---------------------------------------------------------------------

create or replace function public.answer_async_duel(
  p_duel_id uuid,
  p_question_index integer,
  p_choice text,
  p_response_ms integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other_id uuid;
  v_total integer;
  v_question_id uuid;
  v_correct_option text;
  v_is_correct boolean;
  v_response_ms integer;
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

  if v_duel.status <> 'completed' and now() > v_duel.expires_at then
    raise exception 'Duel expired';
  end if;

  v_total := coalesce(array_length(v_duel.question_ids, 1), 0);
  if p_question_index is null
     or p_question_index < 0
     or p_question_index >= v_total then
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
  v_response_ms := greatest(0, least(coalesce(p_response_ms, 0), 120000));

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
        insert into public.push_outbox (to_user_id, kind, title, body)
        values (
          v_other_id,
          'async_duel_result',
          'ZanKurd',
          -- Sunucu alıcının arayüz dilini bilmiyor; metin iki dilli.
          'Pêşbirka te qediya — encamê bibîne · Düellon bitti — sonucu gör'
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
$$;

revoke all on function public.answer_async_duel(uuid, integer, text, integer)
  from public, anon;
grant execute on function public.answer_async_duel(uuid, integer, text, integer)
  to authenticated;

-- ---------------------------------------------------------------------
-- list_my_async_duels: son 30 gün, yeniden eskiye.
--
-- opponent_correct/outcome yalnız BEN bitirdiysem (kendi results satırım
-- varsa) görünür — rakip benden önce bitirmiş olsa bile, ben bitirmeden
-- skorunu göremem. Bu bilerek konmuş bir gizlilik/adalet kuralıdır:
-- aksi hâlde rakibin skorunu görüp kendi cevaplarımı ona göre ayarlayabilirdim.
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
    'seen', (mine.duel_id is null or mine.seen_at is not null)
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
  where (d.creator_id = v_uid or d.opponent_id = v_uid)
    and d.created_at >= now() - interval '30 days'
  order by d.created_at desc;
end;
$$;

revoke all on function public.list_my_async_duels() from public, anon;
grant execute on function public.list_my_async_duels() to authenticated;

-- ---------------------------------------------------------------------
-- mark_async_duel_seen: rozet sayacı için "gördüm" işareti.
--
-- Üyelik/varlık denetimi yoktur: kendi player_id'me ait olmayan ya da
-- henüz benim results satırım oluşmamış bir duel_id sessizce 0 satır
-- günceller. `returns void` olduğu için istemcinin buna bakacak bir
-- sonucu da yok; sözleşme bu RPC için ayrı bir hata metni tanımlamıyor.
-- ---------------------------------------------------------------------

create or replace function public.mark_async_duel_seen(p_duel_id uuid)
returns void
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

  update public.async_duel_results
  set seen_at = coalesce(seen_at, now())
  where duel_id = p_duel_id
    and player_id = v_uid;
end;
$$;

revoke all on function public.mark_async_duel_seen(uuid) from public, anon;
grant execute on function public.mark_async_duel_seen(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- claim_async_duel_xp: idempotent, doğru başına 20 + galibiyet 30.
--
-- award_room_xp örneğindeki gibi çağrılır: `award_xp_delta` istemciye
-- KAPALI olabilir (bkz. 2026-09-22_xp_and_coin_idempotency.sql — o göç
-- henüz UYGULANMADI ama uygulandığında authenticated/anon'dan execute
-- geri alınıp yalnız service_role'e bırakılıyor). Bu fonksiyon onu
-- doğrudan, kendi SECURITY DEFINER gövdesinden çağırır — tıpkı
-- award_room_xp(uuid)'nin yaptığı gibi — bu yüzden award_xp_delta'ya
-- authenticated için ayrıca GRANT gerekmez.
-- ---------------------------------------------------------------------

create or replace function public.claim_async_duel_xp(p_duel_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
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

  if v_opponent_id is not null then
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
$$;

revoke all on function public.claim_async_duel_xp(uuid) from public, anon;
grant execute on function public.claim_async_duel_xp(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- expire_async_duels: yalnız service_role/cron.
--
-- KASITLI SAPMA: Bu göçün görev tarifi altı RPC'nin BAŞINDA da
-- `auth.uid() is null` → 'Not authenticated' istiyor. Bu fonksiyon o
-- kontrolü TAŞIMAZ — tıpkı mevcut cron-only fonksiyonlar
-- `finalize_weekly_league` (2026-07-10_weekly_league.sql) ve
-- `cleanup_stale_rooms` (2026-07-21_room_cleanup.sql) gibi. pg_cron işi
-- `postgres` rolüyle, PostgREST/JWT olmadan çalıştırır; orada auth.uid()
-- HER ZAMAN null döner. Kontrolü eklemek bu fonksiyonu cron'dan asla
-- başarıyla çalışamaz hale getirirdi. KESİN SÖZLEŞME bu fonksiyon için
-- ayrıca bir hata metni tanımlamıyor (yalnız "yalnız service_role/cron"
-- diyor); erişim zaten aşağıdaki REVOKE/GRANT ile donanım düzeyinde
-- kapatılıyor, auth.uid() kontrolüne ihtiyaç yok.
--
-- 'open' VE 'matched' durumundaki süresi geçmiş düelloları kapatır: tasarım
-- metninde örnek olarak yalnız "açık" düellolar anılsa da, rakip eşleşip
-- de sorularını hiç bitirmediği bir düello da süresiz "matched" kalır ve
-- claim_async_duel_xp'nin izin verdiği tek iki durum (completed/expired)
-- dışında sonsuza dek asılı kalırdı.
-- ---------------------------------------------------------------------

create or replace function public.expire_async_duels()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  with expired as (
    update public.async_duels
    set status = 'expired'
    where status in ('open', 'matched')
      and expires_at <= now()
    returning id
  )
  select count(*) into v_count from expired;

  return coalesce(v_count, 0);
end;
$$;

revoke all on function public.expire_async_duels()
  from public, anon, authenticated;
grant execute on function public.expire_async_duels() to service_role;

commit;
